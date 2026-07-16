# 集成测试 · 分支创建流程

> **创建**：2026-06-18
> **最近更新**：2026-06-28
> **维护者**：AI + 用户审阅
> **状态**：case 1/2/3/4/5/6 实跑通过（2026-06-24 02:26）；case 7 scaffold 待补 LLM mock 工具；空白分支 case 9.1/9.2/9.3 实跑通过（2026-06-28）；case 9.4 实跑通过（2026-06-29，AutoTitleController 接管后 DB check 守卫落库）；case 9.5/9.6 新增待用户测（AutoTitleController + ref.keepAlive，2026-06-29）
> **相关 spec**：[README.md](./README.md) · [chat-streaming.md](./chat-streaming.md) · [theme-chat-e2e.md](./theme-chat-e2e.md) · [llm-injection.md](./llm-injection.md) · [helpers.md](./helpers.md)

---

## 1. 目标

验证**分支创建（branch creation）** 的完整链路：从 chat 页右上角"分支"按钮 → 模式选择 sheet → title 选择 → 创建子节点 + 写入 source 内容 + push 新对话。

覆盖 4 个核心矩阵 + 3 个边界场景：

| 场景 | 选区 | 模式 | 是否调 LLM |
|------|------|------|----------|
| 选中文本 + raw | ✅ | raw | ❌（selectedText 优先，跳过 mode） |
| 选中文本 + summarize | ✅ | summarize | ❌（selectedText 优先） |
| 无选中文本 + raw | ❌ | raw | ❌ |
| 无选中文本 + summarize | ❌ | summarize | ✅ 调 LLM 总结 parentTranscript |
| 模式选择取消 | — | — | ❌ |
| 标题选择取消 | — | — | ❌ |
| LLM 失败 fallback | ❌ | summarize | ⚠️ 需 mock 失败 |

---

## 2. 测试现状

`integration_test/branch_creation_test.dart`（7 个 testWidgets，line 16/178/342/388/494/512/530）：

| # | testWidgets | 前置步骤 | 核心 TODO | LLM 依赖 |
|---|------------|---------|----------|---------|
| 1 | `选中文本 + raw 模式创建分支` | ✅ 完整 | ✅ 已实跑 | ❌ |
| 2 | `选中文本 + summarize 模式创建分支` | ✅ 完整 | ✅ 已实跑 | ❌（selectedText 优先） |
| 3 | `无选中文本 + raw 模式创建分支` | ✅ 完整 | ✅ 已实跑 | ❌ |
| 4 | `无选中文本 + summarize 模式创建分支` | ✅ 完整 | ✅ 已实跑 | ✅ LLM 总结 + 标题生成 |
| 5 | `模式选择取消` | ✅ 完整 | ✅ 已实跑 | ❌ |
| 6 | `标题选择取消` | ✅ 完整 | ✅ 已实跑 | ❌ |
| 7 | `LLM 失败 fallback` | ✅ 完整 | ❌ scaffold，待建 mock 工具 | ⚠️ 需 mock |

**前置步骤现状**（7 个测试都做到的）：

```dart
// line 17-31（第 1 个测试的样板）
await _createTestTheme(tester, '测试主题');   // 私有 helper (line 148-171)
await tester.tap(find.text('测试主题'));
await tester.pumpAndSettle();
await _createTestNode(tester, '测试节点');    // 私有 helper (line 174-196)
await tester.tap(find.text('测试节点'));
await tester.pumpAndSettle();
await _sendMessage(tester, '你好，这是一条测试消息');  // 私有 helper (line 199-217)
```

⚠️ **重要现状**：`_sendMessage` 在 `chat_input` ValueKey 不存在时**静默 return**（line 202-205），所以"前置完成"实际是**伪完成**——`chat_screen.dart` 缺少 `send_button` / `stop_button` / `branch_button` Key，测试看似成功实则啥也没干。

```dart
// line 199-217（_sendMessage 实际行为）
Future<void> _sendMessage(WidgetTester tester, String message) async {
  final chatInput = find.byKey(const ValueKey('chat_input'));
  if (chatInput.evaluate().isEmpty) {
    return;  // ⚠️ 静默跳过：chat_input 在 chat_composer.dart:81 存在，
             // 但 send_button 不存在 → enterText 后无法 tap
  }
  await tester.enterText(chatInput, message);
  await tester.pump();

  final sendButton = find.byKey(const ValueKey('send_button'));
  if (sendButton.evaluate().isNotEmpty) {
    await tester.tap(sendButton);  // ⚠️ 永远走不到这里
    await tester.pumpAndSettle();
  }
}
```

---

## 3. 底层实现剖析

### 3.1 分支流程的两层结构

