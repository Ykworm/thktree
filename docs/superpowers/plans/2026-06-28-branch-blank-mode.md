# 分支创建：新增"空白分支"模式实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。
>
> **上游文档：** `docs/_tmp/2026-06-28-branch-blank-mode.md`（v1 brainstorming，12 个决策已用户确认）
> **关联 issue：** P.9（仅 A 部分；B 部分 sheet 间距优化单独处理）
> **任务类型：** 普通功能（+ 集成测试新增）

---

## 🎯 目标

在分支创建入口（`chat_screen` 右上 branch 按钮 + `theme_detail_screen` 节点按钮）新增"空白分支"选项。创建时：

- **不**调 LLM summary
- **不**显示 title suggestion sheet
- 直接创建 child node（title="临时会话"，sourceType='userIdea'，sourceExcerpt=null）
- 进入 chat 后，**流式回复结束后**后置自动生成 title（限一次 + 重试 3 次指数退避 + 模型缺失弹 `showLlmSetupAlert`）

---

## 🧱 技术栈与硬约束

- Flutter 3.x + Cupertino UI
- Riverpod（`ConsumerStatefulWidget` + `ref.read` / `ref.watch`）
- 集成测试驱动（项目禁用单测）
- **A 模式独立原则**：不修改 raw/summarize 现有代码路径；`showBranchFlow` 内独立分支
- **防御式编程**：不修改 `chatTaskStateProvider`、不破坏现有 chat 流程

---

## 📊 任务总表

| # | 任务 | 文件 | 类型 | 依赖 |
|---|------|------|------|------|
| 1 | `BranchMode` 加 `blank` 值 | `title_suggestion_screen.dart` | 修改 | — |
| 2 | sheet UI 加 blank 选项 + ValueKey | `title_suggestion_screen.dart` | 修改 | 1 |
| 3 | `showBranchFlow` 加 blank 早期返回 + `_createBlankBranch` | `title_suggestion_screen.dart` | 修改 | 1 |
| 4 | `updateNodeSourceInfo` 支持 `sourceExcerpt=null` | `node_store.dart` | 修改 | — |
| 5 | 新增 3 个 l10n 键 | `app_zh.arb` + `app_en.arb` | 修改 | — |
| 6 | 跑 `flutter gen-l10n` 重新生成本地化 | 自动 | 触发 | 5 |
| 7 | `_sourceTypeLabel` switch 加 `userIdea` case | `theme_detail_screen.dart` | 修改 | 5 |
| 8 | chat_screen 后置自动 title 生成 + 重试 + 防抖 | `chat_screen.dart` | 修改 | 3, 4 |
| 9 | 集成测试新增 4 用例 | `integration_test/branch_creation_test.dart` | 修改 | 1-8 |
| 10 | 跑测试 + 自检 | 全部 | 验证 | 1-9 |

---

## 📁 文件结构

| 状态 | 路径 | 职责 |
|------|------|------|
| 修改 | `lib/ui/core/shared/title_suggestion_screen.dart` | 加 BranchMode.blank + sheet 选项 + showBranchFlow 早期返回 |
| 修改 | `lib/data/stores/node_store.dart` | `updateNodeSourceInfo` 签名允许 sourceExcerpt=null |
| 修改 | `lib/ui/features/themes/theme_detail_screen.dart` | `_sourceTypeLabel` switch 加 `userIdea` |
| 修改 | `lib/ui/features/chat/chat_screen.dart` | 后置自动 title 生成 hook |
| 修改 | `lib/l10n/app_zh.arb` + `lib/l10n/app_en.arb` | 新增 3 个 l10n 键 |
| 自动 | `lib/l10n/generated/*.dart` | 由 `flutter gen-l10n` 重新生成 |
| 修改 | `integration_test/branch_creation_test.dart` | 新增 4 个 A 模式用例 |

---

## 📋 任务详细说明

---

### 任务 1：BranchMode enum 加 `blank` 值

**文件：** `lib/ui/core/shared/title_suggestion_screen.dart`

