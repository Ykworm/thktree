# 分支创建：选中文本支持 summarize（方案 C）

> 草稿版本：v1 · 待用户确认
> 关联：`lib/ui/core/shared/title_suggestion_screen.dart` `lib/ui/features/chat/chat_screen.dart` `lib/data/services/title_suggestion_service.dart`

## 背景

`lib/ui/core/shared/title_suggestion_screen.dart:871` 的 `showBranchFlow` 当前硬编码：**只要 `selectedText` 非空就走 raw 路径，忽略 `mode`**。

```dart
if (selectedText != null && selectedText.isNotEmpty) {
  sourceContent = selectedText;
  sourceLabel = sourceLabelOverride ?? l10n.titleSourceSelection;
  // ↑ 提前 return，下面 mode == raw / mode == summarize 的判断都不会执行
}
```

这是 **dead option 反模式**：用户从 chat 顶部点 branch 按钮 → 弹 mode sheet（raw / summarize）→ 即使选 summarize，行为仍和 raw 一致。用户被要求做一个不会被执行的选择。

## 目标行为（方案 C）

| 场景 | mode | 行为 |
|------|------|------|
| 无选区 | raw | 用 `parentTranscript` 原文（不变） |
| 无选区 | summarize | LLM 总结 `parentTranscript`（不变） |
| 有选区 | raw | 直接用 `selectedText`（不变） |
| **有选区** | **summarize** | **LLM 总结 `selectedText`（新增）** |

"summarize + 选区"的 LLM 失败时，fallback 到 `selectedText`（而不是 `parentTranscript`），保持"分支上下文与选区相关"的语义。

## 改动点

### 1. `lib/ui/core/shared/title_suggestion_screen.dart:854-924` — `showBranchFlow` 优先级重排

把"selectedText 非空短路"改为"按 mode 分流，selectedText 作为 source 内容参与决策"：

```dart
final String source;
final String label;
if (mode == BranchMode.raw) {
  source = selectedText?.isNotEmpty == true ? selectedText : parentTranscript;
  label  = selectedText?.isNotEmpty == true
      ? (sourceLabelOverride ?? l10n.titleSourceSelection)
      : (sourceLabelOverride ?? l10n.titleSourceConversation);
} else {
  // summarize：调 LLM
  ...
}
```

同时更新 `nodeSourceType` 决策表（第 959-965 行）：新增 `'selectedTextSummary'`。

### 2. `lib/data/services/title_suggestion_service.dart` — 新增 `summarizeSelection`

`_summarySystemPrompt`（第 28-34 行）当前明确写"给定一段用户与助手的完整对话"——选区文本不是对话。新增一个方法处理选区文本：

```dart
static const _selectionSummarySystemPrompt = '''
你是一个文本总结助手。给定一段用户从对话中选中的文本片段，
请生成一段简洁的总结，作为新对话的上下文起点。要求：
1. 保留选区中的关键事实、结论、术语、决定。
2. 控制在合理篇幅（一般 200~500 字），语言简洁清晰。
3. 不要添加原选区中没有的信息，不要替用户做判断。
4. 使用与选区相同的语言输出。''';

static Future<String> summarizeSelection({
  required String selection,
  required LlmProviderConfig provider,
  required String modelId,
  required String apiKey,
  required int contextWindow,
  CancelToken? cancelToken,
}) async {
  // 复用 _truncateByMessages fallback（选区无 ## user 标记会走尾部截断）
  final truncated = _truncateByMessages(selection, contextWindow);
  ...
  user prompt: '请总结以下选中文本：\n\n---\n$truncated'
}
```

`_summarizeWithLifecycleAndRetry` 也对应新增 `_summarizeSelectionWithLifecycleAndRetry`，或参数化为 `summaryKind: 'conversation' | 'selection'`。

### 3. l10n 新增

| key | zh | en |
|---|---|---|
| `titleSourceSelectionSummary` | 选中文本总结 | Selected Text Summary |

`branchModeSheetTitle` / `branchModeSummarize` / `branchModeRaw` 保持不变——sheet 自身无感，mode 语义不变。

### 4. `nodeSourceType` 决策表（第 959-965 行）

```dart
final nodeSourceType = sourceLabelOverride != null
    ? 'note'
    : (mode == BranchMode.summarize && selectedText?.isNotEmpty == true)
        ? 'selectedTextSummary'
        : selectedText?.isNotEmpty == true
            ? 'selectedText'
            : (mode == BranchMode.summarize)
                ? 'summary'
                : 'conversation';
```

需要检查 `lib/data/services/storage_format` / `docs/_shared/storage-format.md` 是否需要登记 `'selectedTextSummary'` 新枚举值。

## 验收方式

按"测试与验收策略"：Flutter 项目默认优先关键路径集成测试。

### 集成测试（新增 2 个用例）

`integration_test/branch_creation_test.dart` 新增：

1. **`branch_with_selected_text_summarize_uses_llm_summary`**
   - 准备：chat 含若干消息，长按选中某段
   - 操作：点 branch → sheet 选 summarize
   - 断言：新 child node 的首条 user 消息 **不是** selectedText 原文，**不是** parentTranscript，是 LLM 生成的 summary；DB `source_type == 'selectedTextSummary'`

2. **`branch_with_selected_text_summarize_falls_back_on_llm_failure`**
   - 准备：mock LLM 让其失败
   - 操作：选中文字 → branch → summarize
   - 断言：fallback 到 selectedText 原文（不是 parentTranscript），`source_type == 'selectedText'`

### 不补单测

本项目禁用单测（`flutter-add-widget-test` 已标红），全部靠集成测试 + 手工验证。

### 手工验证步骤

1. iOS sim：chat 中选几行 → branch → summarize → 等 LLM → 新 chat 首条是 summary
2. 同上但 LLM 失败 → 新 chat 首条是原文
3. 无选区 → branch → summarize → 行为不变（仍是 parentTranscript 总结）

## 待确认细节（用户决策）

- [ ] **C-1 prompt 策略**：采纳"新增 `summarizeSelection` 方法 + 新 prompt"（推荐）vs "复用 `summarizeContent` + 在 user prompt 前加前缀说明"
- [ ] **l10n key**：是否新增 `titleSourceSelectionSummary`（推荐）vs 复用 `titleSourceConversationSummary`（语义不准）
- [ ] **`_summarizeWithLifecycleAndRetry` 复用方式**：参数化 `summaryKind`（推荐）vs 新增 `_summarizeSelectionWithLifecycleAndRetry` 副本
- [ ] **nodeSourceType 新值**：是否新增 `'selectedTextSummary'`（推荐，保持语义清晰）vs 复用 `'summary'`
- [ ] **现有 "selectedText 短路" 行为影响范围**：检查 `_onCreateBranchFromMenu` 之外的入口（`theme_detail_screen.dart` 节点按钮、`note → chat` 流程）是否需要同步处理（**答：不需要**——这些入口本来就 `selectedText: null`，行为不变）

## 范围与限制

- **不在本次改动**：选区菜单项（contextMenu / AdaptiveTextSelectionToolbar）的"创建分支"项——目前 chat 屏幕没有这条菜单项，本 PR 不引入
- **不在本次改动**：`note → chat` 创建流程——`sourceLabelOverride: 'note'`，selectedText 始终 null
- **不在本次改动**：`sourceLabel` 文案风格——保持现有"选中文本 / 对话总结 / 对话 / 笔记"四类
