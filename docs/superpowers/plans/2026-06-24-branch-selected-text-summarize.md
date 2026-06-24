# 选中文本 + summarize 模式分支创建实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复"选中文本 + summarize"时 mode 被静默覆盖的 bug，让用户选择的 mode 真正生效 —— 选区在 summarize 模式下走 LLM 总结，在 raw 模式下走原文。

**架构：**
- `showBranchFlow` 重构判定顺序：先按 mode 分支，再按 selectedText 分支
- 新增 `TitleSuggestionService.summarizeSelection(text)` 静态方法，专门处理选区总结
- 复用 `_summarizeWithLifecycleAndRetry`，新增参数 `summaryKind` 决定调用哪个 service 方法
- `nodeSourceType` 增加 `'selectedTextSummary'` 新值，banner 复用 `titleSourceConversationSummary`（不新增 l10n key）

**技术栈：** Flutter 3.x / Riverpod / Cupertino UI / dart_define LLM 注入

**前置约束：**
- ThkTree 项目禁用单测（AGENTS.md + flutter-add-widget-test 规则），本计划的"测试"专指集成测试
- LLM 配置已通过 `build/dart_define.json` 注入（`dart run tools/gen_dart_define.dart` 产物）
- 已知现状：case 2 当前只验证"流程可达性"（line 236-237 注释），需升级为"行为正确性"验证

---

## 文件结构

| 状态 | 路径 | 职责 |
|---|---|---|
| 修改 | `lib/data/services/title_suggestion_service.dart` | 新增 `summarizeSelection` 静态方法 + `_selectionSystemPrompt` |
| 修改 | `lib/ui/core/shared/title_suggestion_screen.dart` | 重构 `showBranchFlow` 判定；参数化 `_summarizeWithLifecycleAndRetry`；扩展 `nodeSourceType` 决策表 |
| 修改 | `integration_test/branch_creation_test.dart` | case 2 末尾增加"新分支首条是 LLM 总结"断言 |
| 修改 | `docs/_tmp/branch-selected-text-summarize.md` | v1 → v2：把"l10n 新增 key"标记为废弃（改为复用） |

不修改 `lib/l10n/app_zh.arb` / `app_en.arb`（确认复用 `titleSourceConversationSummary`）。

---

## 任务 1：建立基线 + 锁定现有 case 2 行为

**文件：**
- 阅读：`integration_test/branch_creation_test.dart:178-340`（case 2 现状）
- 阅读：`lib/ui/core/shared/title_suggestion_screen.dart:854-1009`（showBranchFlow）

- [ ] **步骤 1：实跑 case 2，确认当前通过（流程可达性）**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter test integration_test/branch_creation_test.dart \
  --dart-define-from-file=build/dart_define.json \
  --name="选中文本 + summarize 模式创建分支"
```

预期：PASS（baseline 锁定）

- [ ] **步骤 2：在 case 2 末尾加 3 秒停留，便于观察新分支首条消息内容**

定位 `integration_test/branch_creation_test.dart:338`（`debugPrint('[Test] ✅ case 2 完成...')` 之前），改为：

```dart
      debugPrint('[Test] 新分支 LLM 回复完成，停留 5 秒查看新分支首条');
      await tester.pump(const Duration(seconds: 5));
      debugPrint('[Test] ✅ case 2 完成：选中文本 + summarize 模式创建分支成功');
```

- [ ] **步骤 3：手工观察打印输出，确认当前 case 2 新分支 ChatScreen 首条消息是"选区原文"（不是总结）**

预期：当前行为 = 用户选区原文直接当首条，**证明 bug 存在**

- [ ] **步骤 4：Commit（仅测试代码微调）**

```bash
git add integration_test/branch_creation_test.dart
git commit -m "test: 增加 case 2 观察停留时间"
```

---

## 任务 2：升级 case 2 为"行为正确性"验证

**文件：**
- 修改：`integration_test/branch_creation_test.dart:178-340`（case 2）

- [ ] **步骤 1：找到 case 2 末尾 line 326-328 的 expect 块**

现有代码：
```dart
      expect(
        find.byKey(const ValueKey('chat_input')),
        findsOneWidget,
        reason: '新分支 ChatScreen 应有输入框',
      );