**改动点：** 行 51-54

```dart
enum BranchMode {
  summarize,
  raw,
  blank,  // 用户自发创建，空白起点（不调 LLM summary / 不显示 title sheet）
}
```

**验收：**
- [ ] enum 加 `blank` 值
- [ ] 现有 `summarize` / `raw` 值不变（保证 BranchMode.blank 不会破坏 switch 穷尽性检查）
- [ ] `flutter analyze` 无新增 error

**`note → chat` 入口审计：**

通过 `rg "showBranchModeSheet\(" lib/` 验证：`showBranchModeSheet` 仅被 **chat_screen（行 358）** + **theme_detail_screen（行 658）** 调用，`note_detail_screen` **不**走此 sheet。note → chat 路径完全不显示 BranchMode 选项 → 不可能选择 `blank` → 回归保护天然成立，不需额外代码。

---

### 任务 2：showBranchModeSheet UI 加 blank 选项

**文件：** `lib/ui/core/shared/title_suggestion_screen.dart`

**改动点：** 行 666-681 区域（`showBranchModeSheet` 内 `_BranchModeOption` 列表）

精确插入位置：**在 `raw` 选项（行 674-681）之后、`Padding` 按钮区（行 682-713）之前**，作为第三个 `_BranchModeOption`：

```dart
_BranchModeOption(
  key: const ValueKey('branch_mode_blank_option'),
  label: l10n.branchModeBlank,  // "空白分支"
  selected: selected == BranchMode.blank,
  onTap: () => setState(
    () => selected = BranchMode.blank,
  ),
),
```

**验收：**
- [ ] sheet 中显示三个选项：总结后创建 / 使用原始上下文创建 / **空白分支**
- [ ] 每个选项可选 + 单选样式（沿用 `_BranchModeOption`）
- [ ] "继续"按钮在 selected != null 时可点（已具备）

---

### 任务 3：showBranchFlow 加 blank 早期返回 + _createBlankBranch

**文件：** `lib/ui/core/shared/title_suggestion_screen.dart`

**改动点 3.1：** `showBranchFlow` 函数顶部（行 802 之前）加早期返回

```dart
Future<String?> showBranchFlow({...}) async {
  // ★ 新增：A 模式走独立路径
  if (mode == BranchMode.blank) {
    return _createBlankBranch(
      context: context,
      themeId: themeId,
      parentNodeId: parentNodeId,
    );
  }

  // ↓ 原有逻辑保持不动（L1-A 拦截 / source content 决策 / title sheet / 创建 / push）
  // ... (line 803-973 不变)
}
```

**改动点 3.2：** 新增私有方法 `_createBlankBranch`（建议放在 `_summarizeWithLifecycleAndRetry` 之前，行 975 附近）

```dart
/// 空白分支创建（不走 LLM summary / 不显示 title sheet）。
///
/// 行为：
/// - 创建 child node（title=占位 "临时会话"）
/// - 写 sourceExcerpt=null, sourceType='userIdea'
/// - 刷新 theme controller（与现有 showBranchFlow 末尾一致）
/// - push chat_screen（autoTriggerReply=true）
///
/// 返回 childNode.nodeId；任意步骤异常 → null。
Future<String?> _createBlankBranch({
  required BuildContext context,
  required String themeId,
  required String? parentNodeId,
}) async {
  final l10n = AppLocalizations.of(context)!;

  try {
    if (!context.mounted) return null;
    final container = ProviderScope.containerOf(context, listen: false);
    final nodeStore = await container.read(nodeStoreProvider.future);
    final sessionStore = await container.read(sessionStoreProvider.future);

    final themeRow = await nodeStore.getThemeRow(themeId: themeId);
    final themePath = themeRow['themePath']! as String;

    // 1. 创建空分支（占位 title = "临时会话"）
    final childNode = await nodeStore.createChatNode(
      themeId: themeId,
      themePath: themePath,
      parentId: parentNodeId,
      title: l10n.branchBlankInitialTitle,
    );

    // 2. 写 source info：sourceExcerpt=null, sourceType='userIdea'
    await nodeStore.updateNodeSourceInfo(
      nodeId: childNode.nodeId,
      sourceExcerpt: null,
      sourceType: 'userIdea',
    );

    // 3. 刷新 theme controller（与现有 showBranchFlow 一致）
    if (!context.mounted) return null;
    unawaited(
      container
          .read(themeDetailControllerProvider(themeId).notifier)
          .refresh()
          .catchError((_) {}),
    );

    // 4. push chat_screen（autoTriggerReply=false — A 模式不自动回复）
    if (!context.mounted) return null;
    context.push(
      '/themes/$themeId/nodes/${childNode.nodeId}',
      extra: ChatScreenLaunchParams(
        title: l10n.branchBlankInitialTitle,
        autoTriggerReply: false,
      ),
    );

    return childNode.nodeId;
  } catch (e) {
    if (!context.mounted) return null;
    ThkAlert.show(
      context: context,
      message: l10n.branchFailed(e.toString()),
    );
    return null;
  }
}
```

