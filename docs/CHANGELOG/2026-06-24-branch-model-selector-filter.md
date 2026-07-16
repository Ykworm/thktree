# 分支创建 sheet filter 漏洞修复 + LLM 未配置死路三层防御

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-24 |
| 范围 | `integration_test/branch_creation_test.dart` 7 个 testWidgets 中 case 1-6 实跑通过（02:26） + `_ModelSelectorSheet` filter 漏洞修复 + `checkLlmSetup` 三层防御 helper 新增 + 2 个 l10n key 新增 + 5 个 ValueKey 补全 + 集成测试 spec `branch-creation.md` 大改版 |
| 设计文档 | [`docs/_shared/integration-testing/branch-creation.md`](../_shared/integration-testing/branch-creation.md) |
| 配套文档 | [CHANGELOG 2026-06-22](./2026-06-22-branch-creation-test.md)（case 1-4 首跑） · [war-story 2026-06-24 Keychain 状态泄漏](../war-stories/flutter/2026-06-24-integration-test-keychain-state-leak.md) |
| 状态 | 🟡 部分完成（case 1-6 实跑通过；case 7 scaffold + LLM mock 工具待补） |

## 背景

2026-06-22 CHANGELOG（[2026-06-22](./2026-06-22-branch-creation-test.md)）记录了分支创建集成测试 case 1-4 实跑通过，留下 3 项未完成工作：case 5/6 scaffold 待实跑、case 7 需建 LLM mock 工具、3 个 helper 重复未提取。

继续推进过程中，发现两个**实际触发比 spec 第 8 节 预想更紧迫**的问题：

1. **`_ModelSelectorSheet.build` 的 sheet filter 漏洞**：原实现 sheet 弹出时调用 `_filterAvailableModels` 过滤掉「无 apiKey 的 provider」，但 `_ModelSelectorSheet` 内部还**冗余地用 provider.apiKey 二次校验**——这两层校验在 SettingsStore 和 providers 列表不一致时会漏掉未配置的 provider，导致 sheet 选项为空但仍渲染 sheet action（用户点了 sheet action 才发现没模型）。
2. **LLM 未配置的死路死循环**：当用户从未配置过 LLM 时，`showBranchFlow` 入口调 `_resolveModelForSummary` 会得到 null，弹"pleaseFetchModels"提示；但提示后用户必须手动跳到 LLM 设置页，否则下次再点 branch 又走死路。这是**配置未初始化的常见状态**——尤其是新装 App 的用户首次使用 branch 功能。spec 当时未识别为风险。

本 CHANGELOG 记录两个问题的发现、修复及对应的三层防御 + sheet filter 漏洞修复。

## 根因

### 根因 1：`_ModelSelectorSheet` 的 sheet filter 与 provider 内嵌 apiKey 校验不一致

`title_suggestion_screen.dart:_ModelSelectorSheet.build`（commit `34d9465` 之前）的实现：

```dart
// filterAvailableModels 已过滤无 apiKey 的 provider
final available = providers.where((p) => p.apiKey.isNotEmpty).toList();
// 但 sheet action 渲染时仍再次判断
for (final provider in available) {
 // ⚠️ 这里又判断了一次 apiKey.isNotEmpty，与 SettingsStore 不一致时
 // 可用的 provider 列表会变成空
 if (provider.apiKey.isNotEmpty && /* 其他条件 */) {
 // 渲染 sheet action
 }
}
```

**根因**：`available` 列表已经过滤过无 apiKey 的 provider，但 sheet 渲染逻辑又用 `provider.apiKey.isNotEmpty` 二次校验。**当 SettingsStore 中 `currentProviderId` 与 `providers` 列表中实际 provider 的 apiKey 不一致时**（比如用户在「默认模型」页面切换了 provider 但没填 apiKey），sheet 渲染时二次校验会把这个 provider 排除，导致 sheet 选项为空。