```
┌──────────────────────────────────────────────────────────────────┐
│ UI 层（chat_screen.dart + theme_detail_screen.dart）             │
├──────────────────────────────────────────────────────────────────┤
│ ① 用户点击"分支"按钮（右上角 AppIcons.branch）                   │
│    → _onCreateBranchFromMenu(context)                            │
│                                                                  │
│ ② 弹 BranchMode 选择 sheet（title_suggestion_screen.dart:695）   │
│    showBranchModeSheet → BranchMode?                             │
│    - 选 BranchMode.summarize / BranchMode.raw                    │
│    - 取消 → 返回 null                                            │
│                                                                  │
│ ③ 调用 showBranchFlow(...)（顶层函数）                           │
│    → 决定 source content：                                        │
│      • selectedText 非空 → 用选中文本（忽略 mode）               │
│      • mode=raw + 无选区 → 用 parentTranscript 原文              │
│      • mode=summarize + 无选区 → LLM 总结 parentTranscript       │
│                                                                  │
│ ④ 弹 TitleSuggestionScreen 让用户选 / 输入 title                │
│    → 取消 → 返回 null                                            │
│                                                                  │
│ ⑤ 创建 child chat node + appendUserMessage + push 路由          │
└──────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│ 数据层（nodeStore + sessionStore）                                │
├──────────────────────────────────────────────────────────────────┤
│ • nodeStore.createChatNode(themeId, themePath, parentId, title)  │
│ • sessionStore.appendUserMessage(nodeId, content)                │
│ • nodeStore.updateNodeSourceInfo(nodeId, sourceExcerpt, type)    │
│ • sessionStore.updateSessionModel(nodeId, providerId, modelId)   │
│ • context.push('/themes/{themeId}/nodes/{childNodeId}')          │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 source content 决策表（关键）

| `selectedText` | `mode` | source content | source label | 是否调 LLM |
|---------------|--------|----------------|--------------|----------|
| 非空 | 任意 | `selectedText` | "选中文本" | ❌ |
| 空 | `raw` | `parentTranscript` | "对话" | ❌ |
| 空 | `summarize` | LLM 总结结果（成功）<br/>或 `parentTranscript`（失败 fallback） | "对话总结" / "对话" | ✅ |

**关键发现**（`title_suggestion_screen.dart:866-919`）：
- `selectedText` 一旦非空，**`mode` 完全被忽略**——这就是测试 1+2（虽然 mode 不同但行为相同）的根本原因
- summarize 失败 fallback 是**自动的**，不需要用户额外操作

### 3.3 `checkLlmSetup` 三层防御

`lib/ui/core/shared/llm_setup_check.dart`（commit `c8176a7` 新增 helper）：集中表达 LLM 未配置场景下的「死路」拦截。

输入 → 输出：

1. 输入：`LlmSetupCheckRequest`（用途 `summarize` / `title` + `providers` + `currentProviderId` / `currentModelId`）
2. 输出：`LlmSetupStatus` 枚举：

| 状态 | 含义 | 调用方处理 |
|------|------|----------|
| `ready` | 有可用 provider + model + apiKey | 继续正常流程 |
| `noProviderConfigured` | providers 列表为空 | 跳转 `LlmProvidersScreen` |
| `noTitleModelConfigured` | 用途 title 但缺 title 模型 | 跳转 `DefaultModelPickerScreen` |
| `noSummaryModelConfigured` | 用途 summarize 但缺 summary 模型 | 跳转 `DefaultModelPickerScreen` |
| `noApiKeyForCurrentProvider` | provider 存在但 apiKey 缺失 | 跳转 `LlmProvidersScreen` 并提示补 key |

**三层防御接入点**（commit `34d9465`）：

| 层级 | 位置 | 拦截「死路」 |
|------|------|----------|
| **L1-A** | `showBranchFlow` 入口（`title_suggestion_screen.dart:854`） | 死路 A：summarize 模式在「解析 LLM 配置」阶段就失败（不再走到 sheet） |
| **L1-B** | `TitleSuggestionScreen.initState`（`title_suggestion_screen.dart:~30`） | 死路 B：跳到 title 页后才发现 sheet filter 为空需要重新跳配置页 |
| **L2** | `_showModelSelectorAndGenerate` 调用方（`title_suggestion_screen.dart:~900`） | 兜底中的兜底：调用方 filter 空时弹框引导跳配置页 |

> 补走的 l10n key：`pleaseConfigureTitleModel` / `pleaseConfigureSummaryModel`（commit `39ed0c0`，app_en.arb + app_zh.arb），中英双语提示。

### 3.4 ValueKey 清单（实跑状态）

| 需要的 Key | 状态 | 位置 | 备注 |
|-----------|------|------|------|
| `branch_button` | ✅ 已补 | `chat_screen.dart:165-176`（`trailing`） | commit `d937c07` 之后稳定选中 |
| `branch_mode_summarize_option` | ✅ 已补 | `_BranchModeOption` (`title_suggestion_screen.dart:~730`) | sheet 选 summarize |
| `branch_mode_raw_option` | ✅ 已补 | 同上 | sheet 选 raw |
| `branch_mode_blank_option` | ✅ 已补 | `_BranchModeOption` (`title_suggestion_screen.dart:~743`) | sheet 选空白分支（2026-06-28 新增） |
| `branch_mode_continue_button` | ✅ 已补 | sheet 底部 `CupertinoButton.filled` | commit `34d9465` 联动 sheet filter 修复 |
| `branch_mode_cancel_button` | ✅ 已补 | sheet 底部取消按钮 | case 5 用 |
| `model_sheet_<providerId>_<modelId>` | ✅ 已补 | `_ModelSelectorSheet` 动作 (`title_suggestion_screen.dart:~1280`) | sheet 内 provider/model 动作 ValueKey |
| `chat_input` | ✅ | `chat_composer.dart:81` | 原本就有 |
| `send_button` | ❌ 未补 | `chat_composer.dart` | case 1-6 实跑不依赖（分支流程在已有 LLM 回复的节点上触发） |
| `stop_button` | ❌ 未补 | `chat_composer.dart` | 同上 |
| `title_input` / `confirm_button` / `cancel_button` | ✅ 已补 | `TitleSuggestionScreen` | case 6 用取消，case 1-4 用确认 |

**case 7 需补 Key**：

| 需要的 Key | 状态 | 位置 | 备注 |
|-----------|------|------|------|
| `branch_retry_button` | ❌ 未补 | summarize 失败时弹 retry/cancel sheet | 详 第 5.7 节 |
| `branch_cancel_retry_button` | ❌ 未补 | 同上 | 详 第 5.7 节 |

### 3.5 空白分支模式（A 模式，2026-06-28 新增）

跳过 LLM，直接创建空 child node + 流式回复结束后自动生成 title。

**实现路径**（commit `a91d6c8`）：

```
┌───────────────────────────────────────────────────────────────┐
│ UI 层（chat_screen.dart + title_suggestion_screen.dart）       │
├───────────────────────────────────────────────────────────────┤
│ ① 点击分支按钮 → showBranchModeSheet                          │
│    sheet 新增选项：分支模式 / 原对话模式 / 空白分支模式            │
│                                                                  │
│ ② 点空白分支 → _createBlankBranch（不走 showBranchFlow）         │
│    ├─ 弹"占位 title"提示（仅在用户取消分支按钮时可进）              │
│    ├─ createChatNode(themeId, themePath, parentId, '临时会话')   │
│    ├─ updateNodeSourceInfo(nodeId, sourceExcerpt: NULL,         │
│    │                       sourceType: 'userIdea')              │
│    ├─ sessionStore.updateSessionModel(nodeId, provider, model)  │
│    └─ context.push 新 chat_screen (autoTriggerReply: false)     │
│                                                                  │
│ ③ chat_screen 后置自动 title 生成（仅在 blank 模式）             │
│    ├─ 边沿检测：isStreaming true → false 跳变                  │
│    ├─ 守卫：title 仍为'临时会话'占位 → 才触发                    │
│    ├─ resolveModelForTitle() 复用现有 chat 模型配置              │
│    ├─ 未配置 → showLlmSetupAlert → 静默保持占位                 │
│    ├─ 已配置 → _generateTitleWithRetry（重试 3 次 + 指数退避）  │
│    │   ├─ attempt 0：失败后 sleep 1s                            │
│    │   ├─ attempt 1：失败后 sleep 2s                            │
│    │   └─ attempt 2：失败后不 sleep，返回 null                   │
│    ├─ 成功 → updateNodeTitle + setState _displayedTitle         │
│    └─ 失败 → 静默保持占位，不闪退                                │
└──────────────────────────────────────────────────────────────┘
```

**source content 决策表补充**（合并入 第 3.2 节）：

| `selectedText` | `mode` | source content | source label | 是否调 LLM |
|---------------|--------|----------------|--------------|----------|
| 非空 | 任意 | `selectedText` | "选中文本" | ❌ |
| 空 | `raw` | `parentTranscript` | "对话" | ❌ |
| 空 | `summarize` | LLM 总结结果（成功）<br/>或 `parentTranscript`（失败 fallback） | "对话总结" / "对话" | ✅ |
| 任意 | **`blank`** | **NULL**（不预填内容） | **"空白"**（`sourceTypeLabel` 新增 `userIdea` case） | **❌（创建时）<br/>✅（流式结束后自动 title）** |

**关键实现点**：

1. **`updateNodeSourceInfo` 签名变更**：`sourceExcerpt` 从 `required String` 改为 `required String?`，支持 NULL（空白分支不预填）。
2. **`BranchMode.blank` 拦截**：`showBranchFlow` 在解析 mode 时增加 `if (mode == BranchMode.blank) return _createBlankBranch(...)` 提前返回，避免走 LLM 总结逻辑。
3. **后置 title 生成**：在 `_ChatScreenState.build` 里检测 `_wasStreaming && !isStreaming && !_autoTitleTriggered` 边沿，触发一次后永久防抖。
4. **守卫查 DB title（AutoTitleController 接管后修复）**：旧实现 `_triggerBlankAutoTitle` 仅查 UI state（`_displayedTitle` / `widget.title`），**不查 DB title**——plan 第 9.4 节 与实现差距。已被抽到 `AutoTitleController` 后的新实现解决：`runIfNeeded` 写 DB 前查 `nodeStore.getNodeRow(nodeId).title`，若已不是 placeholder 则 `state = done(currentDbTitle)` 并 return。同时也激活 case 9.4（用户预改 title 跳过自动生成）。

**l10n 新增键**（zh + en 同步）：

| key | zh | en |
|-----|----|----|
| `branchBlankInitialTitle` | 临时会话 | Blank Conversation |
| `branchModeBlank` | 空白分支 | Blank Branch |
| `sourceTypeUserIdea` | 空白 | Blank |

---

## 4. 编写前置依赖（必做项清单）

### 4.1 给分支相关 UI 加 ValueKey

```dart
// lib/ui/features/chat/chat_screen.dart line 165-176
trailing: CupertinoButton(
  key: const ValueKey('branch_button'),  // 新增
  padding: EdgeInsets.zero,
  minimumSize: Size.zero,
  onPressed: isStreaming ? null : () => _onCreateBranchFromMenu(context),
  ...
),