**验收：**
- [ ] `BranchMode.blank` 走 `_createBlankBranch` 路径（不调 LLM / 不弹 title sheet）
- [ ] DB 中新 node：`title='临时会话'`、`sourceType='userIdea'`、`sourceExcerpt=NULL`
- [ ] 创建后 push 到 chat_screen，title 显示 "临时会话"
- [ ] 任何步骤异常 → 走 `branchFailed` alert，返回 null

**注意：** 现有 `showBranchFlow` 行 957-963 的 `context.push` `extra: ChatScreenLaunchParams(title: title, autoTriggerReply: true)`。A 模式 `autoTriggerReply=false`（用户不自动发起对话，自己输入首条）。

---

### 任务 4：updateNodeSourceInfo 允许 sourceExcerpt=null

**文件：** `lib/data/stores/node_store.dart`

**改动点：** 行 367-381

```dart
/// Update sourceExcerpt and sourceType for a node (called after branch creation).
///
/// [sourceExcerpt] 可空：A 模式（userIdea）不预填，存 NULL；
/// 其他模式（summarize / raw / selectedText / note）传截断后的 excerpt。
Future<void> updateNodeSourceInfo({
  required String nodeId,
  required String? sourceExcerpt,  // ★ 从 required String 改为 required String?
  required String sourceType,
}) async {
  await db.update(
    'nodes',
    {
      'sourceExcerpt': sourceExcerpt,  // SQLite 字段允许 null
      'sourceType': sourceType,
    },
    where: 'nodeId = ?',
    whereArgs: [nodeId],
  );
}
```

**调用方审计（迁移安全）：**

| 调用方 | 当前 sourceExcerpt 值 | 兼容情况 |
|--------|----------------------|----------|
| `lib/ui/core/shared/title_suggestion_screen.dart:930` | `nodeSourceExcerpt`（80 char 截断 String） | ✅ 兼容（String 是 String? 子类型） |
| `lib/ui/features/notes/note_detail_screen.dart:345` | `nodeSourceExcerpt`（80 char 截断 String） | ✅ 兼容 |

**验收：**
- [ ] 签名改为 `required String? sourceExcerpt`
- [ ] 2 个调用方无需修改
- [ ] `flutter analyze` 无新增 error（确认无其他调用方）

---

### 任务 5：新增 3 个 l10n 键

**文件：** `lib/l10n/app_zh.arb` + `lib/l10n/app_en.arb`

**zh 新增（建议插入到 `branchModeContinue` 行 195 之后，与 `branchModeSummarize`/`branchModeRaw` 同区）：**

```json
"branchModeBlank": "空白分支",
"branchBlankInitialTitle": "临时会话",
```

**zh 新增（建议插入到 `sourceTypeNote` 行 229 之后）：**

```json
"sourceTypeUserIdea": "用户补充",
```

**en 新增（同样位置）：**

```json
"branchModeBlank": "Blank Branch",
"branchBlankInitialTitle": "Temporary Chat",
"sourceTypeUserIdea": "User Idea",
```