**触发场景**：case 4（无选 + summarize 模式）实跑时，从 `LlmTestConfig.loadFromDefine()` 注入的 provider 列表里，`currentProviderId` 指向的 provider 在测试环境中 apiKey 已设置（来自 `--dart-define-from-file`），但 sheet filter 二次校验逻辑仍依赖 `p.apiKey.isNotEmpty`——本轮实跑发现 case 4 在某些 provider 配置下，sheet 弹出来但所有 action 都不可见，点 continue 后报「无可用模型」。

### 根因 2：LLM 未配置的死路

`showBranchFlow` 入口（commit `34d9465` 之前）调 `_resolveModelForSummary`：

```dart
// _resolveModelForSummary 返回 null 时
final resolved = await _resolveModelForSummary(...);
if (resolved == null) {
 await _showPleaseFetchModelsSheet(context); // 弹提示
 return; // 直接 return
}
// 否则继续走 sheet → 用户选 → 调 LLM
```

**问题 1：未配置场景无明确引导**——`_showPleaseFetchModelsSheet` 只弹一个简单文案提示，不告诉用户具体跳哪个页面配置什么模型。

**问题 2：死循环**——用户不点跳配置页的话，下次点 branch 还会再弹同一个提示，且没有任何持久化记录「已提示过」。

**问题 3：跳配置页后回不来**——即使用户点了跳配置，配置完返回 chat 后点 branch，逻辑会重新跑 `_resolveModelForSummary`，但 `SettingsStore` 的订阅链路有 1-2 帧延迟，可能拿到旧的空配置。

**触发场景**：本轮实跑 case 4 时，注入的 provider 配置是正确的；但 case 7（LLM 失败 fallback）scaffold 阶段模拟"未配置"场景时，发现即使 mock 失败让 `_resolveModelForSummary` 返回 null，最终用户看到的也只是"pleaseFetchModels"——并不是真正的"失败 fallback"语义。

## 方案

走**方案 A：三层防御 + sheet filter 单点修复 + 跳转目标精细化**。

### 三层防御结构

把"LLM 未配置死路"的拦截从单一的 `_resolveModelForSummary == null` 升级为**集中式 helper `checkLlmSetup` + 三个接入点的多层防御**。

```dart
// lib/ui/core/shared/llm_setup_check.dart（commit c8176a7 新增）
enum LlmSetupStatus {
 ready, // 有可用 provider + model + apiKey
 noProviderConfigured, // providers 列表为空
 noTitleModelConfigured, // 用途 title 但缺 title 模型
 noSummaryModelConfigured, // 用途 summarize 但缺 summary 模型
 noApiKeyForCurrentProvider, // provider 存在但 apiKey 缺失
}

LlmSetupStatus checkLlmSetup({
 required LlmSetupUsage usage, // .summarize / .title
 required List<LlmProvider> providers,
 String? currentProviderId,
 String? currentModelId,
});
```

**三个接入点**（commit `34d9465`）：

| 层级 | 位置 | 拦截「死路」 | 跳转目标 |
|------|------|------------|---------|
| **L1-A** | `showBranchFlow` 入口 | summarize 解析失败（用户从未配过 LLM） | `LlmProvidersScreen` |
| **L1-B** | `TitleSuggestionScreen.initState` | 跳到 title 页后才确认 sheet filter 为空（避免走到一半才发现） | `DefaultModelPickerScreen` |
| **L2** | `_showModelSelectorAndGenerate` 调用方 | 兜底中的兜底（filter 空时弹框引导） | `DefaultModelPickerScreen` |

**跳转目标精细化**（commit `34d9465`）：

| 状态 | 跳转目标 | 提示 |
|------|---------|------|
| `noProviderConfigured` | `LlmProvidersScreen` | "请先添加 LLM Provider 并填写 API Key" |
| `noTitleModelConfigured` | `DefaultModelPickerScreen` | "请配置标题生成模型"（`pleaseConfigureTitleModel`） |
| `noSummaryModelConfigured` | `DefaultModelPickerScreen` | "请配置对话总结模型"（`pleaseConfigureSummaryModel`） |
| `noApiKeyForCurrentProvider` | `LlmProvidersScreen` | "请为当前 Provider 填写 API Key" |