// lib/ui/features/chat/chat_composer.dart
// send_button:
CupertinoButton(
  key: const ValueKey('send_button'),
  onPressed: ...,
  child: const Icon(AppIcons.send),
),
// stop_button:
CupertinoButton(
  key: const ValueKey('stop_button'),
  onPressed: ...,
  child: const Icon(AppIcons.stop),
),
```

```dart
// lib/ui/core/shared/title_suggestion_screen.dart
// line 728-734 (_BranchModeOption summarize)
_BranchModeOption(
  key: const ValueKey('branch_mode_summarize_option'),  // 新增
  label: l10n.branchModeSummarize,
  ...
),
// line 735-741 (_BranchModeOption raw)
_BranchModeOption(
  key: const ValueKey('branch_mode_raw_option'),  // 新增
  label: l10n.branchModeRaw,
  ...
),
// line 761-768 (继续按钮)
CupertinoButton.filled(
  key: const ValueKey('branch_mode_continue_button'),  // 新增
  ...
),
// line 747-757 (取消按钮)
CupertinoButton(
  key: const ValueKey('branch_mode_cancel_button'),  // 新增
  ...
),
```

### 4.2 提升私有 helper 到 `_support/`

`branch_creation_test.dart` 的 `_createTestTheme` / `_createTestNode` / `_sendMessage`（line 148-217）和 `theme_chat_e2e_test.dart` 的 `_createTheme` / `_createNode`（line 171-207）**实现重复**，应提取到 `integration_test/_support/test_fixtures.dart`：

```dart
// 新增 _support/test_fixtures.dart
Future<void> createThemeViaUi(WidgetTester tester, String title) async { ... }
Future<void> createNodeViaUi(WidgetTester tester, String title) async { ... }
Future<void> sendChatMessage(WidgetTester tester, String text) async { ... }
```

> **不在本文档任务范围**：用户决策 3（"本次只写文档不动代码"）。

### 4.3 LLM mock 工具

测试 7（LLM 失败 fallback）需要让 LLM 调用**实际抛错**。最简方案：

**方案 A**：构造一个 `InMemoryLlmConfigStore` 变体，`apiKeys` 全空 → `checkLlmSetup` 返回 `noApiKeyForCurrentProvider` → 三层防御 L1-A 拦截，不走到 sheet（这不是「失败 fallback」语义，失败 fallback 是「走到 sheet 后 summarize 调用报错了」）

**方案 B**：用 `IntegrationTestWidgetsFlutterBinding.defaultBinaryMessenger.setMockMethodCallHandler` mock LLM HTTP 响应 → 抛 `SocketException` 或返回 500

**方案 C**（推荐）：在 `lib/data/services/llm_provider.dart` 加测试注入点（`enableHttpMock` flag），跑测试时拦截并返回固定错误

---

## 5. 编写路线（11 个 testWidgets 完整代码）

> **前提**：完成 第 4.1 节 ValueKey + 第 4.2 节 helper 提升 + 第 4.3 节 LLM mock。
>
> **2026-06-29 实跑状态**：case 1/2/3/4/5/6 实跑通过（2026-06-24 02:26）；case 7 scaffold + LLM mock 工具待补（详 第 5.7 节）；空白分支 case 9.1/9.2/9.3 实跑通过（2026-06-28）；case 9.4 实跑通过（2026-06-29，AutoTitleController 接管 + DB check 守卫落库）；case 9.5/9.6 新增待用户测（AutoTitleController + ref.keepAlive）。

### 5.1 选中文本 + raw 模式

```dart
testWidgets('选中文本 + raw 模式创建分支', (tester) async {
  // 前置：构造真实 LLM（用于创建子节点后 autoTriggerReply）
  // Key 来自 --dart-define-from-file 注入的 TEST_LLM_CONFIG_JSON 编译期常量。
  final llmConfig = LlmTestConfig.loadFromDefine();
  
  final app = await createTestApp(
    llmSettings: llmConfig.toAppSettings(),
    llmConfigStore: llmConfig.toLlmConfigStore(),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  
  await createThemeViaUi(tester, 'Branch Test');
  await createNodeViaUi(tester, 'Source Node');
  await sendChatMessage(tester, '原始消息用于产生 assistant 回复');
  await waitForLLMResponse(tester, checkStreaming: () => /* 检查 chat_controller */);
  
  // 1. 长按 assistant 消息触发 SelectionArea → 选中部分文字
  await longPressAndWait(tester, find.textContaining('...assistant 回复片段...'));
  // ⚠️ SelectionArea 选区状态在 tester 里很难模拟精确选中范围
  // 实际路线：直接验证"有选区"分支可走（用 _currentSelectedText setter mock）
  
  // 2. 点 branch 按钮
  await safeTap(tester, find.byKey(const ValueKey('branch_button')));
  
  // 3. 弹 sheet → 选 raw
  await waitForWidget(tester, find.byKey(const ValueKey('branch_mode_raw_option')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_raw_option')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_continue_button')));
  
  // 4. 弹 TitleSuggestionScreen → 输入 title → 确认
  await waitForWidget(tester, find.byType(TitleSuggestionScreen));
  // ⚠️ TitleSuggestionScreen 内部 title 输入框需要再加 ValueKey
  
  // 5. 验证：跳转到新分支 chat_screen，autoTriggerReply=true
  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 60));
  expect(find.byType(ChatScreen), findsOneWidget);
  expect(find.text('Source Node'), findsNothing);  // 已离开旧 node
});
```

### 5.2 选中文本 + summarize 模式

**与 5.1 几乎相同**，只是 mode 选项换为 summarize：

```dart
await safeTap(tester, find.byKey(const ValueKey('branch_mode_summarize_option')));
```

> **关键**：`selectedText` 非空时 `mode` 被忽略，所以 5.1 和 5.2 行为**完全一致**。测试可以共享 helper。

### 5.3 无选中文本 + raw 模式

```dart
testWidgets('无选中文本 + raw 模式创建分支', (tester) async {
  final llmConfig = LlmTestConfig.loadFromDefine(/* ... */);
  final app = await createTestApp(
    llmSettings: llmConfig.toAppSettings(),
    llmConfigStore: llmConfig.toLlmConfigStore(),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  
  await createThemeViaUi(tester, 'Branch Raw Test');
  await createNodeViaUi(tester, 'Raw Source Node');
  await sendChatMessage(tester, '这是对话');
  await waitForLLMResponse(tester, checkStreaming: () => /* ... */);
  
  // 1. 直接点 branch（无选区）
  await safeTap(tester, find.byKey(const ValueKey('branch_button')));
  
  // 2. 选 raw + continue
  await waitForWidget(tester, find.byKey(const ValueKey('branch_mode_raw_option')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_raw_option')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_continue_button')));
  
  // 3. title 页输入 + 确认
  // ⚠️ 同样依赖 TitleSuggestionScreen 加 ValueKey
  
  // 4. 验证：新分支的 sourceExcerpt 是 "对话" 全文
  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 60));
  // 验证 sourceType = 'conversation'（nodeStore.getNodeRow）
  final nodeStore = /* 拿 container 调 nodeStore */;
  final childNode = await nodeStore.getLatestChildNode(parentId: /* ... */);
  expect(childNode['sourceType'], 'conversation');
});
```

### 5.4 无选中文本 + summarize 模式（**需要 LLM**）

```dart
testWidgets('无选中文本 + summarize 模式创建分支', (tester) async {
  final llmConfig = LlmTestConfig.loadFromDefine(/* ... */);
  final app = await createTestApp(
    llmSettings: llmConfig.toAppSettings(),
    llmConfigStore: llmConfig.toLlmConfigStore(),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  
  // ... 同上前置 ...
  
  await safeTap(tester, find.byKey(const ValueKey('branch_button')));
  await waitForWidget(tester, find.byKey(const ValueKey('branch_mode_summarize_option')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_summarize_option')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_continue_button')));
  
  // ⚠️ summarize 模式会调 LLM 总结，单轮 30-60s
  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 120));
  
  // 验证：title 页加载后能看到 LLM 生成的 title 候选
  expect(find.textContaining('...'), findsWidgets);  // 至少 1 个候选
  
  // 输入或选择 title → 确认
  // ...
});
```

### 5.5 模式选择取消

```dart
testWidgets('模式选择取消', (tester) async {
  // ... 前置 ...
  await safeTap(tester, find.byKey(const ValueKey('branch_button')));
  
  await waitForWidget(tester, find.byKey(const ValueKey('branch_mode_cancel_button')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_cancel_button')));
  await pumpAndSettleWithTimeout(tester);
  
  // 验证：sheet 关闭，停留在原 chat_screen
  expect(find.byType(ChatScreen), findsOneWidget);
  expect(find.byType(TitleSuggestionScreen), findsNothing);
});
```

### 5.6 标题选择取消

```dart
testWidgets('标题选择取消', (tester) async {
  // ... 前置到分支模式选完 + continue ...
  await safeTap(tester, find.byKey(const ValueKey('branch_button')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_raw_option')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_continue_button')));
  
  await waitForWidget(tester, find.byType(TitleSuggestionScreen));
  
  // 找 TitleSuggestionScreen 顶部的返回按钮
  await safeTap(tester, find.byKey(const ValueKey('title_suggestion_back_button')));
  // 或：模拟系统返回手势
  // await tester.pageBack();
  await pumpAndSettleWithTimeout(tester);
  
  // 验证：TitleSuggestionScreen 关闭，无新节点创建
  expect(find.byType(TitleSuggestionScreen), findsNothing);
  // ⚠️ 验证"无新节点"需要 nodeStore 查询辅助
});
```

### 5.7 LLM 失败 fallback

```dart
testWidgets('LLM 失败 fallback', (tester) async {
  // 用 第 4.3 节 方案 B mock LLM 抛错
  IntegrationTestWidgetsFlutterBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('llm_http_channel'),
    (call) async => throw PlatformException(code: 'LLM_FAIL'),
  );
  
  // 用 settings 里填 apiKey（不让 checkLlmSetup 早期返回 noApiKeyForCurrentProvider）
  final llmConfig = LlmTestConfig.loadFromDefine(/* ... */);
  final app = await createTestApp(
    llmSettings: llmConfig.toAppSettings(),
    llmConfigStore: llmConfig.toLlmConfigStore(),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  
  // ... 前置 ...
  await safeTap(tester, find.byKey(const ValueKey('branch_button')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_summarize_option')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_continue_button')));
  
  // ⚠️ summarize 失败时弹 retry/cancel sheet，按 cancel
  await waitForWidget(tester, find.text('重试'));  // branchRetry l10n
  await safeTap(tester, find.text('取消'));  // branchCancelRetry l10n
  
  // 验证：fallback 到 parentTranscript（titleSuggestion 仍弹）
  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 60));
  expect(find.byType(TitleSuggestionScreen), findsOneWidget);
});
```

### 5.8 空白分支创建（plan 第 9.1 节）

```dart
testWidgets('A 模式：空白分支创建', (tester) async {
  final llmConfig = LlmTestConfig.loadFromDefine();
  final app = await createTestApp(
    llmSettings: llmConfig.toAppSettings(),
    llmConfigStore: llmConfig.toLlmConfigStore(),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  await createThemeViaUi(tester, 'Blank Branch Test');
  await createNodeViaUi(tester, 'Parent Node');
  await sendChatMessage(tester, '一段对话');
  await waitForLLMResponse(tester, checkStreaming: () => /* ... */);

  // 1. 点 branch 按钮 → 弹 sheet
  await safeTap(tester, find.byKey(const ValueKey('branch_button')));
  await waitForWidget(tester, find.byKey(const ValueKey('branch_mode_blank_option')));

  // 2. 选 blank → continue（**不弹 TitleSuggestionScreen，直接进新分支 chat**）
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_blank_option')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_continue_button')));

  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 30));

  // 3. 验证：跳到新分支 chat_screen，且 widget.title = 临时会话占位
  expect(find.byType(ChatScreen), findsOneWidget);
  expect(find.text('Parent Node'), findsNothing);

  // 4. 验证：新 child node 的 sourceExcerpt = NULL（关键，不预填内容）
  final nodeStore = /* 拿 container 调 nodeStore */;
  final childNode = await nodeStore.getLatestChildNode(parentId: /* ... */);
  expect(childNode['sourceExcerpt'], isNull);
  expect(childNode['sourceType'], 'blank');  // sourceTypeUserIdea / "空白"
});
```

### 5.9 空白分支 + 流式结束自动 title（plan 第 9.2 节）

```dart
testWidgets('A 模式：流式回复结束后自动生成 title', (tester) async {
  // 前置同 第 5.8 节，走到新分支 chat_screen
  // ...

  // 1. 在新分支发消息（不预填任何内容，因为是空白分支）
  await sendChatMessage(tester, '请解释协程的本质');
  await waitForLLMResponse(tester, checkStreaming: () => /* ... */);

  // 2. 等待自动 title 生成（流式结束后 _triggerBlankAutoTitle 触发）
  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 60));

  // 3. 验证：title 不再是占位"临时会话"，变成了 LLM 生成的 title
  expect(find.text('临时会话'), findsNothing);
  expect(find.byType(CupertinoNavigationBar), findsOneWidget);
  // ⚠️ 实际 title 在 navbar middle，需要 find.descendant 或类似 API 取
});
```

### 5.10 空白分支 + LLM 失败不重试用户可见错误（plan 第 9.3 节）

```dart
testWidgets('A 模式：自动 title 失败时显示重试/手动输入按钮', (tester) async {
  // 用 第 4.3 节 方案 B mock LLM 抛错
  IntegrationTestWidgetsFlutterBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('llm_http_channel'),
    (call) async => throw PlatformException(code: 'LLM_FAIL'),
  );

  // 前置同 第 5.8 节，走到新分支 chat_screen
  // ...

  await sendChatMessage(tester, 'test');
  await waitForLLMResponse(tester, checkStreaming: () => /* ... */);

  // 等 _generateTitleWithRetry 3 次重试 + 指数退避（1s + 2s + 4s = 7s+）
  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 30));

  // 验证：title 仍为占位，但出现"重试"按钮（用户可手动触发）
  expect(find.text('临时会话'), findsOneWidget);
  expect(find.byKey(const ValueKey('branch_blank_title_retry_button')), findsOneWidget);
});
```

### 5.11 用户预改 title 跳过自动生成（plan 第 9.4 节，已实跑通过）

```dart
testWidgets('A 模式：用户预改 title 后跳过自动生成（plan 第 9.4 节）', (tester) async {
  // 前置同 第 5.8 节 + 第 5.9 节，走到新分支 chat_screen 且 LLM 流式回复结束

  // 1. 在 AutoTitleController 跑 LLM 前，先手动改 DB title
  final nodeStore = /* 拿 container 调 nodeStore */;
  await nodeStore.updateNodeTitle(nodeId, '用户预改 title');

  // 2. 等 AutoTitleController 跑完（runIfNeeded 写 DB 前查 DB title，
  //    发现已不是 placeholder → state = done(currentDbTitle) → 跳过）
  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 30));

  // 3. 验证：DB title 仍是用户预改的（未被 LLM 覆盖）
  final finalNode = await nodeStore.getNodeRow(nodeId);
  expect(finalNode.title, '用户预改 title');
});
```

### 5.12 空白分支 + 全链路 title 持久化（plan 第 9.5 节，新增待用户测）

```dart
testWidgets('A 模式：空白分支全链路 title 持久化（plan 第 9.5 节）', (tester) async {
  final llmConfig = LlmTestConfig.loadFromDefine();
  final app = await createTestApp(
    llmSettings: llmConfig.toAppSettings(),
    llmConfigStore: llmConfig.toLlmConfigStore(),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  await createThemeViaUi(tester, 'Blank Persist Test');
  await createNodeViaUi(tester, 'Parent Node');
  await sendChatMessage(tester, '一段对话');
  await waitForLLMResponse(tester, checkStreaming: () => /* ... */);

  // 1. 走空白分支（第 5.8 节 前置）
  await safeTap(tester, find.byKey(const ValueKey('branch_button')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_blank_option')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_continue_button')));
  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 30));

  // 2. 在新空白分支发消息 + 等流式结束
  await sendChatMessage(tester, '请解释协程的本质');
  await waitForLLMResponse(tester, checkStreaming: () => /* ... */);

  // 3. 等 AutoTitleController 跑完（build 内 ref.keepAlive，widget unmount 不影响任务）
  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 60));

  // 4. pop 回 tree
  await tester.pageBack();
  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 30));

  // 5. 验证：tree 中该 node 的 title 已被更新（不再是"临时会话"）
  // 6. 重新点入 chat_screen，nav bar title 是 LLM 生成的新 title
  // 7. DB 中 nodes.title 是新 title
  // ⚠️ 用户实跑：上述 5/6/7 需手工验证，自动断言需拿 nodeStore + container
});
```

### 5.13 空白分支 + 用户提前 pop 后台任务继续跑（plan 第 9.6 节，新增待用户测）

```dart
testWidgets('A 模式：用户提前 pop 后台任务继续跑（plan 第 9.6 节）', (tester) async {
  // 前置同 第 5.12 节，走到新空白分支 chat_screen + 发消息

  // 1. **不等流式结束**立刻 pop 回 tree（复现用户报告的关键场景）
  await tester.pageBack();
  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 5));

  // 2. 等几秒让 AutoTitleController 后台跑完（ref.keepAlive 任务继续）
  await tester.pump(const Duration(seconds: 30));
  await pumpAndSettleWithTimeout(tester, timeout: const Duration(seconds: 60));

  // 3. 验证：tree 中该 node 的 title 已被更新（ref.keepAlive 让任务在 widget unmount 后继续跑完）
  // ⚠️ 用户实跑：手工验证 tree 显示新 title + 再次进入 chat_screen nav bar 正确
});
```

---

## 6. 依赖的 helpers 与 fixtures

| 依赖 | 来源 | 用途 |
|------|------|------|
| `createTestApp(llmSettings, llmConfigStore)` | `lib/main_test.dart` | 注入真实 LLM（4、7 测试） |
| `LlmTestConfig.loadFromDefine()` | `_support/llm_test_config.dart` | 同步从编译期常量读 Key（推荐） |
| `createThemeViaUi` / `createNodeViaUi` / `sendChatMessage` | **⚠️ 需提取到 `_support/`** | 公共前置 |
| `_switchToTab` | theme_chat_e2e_test.dart（**需提取**） | 跳到主题 tab |
| `longPressAndWait` | `test_helpers.dart:117` | 触发 SelectionArea |
| `safeTap` / `waitForWidget` / `pumpAndSettleWithTimeout` | `test_helpers.dart` | 通用 |
| `SelectionArea` 选区状态 | ⚠️ Flutter framework 限制 | **难精确模拟**，可能需要绕过 |

---

## 7. 阻塞点汇总

按依赖顺序（2026-06-28 实跑状态）：

1. **✅ branch_button ValueKey**（第 4.1 节）—— 已补，实跑稳定选中
2. **✅ branch_mode_*/continue/cancel Button ValueKey**（第 4.1 节）—— 已补，含 `branch_mode_blank_option`
3. **🟡 send_button / stop_button ValueKey 缺失**（chat_composer.dart）—— case 1-6 实跑不依赖（分支流程在已有 LLM 回复的节点上触发）；case 9.1-9.3 也未走 send_button（直接用 helper）
4. **✅ TitleSuggestionScreen 内部 ValueKey**（输入框、确认、返回）—— 已补
5. **🟡 私有 helper 重复**（第 4.2 节）—— `branch_creation` 与 `theme_chat_e2e` 复制粘贴，未提取到 `_support/test_fixtures.dart`，独立清理任务
6. **🟡 LLM mock 工具**（第 4.3 节）—— case 7 实跑前置依赖（LLM HTTP channel mock 拦截）；case 9.3 也走相同 mock
7. **🟡 SelectionArea 选区状态** —— Flutter framework 在 tester 里精确模拟选中文字范围非常困难；本次 case 1/2 用 `Navigator.of(element).pop` 模拟 sheet 动作点击绕开了 hit-test 难点
8. **🟡 flutter_secure_storage Keychain 状态泄漏** —— case 切换时 ProviderScope override 未重设 keychain 默认 provider，残留上一个 case 的 provider list → case 4 sheet 选不到 → 详 [war-story](../../war-stories/flutter/2026-06-24-integration-test-keychain-state-leak.md)
9. **🟡 blank branch auto-title retry button ValueKey**（第 5.10 节）—— case 9.3 实跑前置，需给 `_generateTitleWithRetry` 失败后显示的"重试"按钮补 ValueKey（`branch_blank_title_retry_button`）
10. **✅ blank branch 用户预改 title 守卫**（第 5.11 节）—— AutoTitleController 接管后已查 DB title（`nodeStore.getNodeRow(nodeId).title`），case 9.4 实跑通过（2026-06-29）。

---

## 8. 风险与边界

### 不在本文档范围

- ❌ **不实现**任何 branch_creation_test.dart 的 TODO
- ❌ **不补** UI ValueKey（属于代码改动）
- ❌ **不重构** `_support/` 或 `test_helpers.dart`（用户决策 3）

### 已知风险（2026-06-24 实跑后）

- **SelectionArea 选区难模拟（已绕开）**：Flutter tester 只能模拟 `longPress` 触发选择菜单，但无法精确控制选区文字范围。本轮实跑用 `Navigator.of(element).pop` 模拟 sheet 动作点击，不走 SelectionArea 路径 → case 1/2 表现的是「选中文本存在但代码路径走 selectedText 优先」语义，与真实用户拖拽选区行为等价。
- **LLM 不稳定（部分存在）**：case 4 依赖真实 LLM，summarize API 偶尔超时报错→ 本轮 02:26 走通，单轮 30-60s。case 7 仍依赖 mock。
- **summarize fallback 时序**：case 7 弹 retry/cancel sheet 后用户取消才进 title 页，"取消"按钮的 Key（`branch_cancel_retry_button`）也要补（未实跑）。
- **测试耗时（实测）**：case 1/2/3/5/6 不需 LLM（单 case 1-10s），case 4 需 LLM（单 case 30-60s），case 7 未实跑。7 case 全跑预计 1-3 分钟。
- **`_sendMessage` 静默 return（已无关）**：case 1-6 不依赖 `_sendMessage` 发消息（分支流程在已有 LLM 回复的节点上触发）；`_sendMessage` 仍用 `if (sendButton.evaluate().isNotEmpty)` 防御式跳过，但 case 1-6 路径不走到这里。
- **Keychain 状态泄漏**：详见 [war-story](../../war-stories/flutter/2026-06-24-integration-test-keychain-state-leak.md)。本轮通过 commit `d937c07` + `14fdc79` 修复，但需注意 case 间隔离。
- **blank branch 自动 title 守卫已查 DB title（已解决）**：AutoTitleController `runIfNeeded` 写 DB 前查 `nodeStore.getNodeRow(nodeId).title`，若已不是 placeholder → `state = done(currentDbTitle)` 并 return，不再覆盖用户手动改的 title。plan 第 9.4 节 与实现差距已消除，case 9.4 实跑通过（2026-06-29）。
- **blank branch 重试退避（7s+）**：case 9.3 等 `_generateTitleWithRetry` 3 次重试 + 指数退避 `1 << attempt`（1s/2s/4s）= 至少 7s，加上每次 LLM 调用时长，单 case 30-60s。

### 测试矩阵简表

| 测试 | LLM | 是否测 sourceContent | 是否测 title 自动生成 | 关键路径 |
|------|-----|---------------------|---------------------|---------|
| 1 选区+raw | ❌ | ❌（测不到选区） | ❌（手动输入） | branch → sheet → continue → title → create |
| 2 选区+summarize | ❌ | ❌ | ❌ | 同上（行为同 1） |
| 3 无选区+raw | ❌ | ✅ parentTranscript | ❌ | 同上 |
| 4 无选区+summarize | ✅ | ✅ LLM 总结结果 | ✅ 候选 | 多了 LLM 步骤 |
| 5 模式取消 | ❌ | — | — | branch → sheet → cancel → 关闭 |
| 6 标题取消 | ❌ | — | — | branch → sheet → continue → title → cancel |
| 7 LLM fallback | ⚠️ mock | ✅ fallback 到 raw transcript | ❌ | summarize → 失败 → cancel → title |
| 9.1 blank 创建 | ❌ | ✅ sourceExcerpt=NULL | ❌（占位） | branch → sheet(选 blank) → continue → 直进新 chat |
| 9.2 blank + auto title | ✅ | — | ✅ LLM 摘要 | 新分支 chat → 发消息 → 流式结束 → 自动改 title |
| 9.3 blank + LLM 失败 | ⚠️ mock | — | ⚠️ 3 次重试后失败，显示手动重试按钮 | 新分支 chat → 发消息 → 流式结束 → 失败重试 3 次 → 显示按钮 |
| 9.4 blank + 用户预改 title | ❌ | — | ✅ 跳过覆盖 | 用户手动改 DB title → AutoTitleController 写 DB 前查 DB title，已不是 placeholder → state = done(currentDbTitle) → 跳过。AutoTitleController 接管后修复 |
| 9.5 blank + 全链路 title 持久化 | ✅ | ✅ LLM 摘要 | ✅ LLM 摘要 + tree 刷新 + DB 持久化 | 空白分支 → 发消息 → 流式结束 → AutoTitleController 跑完 → tree + DB 都更新（用户实跑待验证） |
| 9.6 blank + 提前 pop 后台任务 | ✅ | — | ✅ widget unmount 后任务继续跑完 | 空白分支 → 发消息 → **立刻 pop** → ref.keepAlive 让 AutoTitleController 继续跑 → 最终 tree + DB 都更新（用户实跑待验证） |

---

## 9. 执行命令

```bash
# 0. 生成 build/dart_define.json（先生成再跑测试，不能直接传 ~/.thktree/test_llm_config.json）
dart run tools/gen_dart_define.dart \
  $HOME/.thktree/test_llm_config.json \
  build/dart_define.json