**验收：**
- [ ] zh 与 en 各新增 3 个键
- [ ] 命名风格与现有 `branchMode*` / `sourceType*` 一致
- [ ] 用户确认：zh "用户补充"（确认）、en "User Idea"（Title Case）

---

### 任务 6：跑 `flutter gen-l10n` 重新生成本地化

**命令：**

```bash
flutter gen-l10n
```

**验收：**
- [ ] `lib/l10n/generated/app_localizations.dart` 包含新键（`branchModeBlank`, `branchBlankInitialTitle`, `sourceTypeUserIdea`）
- [ ] zh / en 两个 locale 都生成

---

### 任务 7：_sourceTypeLabel switch 加 `userIdea` case

**文件：** `lib/ui/features/themes/theme_detail_screen.dart`

**改动点：** 行 606-614

```dart
String? _sourceTypeLabel(AppLocalizations l10n, String? sourceType) {
  return switch (sourceType) {
    'selectedText' => l10n.sourceTypeSelectedText,
    'conversation' => l10n.sourceTypeConversation,
    'summary' => l10n.sourceTypeSummary,
    'note' => l10n.sourceTypeNote,
    'userIdea' => l10n.sourceTypeUserIdea,  // ★ 新增
    _ => null,
  };
}
```

**验收：**
- [ ] tree view 显示空白分支节点 sourceType 标签为 "用户补充" / "User Idea"
- [ ] 其他 4 case 行为不变

---

### 任务 8：chat_screen 后置自动 title 生成

**文件：** `lib/ui/features/chat/chat_screen.dart`

**核心原则：** **防御式编程** — 不修改 `chatTaskStateProvider`、不侵入顶层 `ref.listen`，而是监听 `chatControllerProvider(_args)` 的 `isStreaming` 状态从 `true` 变 `false` 的"刚刚结束"事件。

**实现策略（推荐方案 α-β 混合）：**

在 `_ChatScreenState` 添加 3 个字段：

```dart
String? _pendingAutoTitleNodeId;  // null=未触发；nodeId=已注册但未触发
bool _wasStreaming = false;        // 上次 isStreaming 状态（用于检测 true → false 边沿）
bool _autoTitleTriggered = false;  // 防抖：触发过一次就永远 false
String? _autoTitlePlaceholder;     // 当前 title 是否还是占位 "临时会话"（截屏用）
```

`initState` 中：

```dart
@override
void initState() {
  super.initState();
  _args = ChatControllerParams(
    nodeId: widget.nodeId,
    title: widget.title,
    autoTriggerReply: widget.autoTriggerReply,
  );
  // ★ 新增：A 模式占位 title → 注册后置自动 title 监听
  // 占位 title 判断在 build 里（需要 l10n），不能放在 initState
}
```

**`build` 方法中（行 107 附近，messagesAsync.watch 之后）加边沿检测：**

```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final messagesAsync = ref.watch(chatControllerProvider(_args));
  final isStreaming = messagesAsync.maybeWhen(
    data: (messages) => messages.any((m) => m.status == SessionMessageStatus.streaming),
    orElse: () => false,
  );

  // ★ 新增：A 模式后置自动 title 生成（边沿检测：true → false）
  if (_wasStreaming && !isStreaming && !_autoTitleTriggered) {
    final placeholder = l10n.branchBlankInitialTitle;
    final isBlankNode = widget.title == placeholder;
    if (isBlankNode) {
      _autoTitleTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerBlankAutoTitle();
      });
    }
  }
  _wasStreaming = isStreaming;

  // ↓ 原有 build 逻辑不变
  // ...
}
```

**新增方法 `_triggerBlankAutoTitle`：**