```

- [ ] **步骤 2：先写验证"新分支首条是 LLM 总结"的断言（基于 chat input 上方的消息列表）**

在 line 328 之后增加：

```dart
      // 验证 case 2 修复后行为：summarize 必须真的对选区做 LLM 总结
      // 判定依据：选区原文 = "请用一句话介绍你自己"（用户原始消息）
      // 总结后的消息 ≠ 原文（包含总结性语言：例如"简介/介绍/助手/AI"等）
      // 如果首条 == 原文，说明 mode 仍被静默覆盖
      final rawSelectedText = '请用一句话介绍你自己';
      final summaryIndicators = ['介绍', '助手', 'AI', '你好', '总结'];
      
      // 等待 5s 让 LLM 回复渲染完成，再检查首条消息内容
      debugPrint('[Test] 等待 LLM 渲染完成，验证首条消息是 summary 不是 raw');
      await tester.pump(const Duration(seconds: 5));
      
      // 查找包含 rawSelectedText 的 widget（find 整个子树）
      final rawTextFinder = find.textContaining(rawSelectedText);
      final rawCount = rawTextFinder.evaluate().length;
      debugPrint('[Test] 包含选区原文 "$rawSelectedText" 的 widget 数: $rawCount');
      
      // 修复后：raw 原文不应出现在首条消息气泡中（只可能在 messageInput hint 或 system message）
      // 简化判定：原 case 1（raw）会有 rawCount >= 1；修复后 case 2 应该有 rawCount == 0
      // 但本断言容易脆，先记录为 warning，不 fail
      // 真实强断言：检查新分支 message list 第一个 bubble 的内容包含 summary 关键词
      if (rawCount > 0) {
        debugPrint('[Test] ⚠️ 警告：选区原文仍出现在新分支，可能是 mode 未生效');
      } else {
        debugPrint('[Test] ✅ 选区原文未出现，验证 mode 生效');
      }
```

> **注意**：上述为初始观察性断言。任务 4 实现完成后，需把 `if` 升级为 `expect(rawCount == 0, isTrue)`。任务 4 单独完成升级。

- [ ] **步骤 3：实跑 case 2，预期 rawCount > 0（baseline 仍 fail，证明 bug 存在）**

```bash
flutter test integration_test/branch_creation_test.dart \
  --dart-define-from-file=build/dart_define.json \
  --name="选中文本 + summarize 模式创建分支"
```

预期：测试通过，但 debugPrint 出现 "⚠️ 警告：选区原文仍出现在新分支"

- [ ] **步骤 4：Commit**

```bash
git add integration_test/branch_creation_test.dart
git commit -m "test: case 2 增加 mode 生效观察性断言（基线）"
```

---

## 任务 3：实现 TitleSuggestionService.summarizeSelection

**文件：**
- 修改：`lib/data/services/title_suggestion_service.dart`
- 位置：紧跟现有 `summarizeContent`（line 187-219）之后

- [ ] **步骤 1：定位现有 `_summarySystemPrompt`（line 28-34）和 `summarizeContent`（line 187-219）**

确认参数列表：`{transcript, provider, modelId, apiKey, contextWindow, cancelToken}`

- [ ] **步骤 2：新增选区专用 system prompt**

在 `_summarySystemPrompt` 之后（line 34 后）新增：

```dart
  static const _selectionSystemPrompt = '''
你是一个文本整理助手。给定用户从一段长内容中选中的一段文字，请生成一段简洁的总结或要点提炼，
作为新对话的上下文起点。要求：
1. 保留选区中讨论的关键事实、结论、术语、决定。
2. 控制在合理篇幅（一般 100~500 字），语言简洁清晰，不要冗长。
3. 不要添加选区中没有的信息，不要替用户做判断。
4. 使用与选区相同的语言输出。
5. 如果选区本身已经是短句或无明显语义结构，可以原样返回或做轻微润色。''';
```

- [ ] **步骤 3：新增 `summarizeSelection` 静态方法**

在 `summarizeContent` 之后新增：

```dart
  /// 总结用户从聊天消息中选中的文本。
  ///
  /// 与 [summarizeContent] 的区别：
  /// - 使用 [selectionSystemPrompt]（短文本整理场景，对话总结场景用 summarizeContent）
  /// - 输入通常是几十到几百字的选区，不需要按消息边界截断
  /// - token 上限按 [contextWindow] 的 25% 控制（而非 summarizeContent 的 50%）
  static Future<String> summarizeSelection({
    required String selectedText,
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    required int contextWindow,
    CancelToken? cancelToken,
  }) async {
    // 选区场景下做轻量 sanitization，不按 ## user/assistant 切分
    final cleaned = selectedText.trim();
    if (cleaned.isEmpty) {
      throw const FormatException('选区为空');
    }

    // 选区一般较短，直接使用，不做 _truncateByMessages
    final estimatedTokens = _estimateTokens(cleaned);
    final maxTokens = (contextWindow * 0.25).floor();
    final truncated = estimatedTokens > maxTokens
        ? _truncateByChars(cleaned, maxTokens)
        : cleaned;

    final userPrompt = '请整理以下选区内容：\n\n---\n$truncated';

    final request = LlmRequest(
      provider: provider,
      modelId: modelId,
      apiKey: apiKey,
      systemPrompt: _selectionSystemPrompt,
      userPrompt: userPrompt,
      temperature: 0.3,
      maxOutputTokens: 512,
      cancelToken: cancelToken,
    );
    return LlmClient.sendOnce(request);
  }

  /// 选区场景下用，按字符数粗略截断（无消息边界可参考）。
  static String _truncateByChars(String text, int maxTokens) {
    // 粗略估算：英文 4 char/token，中文 1~2 char/token
    final maxChars = maxTokens * 2;
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}\n\n[已截断]';
  }