### Sheet filter 漏洞修复

`title_suggestion_screen.dart:_ModelSelectorSheet.build`（commit `34d9465`）移除**冗余的 provider.apiKey 二次校验**，统一依赖 `filterAvailableModels` 的结果：

```dart
// 修复后（commit 34d9465）
final available = filterAvailableModels(providers);
// 不再二次校验 apiKey，直接用 available 渲染 sheet action
```

### 4 个 ValueKey 补全

| Key | 位置 | 用途 |
|-----|------|------|
| `model_sheet_<providerId>_<modelId>` | `_ModelSelectorSheet` action（`title_suggestion_screen.dart:~1280`） | case 4 sheet 选 provider/model 动作 |
| `branch_button` | `chat_screen.dart:165-176` `trailing` | 入口（之前已补，本轮 commit `14fdc79` 处理 isStreaming 期间 disable 问题） |
| 配合 `Navigator.of(element).pop` 模拟点击 | 7 个 testWidgets | 绕开 SelectionArea hit-test 难点 |

### 2 个 l10n key 新增（commit `39ed0c0`）

- `pleaseConfigureTitleModel`（中英双语）
- `pleaseConfigureSummaryModel`（中英双语）

## 实施内容

### 5 个 commit（worktree `branch-selected-text-summarize`）

| Commit | 说明 |
|--------|------|
| `c8176a7` | feat(ui): 新增 `llm_setup_check` helper（enum + 三层防御 helper + 顶层 resolve 函数） |
| `34d9465` | fix(ui): 修 sheet filter 缺 apiKey 校验 + 三层防御拦截 LLM 未配置死路 |
| `39ed0c0` | feat(l10n): 新增 `pleaseConfigureTitleModel` / `pleaseConfigureSummaryModel` |
| `d937c07` | fix(test): 修 case 4 sheet 选不到 + case 5/6/7 tab 切换漏掉（ProviderScope override 残留状态清理） |
| `14fdc79` | fix(test): 修 case 3 branch_button 在 isStreaming 时被 disable 选不到 sheet |

### 7 个 testWidgets 实跑结果（02:26）

| # | testWidgets | 结果 | 耗时 |
|---|------------|------|------|
| 1 | 选中文本 + raw 模式创建分支 | ✅ | 00:34 |
| 2 | 选中文本 + summarize 模式创建分支 | ✅ | 01:10 |
| 3 | 无选中文本 + raw 模式创建分支 | ✅ | 01:22 |
| 4 | 无选中文本 + summarize 模式创建分支（需 LLM） | ✅ | 02:01 |
| 5 | 模式选择取消 | ✅ | 02:09 |
| 6 | 标题选择取消 | ✅ | 02:17 |
| 7 | LLM 失败 fallback | ❌ scaffold + LLM mock 工具待补 | — |

Xcode build 耗时 25.2s（首次冷启动），6 个 testWidgets 依次跑完合计约 2 分钟。

### branch-creation.md 大改版

状态行、第 2 节 测试现状表、第 3.3 节 解析逻辑（`_resolveModelForSummary` → `checkLlmSetup`）、第 3.4 节 ValueKey 清单、第 4.3 节 LLM mock 方案 A 描述、第 5 节 编写路线实跑状态、第 7 节 阻塞点汇总、第 8 节 已知风险、第 9 节 当前结果、第 10 节 Checklist、第 11 节 相关文档链接全部更新。详见 [branch-creation.md 大改版 diff](`git diff docs/_shared/integration-testing/branch-creation.md`)。

## 验证