```dart
/// A 模式后置自动 title 生成（流式回复结束后调用一次）。
///
/// 流程：
/// 1. 守卫：title 已被用户改过（不是占位） → 跳过
/// 2. 解析 chatDefaultModel（沿用 settings.chatDefaultProviderId/chatDefaultModelId）
/// 3. 未配置 → 弹 showLlmSetupAlert → 静默保持占位
/// 4. 已配置 → 调 LLM 生成 title（重试 3 次，指数退避 1s/2s/4s）
/// 5. 成功 → nodeStore.updateNodeTitle → 刷新 UI
/// 6. 失败 / 空 → 静默保持占位
Future<void> _triggerBlankAutoTitle() async {
  if (!mounted) return;
  final l10n = AppLocalizations.of(context)!;
  final placeholder = l10n.branchBlankInitialTitle;

  // 1. 守卫：title 已被改过
  if (widget.title != placeholder) return;

  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final settings = container.read(settingsControllerProvider).value;
    if (settings == null) return;

    // 2. 解析 model：优先复用 resolveModelForTitle（已有 fallback chain：
    //    titleModelProviderId → currentProviderId → legacy → 第一个有 apiKey 的 provider）
    //    这里用 settings.chatDefaultProviderId/chatDefaultModelId 作为 current 偏好
    final settings2 = container.read(settingsControllerProvider).value;
    final providers = container.read(llmProvidersProvider).value ?? [];
    final resolved = await resolveModelForTitle(
      container,
      providers,
      currentProviderId: settings2?.chatDefaultProviderId,
      currentModelId: settings2?.chatDefaultModelId,
    );
    if (resolved == null) {
      if (!mounted) return;
      await showLlmSetupAlert(
        context: context,
        status: LlmSetupStatus.noTitleModelConfigured,  // 复用：未配置 title 模型
        container: ProviderScope.containerOf(context, listen: false),
      );
      return;
    }
    final (provider, modelId, apiKey) = resolved;

    // 3. 调 LLM 生成 title（重试 3 次 + 指数退避）
    final newTitle = await _generateTitleWithRetry(
      provider: provider,
      modelId: modelId,
      apiKey: apiKey,
      transcriptContext: _collectTranscriptForTitle(),
    );

    // 4. 成功 → 写 DB + 刷新 UI
    if (!mounted) return;
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      final nodeStore = await container.read(nodeStoreProvider.future);
      await nodeStore.updateNodeTitle(
        nodeId: widget.nodeId,
        newTitle: newTitle.trim(),
      );
      // 注：widget.title 是构造时传入的，要让 nav bar 实时显示新 title，
      // 需要把 title 从 controller 读而非 widget.title。本任务范围内先接受一次刷新。
      if (mounted) setState(() {});
    }
    // 5. 失败 / 空 → 静默
  } catch (e, st) {
    debugPrint('[AutoTitle] FAILED nodeId=${widget.nodeId}: $e\n$st');
  }
}

/// 收集 chat transcript 用于生成 title（取最后一对 user + assistant message）。
String _collectTranscriptForTitle() {
  final messagesAsync = ref.read(chatControllerProvider(_args));
  return messagesAsync.maybeWhen(
    data: (messages) {
      final lastUser = messages.lastWhere(
        (m) => m.role == SessionRole.user,
        orElse: () => SessionMessage(role: SessionRole.user, body: '', status: SessionMessageStatus.done),
      );
      final lastAssistant = messages.lastWhere(
        (m) => m.role == SessionRole.assistant,
        orElse: () => SessionMessage(role: SessionRole.assistant, body: '', status: SessionMessageStatus.done),
      );
      return 'User: ${lastUser.body}\nAssistant: ${lastAssistant.body}';
    },
    orElse: () => '',
  );
}

/// 调 LLM 生成 title，带 3 次重试 + 指数退避 1s/2s/4s。
Future<String?> _generateTitleWithRetry({
  required LlmProviderConfig provider,
  required String modelId,
  required String apiKey,
  required String transcriptContext,
}) async {
  const maxAttempts = 3;
  String? lastError;

  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      final title = await _callTitleLlm(
        provider: provider,
        modelId: modelId,
        apiKey: apiKey,
        transcriptContext: transcriptContext,
      );
      if (title != null && title.trim().isNotEmpty) return title;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[AutoTitle] attempt ${attempt + 1} failed: $e');
    }
    // 指数退避（最后一次不 sleep）
    if (attempt < maxAttempts - 1) {
      await Future.delayed(Duration(seconds: 1 << attempt));  // 1s / 2s / 4s
    }
  }

  if (lastError != null) {
    debugPrint('[AutoTitle] all $maxAttempts attempts failed, last error: $lastError');
  }
  return null;
}

/// 调一次 LLM 生成 title（不带重试）。
///
/// 复用 TitleSuggestionService.generateTitles 的调用模式（参考 title_suggestion_screen.dart 行 286-294）
/// 或直接调 LlmClient.streamChatCompletion + 简化 system prompt（"基于以下对话生成 5-10 字标题"）。
Future<String?> _callTitleLlm({
  required LlmProviderConfig provider,
  required String modelId,
  required String apiKey,
  required String transcriptContext,
}) async {
  // 具体实现：复用 TitleSuggestionService.generateTitles(content: transcriptContext, direction: null, ...)
  // 或直接 new LlmClient(provider, apiKey).streamChatCompletion(...) + 解析第一个 chunk
  // 本任务范围限定接口，调用细节实施时定（与 title_suggestion_screen.dart:286-294 对齐）
  throw UnimplementedError('TODO: implement using TitleSuggestionService or LlmClient');
}
```