```

> 校验：`_estimateTokens`（line 42-75）、`LlmRequest` / `LlmClient.sendOnce`、`_truncateByMessages`（line 87-140）都是已存在方法，可直接复用。如 `LlmRequest` 字段名不一致，按实际类型调整。

- [ ] **步骤 4：实跑 dart analyze，确认无新编译错误**

```bash
flutter analyze lib/data/services/title_suggestion_service.dart
```

预期：无 error，可能有 info（不影响）

- [ ] **步骤 5：Commit**

```bash
git add lib/data/services/title_suggestion_service.dart
git commit -m "feat(service): 新增 summarizeSelection 选区总结方法"
```

---

## 任务 4：实现 showBranchFlow 的 mode 优先重构

**文件：**
- 修改：`lib/ui/core/shared/title_suggestion_screen.dart:854-924`（showBranchFlow 主逻辑）
- 修改：`lib/ui/core/shared/title_suggestion_screen.dart:1067-1140`（_summarizeWithLifecycleAndRetry）
- 修改：`lib/ui/core/shared/title_suggestion_screen.dart:959-965`（nodeSourceType 决策表）

- [ ] **步骤 1：阅读 showBranchFlow 完整签名（line 854）**

```dart
Future<String?> showBranchFlow({
  required BuildContext context,
  required String parentTranscript,
  required BranchMode mode,
  String? selectedText,
  String? sourceLabelOverride,
})
```

确认参数列表与默认值。

- [ ] **步骤 2：把 line 871-924 的 selectedText 短路逻辑改为 mode 优先**

**当前（buggy）**：

```dart
if (selectedText != null && selectedText.isNotEmpty) {
  sourceContent = selectedText;
  sourceLabel = sourceLabelOverride ?? l10n.titleSourceSelection;
} else if (mode == BranchMode.raw) {
  sourceContent = parentTranscript;
  sourceLabel = sourceLabelOverride ?? l10n.titleSourceConversation;
} else {
  // summarize
  ...
}
```

**改为（mode 优先）**：

```dart
if (mode == BranchMode.raw) {
  // raw 模式：选区优先；无选区才用对话
  if (selectedText != null && selectedText.isNotEmpty) {
    sourceContent = selectedText;
    sourceLabel = sourceLabelOverride ?? l10n.titleSourceSelection;
  } else {
    sourceContent = parentTranscript;
    sourceLabel = sourceLabelOverride ?? l10n.titleSourceConversation;
  }
} else {
  // summarize 模式：选区 + summarize → LLM 总结选区；无选区 + summarize → LLM 总结对话
  final hasSelection = selectedText != null && selectedText.isNotEmpty;
  final summaryKind = hasSelection ? SummaryKind.selection : SummaryKind.conversation;
  final resolved = await _resolveModelForSummary(
    context: context,
    summaryKind: summaryKind,
  );
  if (resolved == null) {
    // 模型解析失败 → fallback
    sourceContent = hasSelection ? selectedText! : parentTranscript;
    sourceLabel = sourceLabelOverride ??
        (hasSelection ? l10n.titleSourceSelection : l10n.titleSourceConversation);
  } else {
    final summary = await _summarizeWithLifecycleAndRetry(
      context: context,
      text: hasSelection ? selectedText! : parentTranscript,
      resolvedModel: resolved,
      summaryKind: summaryKind,
    );
    if (summary != null && summary.isNotEmpty) {
      sourceContent = summary;
      sourceLabel = sourceLabelOverride ?? l10n.titleSourceConversationSummary;
    } else {
      // LLM 总结失败 → fallback（注意：选区 summarize 失败 → 选区原文；不是对话原文）
      sourceContent = hasSelection ? selectedText! : parentTranscript;
      sourceLabel = sourceLabelOverride ??
          (hasSelection ? l10n.titleSourceSelection : l10n.titleSourceConversation);
    }
  }
}
```

- [ ] **步骤 3：参数化 `_summarizeWithLifecycleAndRetry`（line 1067 附近）**

定位函数签名，新增 `summaryKind` 参数：

**当前签名**（参考 line 1067 实际内容，可能略有差异）：

```dart
Future<String?> _summarizeWithLifecycleAndRetry({
  required BuildContext context,
  required String transcript,
  required ResolvedSummaryModel resolvedModel,
  ...
})
```

**改为**：

```dart
/// 选区/对话来源枚举（驱动 service 方法和 prompt 选择）
enum SummaryKind {
  /// 整个对话
  conversation,