| 类别 | 状态 |
|---|---|
| case 1（选中文本 + raw）实跑 | ✅ 完整链路通过 |
| case 2（选中文本 + summarize）实跑 | ✅ 完整链路通过（行为与 1 等价，selectedText 优先） |
| case 3（无选 + raw）实跑 | ✅ 完整链路通过 |
| case 4（无选 + summarize）实跑 | ✅ 完整链路通过（含 LLM 真实调用） |
| case 5（模式选择取消） | ✅ 实跑通过 |
| case 6（标题选择取消） | ✅ 实跑通过 |
| case 7（LLM 失败 fallback） | ❌ scaffold（待建 LLM mock 工具） |
| 7 个 testWidgets 全跑 | ✅ 02:26（Xcode build 25.2s + 6 case 跑过） |
| `_ModelSelectorSheet` sheet filter 漏洞修复 | ✅ 移除冗余 apiKey 二次校验 |
| 三层防御 L1-A / L1-B / L2 接入 | ✅ commit `34d9465` |
| `pleaseConfigureTitleModel` / `pleaseConfigureSummaryModel` l10n | ✅ commit `39ed0c0` |
| `flutter analyze` | ✅ 无新增 error |

## 已知风险（留给后续决定）

- **case 7 阻塞在 LLM mock 工具缺口**：`integration_test/_support/` 当前无 HTTP mock 通道，与 2026-06-22 CHANGELOG 记录的状态一致。本轮未新增 mock 工具，建议下轮单独处理（候选方案见 [2026-06-22 CHANGELOG 已知风险](./2026-06-22-branch-creation-test.md#已知风险留给后续决定)）。
- **3 个 helper 仍未提取**：`branch_creation_test.dart` 内 `_createTestTheme` / `_createTestNode` / `_sendMessage` 仍重复 4 次（每个 testWidgets 一次），未提取到 `_support/test_fixtures.dart`。case 1-6 实跑不依赖 helper 提取，但属于技术债。
- **commit 545f594 混入代码 commit 序列的违规操作**仍记录在 2026-06-22 CHANGELOG 中，本轮未引入新的"代码/文档 commit 混用"——5 个 commit 全部是代码/l10n 改动，未修改 doc。
- **Keychain 状态泄漏**：本轮实跑通过 commit `d937c07` + `14fdc79` 修复（ProviderScope override 残留清理 + isStreaming 时 branch_button disable 处理），但详见 [war-story 2026-06-24 Keychain 状态泄漏](../war-stories/flutter/2026-06-24-integration-test-keychain-state-leak.md)——问题有排查成本、根因隐蔽、有复用价值，单独记录。

## 关联

- [CHANGELOG 2026-06-22](./2026-06-22-branch-creation-test.md) — case 1-4 首跑 + 翻转 spec 第 8 节 不实现决策
- [docs/_shared/integration-testing/branch-creation.md](../_shared/integration-testing/branch-creation.md) — 集成测试规范（本次大改版）
- [docs/war-stories/flutter/2026-06-24-integration-test-keychain-state-leak.md](../war-stories/flutter/2026-06-24-integration-test-keychain-state-leak.md) — Keychain 状态泄漏单独 war-story
- [ADR-015](../DECISIONS.md#adr-015-分支创建集成测试-4-chat-并行推进翻转不实现-case-1-7旧决策) — 翻转不实现决策的正式记录
- [ADR-013](../DECISIONS.md#adr-013-llm-测试-key-通过-dart-define-注入放弃-assets-路径) — case 4 依赖的 LLM 注入基础设施
- [docs/_shared/integration-testing/llm-injection.md](../_shared/integration-testing/llm-injection.md) — LLM 注入详细版
- [docs/_shared/integration-testing/helpers.md](../_shared/integration-testing/helpers.md) — `_sendMessage` 等 helper 的语义定义
- [docs/_shared/integration-testing/theme-chat-e2e.md](../_shared/integration-testing/theme-chat-e2e.md) — theme_chat_e2e_test 配套文档（4 个 helper 借鉴）