**注意事项：**

1. **`_collectTranscriptForTitle` 简化**：本任务先用最简单的"最后一对 user/assistant"实现，后续可扩展为"整段对话"
2. **`_callTitleLlm` 调用方式**：复用 `TitleSuggestionService` 已有逻辑或直接调 `LlmClient.streamChatCompletion` + 简化 system prompt（"基于以下对话生成 5-10 字标题"）
3. **widget.title 刷新问题**：`_ChatScreenState` 当前用 `widget.title` 显示，nav bar 不会自动同步。可在 `setState` 时把 title 缓存到 `_displayedTitle` 字段，让 build 用 `_displayedTitle ?? widget.title` 显示
4. **isStreaming 边沿检测**：避免 LLM 切回重试时重复触发（A.3 防抖用 `_autoTitleTriggered` flag，二次保护）

**验收：**
- [ ] A 模式创建空分支 → 发首条消息 → LLM 回复结束 → title 自动变化
- [ ] 用户手动改过 title 后不再触发
- [ ] 重试 3 次失败后静默保持 "临时会话"
- [ ] 模型未配置弹 `showLlmSetupAlert`，不阻止创建空分支

---

### 任务 9：集成测试新增 4 个 A 模式用例

**文件：** `integration_test/branch_creation_test.dart`（修改）

参考现有 `branch_creation_test.dart` 的 4 个已实现用例（选中文本 + raw/summarize，无选中文本 + raw/summarize），新增：

#### Test 9.1：`branch_blank_creates_empty_node`

```dart
testWidgets('A 模式创建空 node：title=临时会话，sourceType=userIdea，sourceExcerpt=null', (tester) async {
  // 1. 父 chat 有 N 条消息
  // 2. 点 branch → 选"空白分支"
  // 3. 断言：
  //    - 跳转 chat_screen
  //    - DB：source_type='userIdea', source_excerpt=NULL
  //    - title 显示 "临时会话"
  //    - 首条 user message 不存在（session.md 空）
});
```

#### Test 9.2：`branch_blank_triggers_auto_title_after_reply`

```dart
testWidgets('A 模式后置自动 title 生成（流式回复结束后触发）', (tester) async {
  // 1. A 模式创建空分支 + mock LLM 配置 chatModel
  // 2. 用户发首条消息 → LLM 流式回复结束（用 topic_llm_client 注入 mock）
  // 3. 监听 node.title 变化
  // 4. 断言：最终 title ≠ "临时会话"（LLM 生成）
  // 5. mock 验证：title 生成调用 1 次
});
```

#### Test 9.3：`branch_blank_retries_on_llm_failure`