  /// 用户选中的文本
  selection,
}

Future<String?> _summarizeWithLifecycleAndRetry({
  required BuildContext context,
  required String text,
  required ResolvedSummaryModel resolvedModel,
  required SummaryKind summaryKind,
  ...
}) async {
  // ... 内部根据 summaryKind 决定调哪个 service 方法
  final summary = summaryKind == SummaryKind.selection
      ? await TitleSuggestionService.summarizeSelection(
          selectedText: text,
          provider: resolvedModel.provider,
          modelId: resolvedModel.modelId,
          apiKey: resolvedModel.apiKey,
          contextWindow: resolvedModel.contextWindow,
          cancelToken: cancelToken,
        )
      : await TitleSuggestionService.summarizeContent(
          transcript: text,
          provider: resolvedModel.provider,
          modelId: resolvedModel.modelId,
          apiKey: resolvedModel.apiKey,
          contextWindow: resolvedModel.contextWindow,
          cancelToken: cancelToken,
        );
  ...
}
```

> 注：函数签名具体参数（cancelToken / lifecycleListener 等）按 line 1067 实际内容调整；本计划给出主结构。

- [ ] **步骤 4：参数化 `_resolveModelForSummary` 接受 summaryKind（line 1207 附近）**

如果 `_resolveModelForSummary` 内部根据 summaryKind 选择不同模型（v1 不做差异化，summaryKind 仅做透传），保持现状即可。任务 3 完成时核对实现，决定是否需要修改。

- [ ] **步骤 5：更新 `nodeSourceType` 决策表（line 959-965）**

**当前**：

```dart
final nodeSourceType = sourceLabelOverride != null
    ? 'note'
    : (selectedText != null && selectedText.isNotEmpty)
        ? 'selectedText'
        : (mode == BranchMode.summarize)
            ? 'summary'
            : 'conversation';
```

**改为**：

```dart
final hasSelection = selectedText != null && selectedText.isNotEmpty;
final nodeSourceType = sourceLabelOverride != null
    ? 'note'
    : (mode == BranchMode.raw)
        ? (hasSelection ? 'selectedText' : 'conversation')
        // summarize
        : (hasSelection ? 'selectedTextSummary' : 'summary');
```

- [ ] **步骤 6：实跑 dart analyze**

```bash
flutter analyze lib/ui/core/shared/title_suggestion_screen.dart
```

预期：无 error。如有 `_resolveModelForSummary` 调用点不匹配，按错误信息调整。

- [ ] **步骤 7：实跑 case 1（选区+raw），确认不回归**

```bash
flutter test integration_test/branch_creation_test.dart \
  --dart-define-from-file=build/dart_define.json \
  --name="选中文本 + raw 模式创建分支"
```

预期：PASS

- [ ] **步骤 8：实跑 case 4（无选+summarize），确认不回归**

```bash
flutter test integration_test/branch_creation_test.dart \
  --dart-define-from-file=build/dart_define.json \
  --name="无选中文本 + summarize 模式创建分支"
```

预期：PASS

- [ ] **步骤 9：实跑 case 2（选区+summarize），观察新行为**

```bash
flutter test integration_test/branch_creation_test.dart \
  --dart-define-from-file=build/dart_define.json \
  --name="选中文本 + summarize 模式创建分支"
```

预期：测试通过，debugPrint 输出 "✅ 选区原文未出现，验证 mode 生效"（即任务 2 步骤 2 的 if 分支走 else）

- [ ] **步骤 10：Commit**

```bash
git add lib/ui/core/shared/title_suggestion_screen.dart
git commit -m "feat(branch): 修复选区+summarize 时 mode 静默覆盖问题"
```

---

## 任务 5：升级 case 2 断言为强断言

**文件：**
- 修改：`integration_test/branch_creation_test.dart`（任务 2 步骤 2 位置）

- [ ] **步骤 1：把任务 2 步骤 2 的观察性 if 改为 expect 强断言**

```dart
      // 强断言：选区原文不应出现在新分支首条消息气泡中
      expect(
        rawCount,
        equals(0),
        reason: 'summarize 模式下应使用 LLM 总结，不应把选区原文当首条',
      );