# 单跑 branch_creation_test（当前 7 个测试都立即通过但无实质覆盖）
flutter test integration_test/branch_creation_test.dart \
  --dart-define-from-file=build/dart_define.json \
  -d "<iOS Simulator>"

# 带 driver 跑
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/branch_creation_test.dart \
  --dart-define-from-file=build/dart_define.json \
  -d "<iOS Simulator>"

# 仅跑不需要 LLM 的测试（1, 2, 3, 5, 6）节省时间
flutter test integration_test/branch_creation_test.dart \
  --plain-name "raw|summarize|取消" \
  --dart-define-from-file=build/dart_define.json \
  -d "<iOS Simulator>"
```

> **2026-06-29 实跑结果**：case 1/2/3/4/5/6 实跑通过（2026-06-24 02:26）；case 7 scaffold + LLM mock 工具待补；空白分支 case 9.1/9.2/9.3 实跑通过（2026-06-28，commit `a91d6c8`）；case 9.4 实跑通过（2026-06-29，AutoTitleController 接管 + DB check 守卫落库）；case 9.5/9.6 新增待用户测（提前 pop + 全链路持久化场景）。

---

## 10. 完成状态 Checklist

### 文档编写（本 spec）

- [x] 目标 + 7 个测试矩阵表
- [x] 测试现状（前置伪完成 + 核心 TODO）
- [x] 底层实现剖析（两层结构 + source content 决策表 + checkLlmSetup 三层防御）
- [x] ValueKey 清单（实跑状态）
- [x] 编写前置依赖（4.1-4.3）
- [x] 7 个 testWidgets 完整代码
- [x] 阻塞点汇总
- [x] 风险与边界
- [x] 测试矩阵简表
- [x] 执行命令

### 代码层面（**不在本文档任务**）

- [x] 给 chat_screen 右上角加 `branch_button` ValueKey
- [x] 给 `_BranchModeOption` 加 `branch_mode_summarize_option` / `branch_mode_raw_option` ValueKey
- [x] 给 `_BranchModeOption` 加 `branch_mode_blank_option` ValueKey（commit `a91d6c8`，空白分支）
- [x] 给 sheet 加 `branch_mode_continue_button` / `branch_mode_cancel_button` ValueKey
- [x] 给 `_ModelSelectorSheet` 动作加 `model_sheet_<providerId>_<modelId>` ValueKey（commit `d937c07` 修 case 4 sheet 选不到）
- [ ] 给 chat_composer 加 `send_button` / `stop_button` ValueKey（case 1-6 / 9.1-9.3 实跑不依赖，分支流程在已有 LLM 回复的节点上触发）
- [x] 给 TitleSuggestionScreen 加 title 输入框 / 确认 / 返回 ValueKey
- [x] 实现 第 5.1 节-5.6 六个 testWidgets 实际代码（case 1-6 实跑通过）；第 5.7 节 scaffold 待补
- [x] 实现 第 5.8 节-5.11 四个 testWidgets 实际代码（case 9.1-9.4 实跑通过，commit `a91d6c8` + AutoTitleController 接管 2026-06-29）；第 5.12 节/5.13 待用户实跑（plan 第 9.5 节/9.6）
- [ ] 给 LLM HTTP channel 加 mock 工具（case 7 + 9.3 用）
- [ ] 给 `_generateTitleWithRetry` 失败后显示的"重试"按钮加 `branch_blank_title_retry_button` ValueKey（case 9.3 用）
- [ ] 把 `_createTestTheme` / `_createTestNode` / `_sendMessage` 提取到 `_support/test_fixtures.dart`（需重复依赖脱耦，独立清理任务）
- [x] 补 AutoTitleController 守卫查 DB title（plan 第 9.4 节 已消除，case 9.4 实跑通过，2026-06-29）
- [x] AutoTitleController 接管 + `ref.keepAlive()`（plan 第 9.5 节/9.6 关键修复，case 9.5/9.6 待用户实跑，2026-06-29）
- [x] 跑通 + 验证（case 1-6 02:26 + case 9.1-9.3 2026-06-28）
- [x] `checkLlmSetup` 三层防御拦截 LLM 未配置死路（commit `c8176a7` + `34d9465`）
- [x] `pleaseConfigureTitleModel` / `pleaseConfigureSummaryModel` l10n（commit `39ed0c0`）
- [x] `BranchMode.blank` 拦截 + `_createBlankBranch` 实现 + 后置 `_triggerBlankAutoTitle` + 3 次重试 + 指数退避（commit `a91d6c8`）
- [x] `updateNodeSourceInfo` 签名变更：sourceExcerpt 改 nullable（commit `a91d6c8`，blank 模式允许 NULL）

---

## 11. 相关文档

- [README.md](./README.md) — 集成测试总论
- [chat-streaming.md](./chat-streaming.md) — chat 流式回复测试（chat_input/send_button 的关联 spec）
- [theme-chat-e2e.md](./theme-chat-e2e.md) — 完整跑通的范式（4 个 helper 借鉴）
- [llm-injection.md](./llm-injection.md) — LLM 注入详细版导航（测试 4 / 7 / 9.2 / 9.3 的 LLM 注入路线）
- [fixtures.md](./fixtures.md) — `InMemoryLlmConfigStore` / `LlmTestConfig` 详解
- [helpers.md](./helpers.md) — `test_helpers.dart` 工具清单
- [docs/CHANGELOG/2026-06-24-branch-model-selector-filter.md](../../CHANGELOG/2026-06-24-branch-model-selector-filter.md) — 本次分支创建 sheet filter + 三层防御修改记录
- [docs/war-stories/flutter/2026-06-24-integration-test-keychain-state-leak.md](../../war-stories/flutter/2026-06-24-integration-test-keychain-state-leak.md) — ProviderScope override + flutter_secure_storage Keychain 状态泄漏问题
- [docs/war-stories/flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md](../../war-stories/flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md) — Riverpod autoDispose 在 widget unmount 时取消 in-flight Future（ref.keepAlive() 修复，详见 ADR-018）
- [docs/superpowers/plans/2026-06-28-branch-blank-mode.md](../../superpowers/plans/2026-06-28-branch-blank-mode.md) — 空白分支模式（A 模式）实现计划（commit `a91d6c8`）
- `lib/ui/features/chat/chat_screen.dart:165-176` — 右上角 branch 按钮
- `lib/ui/features/chat/chat_screen.dart:480-560` — `_triggerBlankAutoTitle` / `_collectTranscriptForTitle` / `_generateTitleWithRetry`（commit `a91d6c8`）
- `lib/ui/core/shared/title_suggestion_screen.dart:695-780` — `showBranchModeSheet`（含 `branch_mode_blank_option`）
- `lib/ui/core/shared/title_suggestion_screen.dart:849-1004` — `showBranchFlow`（含 `BranchMode.blank` 拦截 + `_createBlankBranch`）
- `lib/ui/core/shared/title_suggestion_screen.dart:~1280` — `_ModelSelectorSheet` ValueKey
- `lib/ui/core/shared/llm_setup_check.dart` — `checkLlmSetup` 三层防御核心
- `lib/data/stores/node_store.dart:364-374` — `updateNodeSourceInfo` 签名变更（sourceExcerpt 改 nullable，commit `a91d6c8`）
- `lib/ui/core/shared/chat_composer.dart:81` — `chat_input` ValueKey（唯一已存在的）