```dart
testWidgets('A 模式自动 title 重试 3 次（指数退避）', (tester) async {
  // 1. A 模式创建空分支 + mock LLM 让 title 调用前 2 次失败、第 3 次成功
  // 2. 用户发首条消息 → LLM 流式回复结束
  // 3. 断言：最终 title = LLM 生成值；mock 验证：调用 3 次
});
```

#### Test 9.4：`branch_blank_skips_auto_title_when_user_edited`

```dart
testWidgets('A 模式用户手动改 title 后跳过自动生成', (tester) async {
  // 1. A 模式创建空分支 + mock LLM
  // 2. 创建后立即手动改 title（通过 chat 顶栏 rename 功能或 DB 直接更新）
  // 3. 发消息 → LLM 回复结束
  // 4. 断言：mock 验证：未调用 title 生成；title = 用户手动改的值
});
```

**测试基础设施依赖：**

- `integration_test/_support/topic_llm_client.dart`（已有）— 注入 mock LLM
- `integration_test/_support/topic_library.dart`（已有）— 主题库 fixture
- 集成测试 ValueKey 约定：
  - `'branch_mode_blank_option'` — 空白分支选项（任务 2 加）
  - `'branch_button'` — chat 顶栏 branch 按钮（已有）

**验收：**
- [ ] 4 个 testWidgets 全绿
- [ ] 测试在 iOS sim 跑通（默认运行平台）
- [ ] 不破坏现有 4 个 branch_creation 用例

---

### 任务 10：跑测试 + 自检

**命令：**

```bash
# 1. 静态检查
flutter analyze

# 2. 集成测试（iOS sim）
flutter test integration_test/branch_creation_test.dart -d "iPhone 15 Pro"

# 3. 现有测试回归
flutter test integration_test/  # 全部集成测试
```

**自检清单：**

- [ ] `flutter analyze` 无新增 error/warning
- [ ] `branch_creation_test.dart` 8 个用例全绿（4 已有 + 4 新增）
- [ ] 现有 `search_test.dart` / `chat_async_recovery_test.dart` / `llm_error_retry_test.dart` / `theme_chat_e2e_test.dart` 全绿
- [ ] 手工验证 9 步（见下）

---

## 🧪 手工验证步骤（iOS sim）

1. **正常路径**：chat → branch → "空白分支" → 进入空 chat（title 显示"临时会话"）→ 发"我想讨论 iOS 26 的 App Intents" → LLM 回复 → 等流式结束 → title 变成 LLM 生成值
2. **未配置 chatModel**：同上但未配置 chatModel → 弹 `showLlmSetupAlert` 引导去配置 → title 保持"临时会话"
3. **重试路径**：mock 让 LLM 前 2 次失败 → 第 3 次成功 → title = LLM 生成值；观察 log 有重试记录
4. **重试 3 次全失败**：mock 让 LLM 全失败 → 静默，title 保持"临时会话"，无 crash、无 alert
5. **用户手动改 title 后跳过自动生成**：创建空分支 → 手动改 title 为"我的 iOS 26 计划" → 发消息 → LLM 回复结束 → **title 不变**
6. **raw 模式不变**：chat → branch → "使用原始上下文创建" → 行为跟之前一致（**回归保护**）
7. **summarize 模式不变**：chat → branch → "总结后创建" → 行为跟之前一致（**回归保护**）
8. **主题节点入口**：theme_detail_screen 节点 → branch → "空白分支" → 也能正常创建空子分支
9. **note → chat 不变**：笔记 → 创建对话 → 仍走 `sourceLabelOverride: 'note'`，**不应出现"空白分支"选项**

---

## ✅ 验收总览

| 层级 | 方式 | 目标 |
|------|------|------|
| 静态 | `flutter analyze` | 无新增 error/warning |
| 集成 | `integration_test/branch_creation_test.dart` | 8 个用例全绿（4 已有 + 4 新增） |
| 回归 | 现有集成测试套件 | 全绿 |
| 手工 | iOS sim 9 步 | 全通过 |

---

## ⚠️ 风险与缓解