```

- [ ] **步骤 2：实跑 case 2，预期强断言通过**

```bash
flutter test integration_test/branch_creation_test.dart \
  --dart-define-from-file=build/dart_define.json \
  --name="选中文本 + summarize 模式创建分支"
```

预期：PASS

- [ ] **步骤 3：Commit**

```bash
git add integration_test/branch_creation_test.dart
git commit -m "test: case 2 升级为强断言（验证 mode 真的生效）"
```

---

## 任务 6：实跑 case 1/2/4 全量回归

**文件：** 无（仅验证）

- [ ] **步骤 1：实跑 branch_creation_test.dart 全部 case**

```bash
flutter test integration_test/branch_creation_test.dart \
  --dart-define-from-file=build/dart_define.json
```

预期：case 1、2、3、4 全部 PASS（case 5/6/7 是 TODO 状态，本来就 skip）

- [ ] **步骤 2：手工回归（可选）**

启动 app，走一次"选文字 → summarize → 创建分支"，确认 banner 显示"对话总结"+首条消息是 LLM 总结（不是选区原文）。

---

## 任务 7：更新 docs/_tmp/ 草稿 v2 + 清理

**文件：**
- 修改：`docs/_tmp/branch-selected-text-summarize.md`

- [ ] **步骤 1：在草稿头部加 v2 标记**

文件第一行加：

```markdown
# 选中文本 + summarize 模式分支创建（v2，已实施）

> v1 草稿归档在下方 § 变更历史。v2 关键变更：l10n 改为复用 `titleSourceConversationSummary`，不再新增 key；新增 `summaryKind` 枚举驱动 service 方法选择。
```

- [ ] **步骤 2：在草稿末尾追加 § 变更历史**

```markdown
## § 变更历史

### v2（实施版）
- l10n：复用 `titleSourceConversationSummary`，**不新增** `titleSourceSelectionSummary`
- prompt：新增 `_selectionSystemPrompt`（专门处理短文本/选区场景）
- service：新增 `summarizeSelection` 静态方法，token 上限 25%（vs conversation 50%）
- showBranchFlow：判定顺序改为 mode 优先；选区 summarize 失败 → fallback 到选区原文
- nodeSourceType：新增 `'selectedTextSummary'` 值

### v1（讨论版，已废弃）
- 提议新增 `titleSourceSelectionSummary`（过度设计）
- 提议所有场景复用 `summarizeContent` + 对话 prompt（语义不准）
```

- [ ] **步骤 3：Commit 草稿**

按 AGENTS.md"代码 commit 和文档 commit 必须分开"原则，单独 commit：

```bash
git add docs/_tmp/branch-selected-text-summarize.md
git commit -m "docs: branch-selected-text-summarize v2 实施记录"
```

---

## 自检

- [x] **规格覆盖度**：
  - mode 必须生效 ✅ 任务 4 步骤 2
  - summarize 失败 fallback 到选区原文 ✅ 任务 4 步骤 2 else 分支
  - prompt 适配选区场景 ✅ 任务 3 步骤 2
  - l10n 复用现有 key ✅ 任务 4 步骤 2（不新增）
  - nodeSourceType 新值 ✅ 任务 4 步骤 5

- [x] **占位符扫描**：无"TODO"/"待定"等占位符（除 case 5/6/7 已有 TODO，与本计划无关）

- [x] **类型一致性**：
  - `SummaryKind` 枚举 → `_summarizeWithLifecycleAndRetry` 参数 → `showBranchFlow` 调用 ✅
  - `TitleSuggestionService.summarizeSelection` 签名 → 调用点参数 ✅
  - `nodeSourceType` 4 个值（note/selectedText/conversation/summary/selectedTextSummary）→ 决策表 ✅

---

## 执行交接

**计划已完成并保存到 `docs/superpowers/plans/2026-06-24-branch-selected-text-summarize.md`。两种执行方式：**

**1. 子代理驱动（推荐）** - 每个任务调度一个新的子代理，任务间进行审查，快速迭代

**2. 内联执行** - 在当前会话中使用 executing-plans 执行任务，批量执行并设有检查点

**选哪种方式？**

**注**：按 AGENTS.md "强制 worktree 开发流程"，本计划所有 commit 应在 worktree 中执行（不在主仓库 dev 分支直接改）。worktree 创建命令：

```bash
git worktree add ../ThkTree-worktrees/branch-selected-text-summarize -b codex/branch-selected-text-summarize
```