| 风险 | 缓解 |
|------|------|
| `updateNodeSourceInfo` 改 nullable 破坏其他调用方 | 已审计：2 个调用方都传非 null String，安全迁移 |
| LLM 调用代码路径高度依赖 `TitleSuggestionService` 现有逻辑 | 任务 8 在 `_callTitleLlm` 中标注实施对齐点（参考 `title_suggestion_screen.dart:286-294`） |
| `chat_screen` 后置 hook 侵入现有流 | 用边沿检测 + flag 防抖，不改 `chatTaskStateProvider`；回归保护 9.2/9.3/9.4 |
| widget.title 不刷新（nav bar 不变） | 短期接受（用户手动刷新页面可见）；如需实时可在 `setState` 用本地 `_displayedTitle` 缓存 |

---

## 🛡️ 回归保护清单

A 模式独立原则（**不**触碰以下路径）：

- [ ] `summarize` 模式：`showBranchFlow` 行 803-888 的 LLM summary 逻辑
- [ ] `raw` 模式：`showBranchFlow` 行 834-837 的 parentTranscript 直接使用
- [ ] 现有 `updateNodeSourceInfo` 调用方：2 处行为不变（仅签名从 String 改 String?）
- [ ] `_sourceTypeLabel` 其他 4 case 不变
- [ ] `note → chat` 入口：仍走 `sourceLabelOverride: 'note'`，**不应**出现"空白分支"选项
- [ ] `chat_screen` 现有流：isStreaming / branch_button / model panel / composer 行为不变
- [ ] `chat_task_service.dart` 不修改：只在 chat_screen 端监听状态变化

---

## 📁 涉及文件汇总

**新增：** 0 个（l10n 生成文件由 `flutter gen-l10n` 自动产出）

**修改（7 个）：**
- `lib/ui/core/shared/title_suggestion_screen.dart` — BranchMode.blank + sheet 选项 + showBranchFlow 早期返回 + `_createBlankBranch`
- `lib/data/stores/node_store.dart` — `updateNodeSourceInfo` 签名允许 sourceExcerpt=null
- `lib/ui/features/themes/theme_detail_screen.dart` — `_sourceTypeLabel` switch 加 `userIdea`
- `lib/ui/features/chat/chat_screen.dart` — 后置自动 title 生成 + 重试 + 防抖
- `lib/l10n/app_zh.arb` — 新增 3 个键
- `lib/l10n/app_en.arb` — 新增 3 个键
- `integration_test/branch_creation_test.dart` — 新增 4 个 A 模式用例

**worktree：**

```bash
git worktree add ../ThkTree-worktrees/branch-blank-mode -b codex/branch-blank-mode
```

---

## 📚 引用

- 上游 brainstorming：`docs/_tmp/2026-06-28-branch-blank-mode.md`
- 现有分支创建：`lib/ui/core/shared/title_suggestion_screen.dart`
- LLM 模型解析：`lib/ui/core/shared/llm_setup_check.dart`
- 现有集成测试示例：`integration_test/branch_creation_test.dart`
- AGENTS.md 测试策略：本项目禁用单测，全部靠集成测试 + 手工验证

---

## 🎬 执行顺序建议

```
任务 5（l10n） ─┐
                ├─→ 任务 6（gen-l10n） ─→ 任务 7（_sourceTypeLabel）
任务 1（enum） ─┘
                 ↓
                任务 2（sheet UI） ─→ 任务 3（showBranchFlow + _createBlankBranch）
                 ↓
                任务 4（updateNodeSourceInfo 签名）
                 ↓
                任务 8（chat_screen 后置自动 title）
                 ↓
                任务 9（集成测试 4 用例） ─→ 任务 10（跑测试 + 自检）
```

并行友好组：

- 组 A（独立）：任务 1 + 任务 4 + 任务 5
- 组 B（依赖 A）：任务 2 + 任务 7
- 组 C（依赖 B）：任务 3 + 任务 6
- 组 D（依赖 C）：任务 8
- 组 E（依赖 D）：任务 9 → 任务 10
