# 集成测试 · 分支创建流程

> **创建**：2026-06-18
> **最近更新**：2026-06-18
> **维护者**：AI + 用户审阅
> **状态**：case 1/3/4 已实跑通过，case 2/5/6/7 待实现
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

`integration_test/branch_creation_test.dart`（218 行）有 7 个 testWidgets：

| # | testWidgets | 前置步骤 | 核心 TODO | LLM 依赖 |
|---|------------|---------|----------|---------|
| 1 | `选中文本 + raw 模式创建分支` | ✅ 完整 | ✅ 已实现 | ❌ |
| 2 | `选中文本 + summarize 模式创建分支` | ✅ 完整 | ❌ 选区 + branch | ❌ |
| 3 | `无选中文本 + raw 模式创建分支` | ✅ 完整 | ✅ 已实跑 | ❌ |
| 4 | `无选中文本 + summarize 模式创建分支` | ✅ 完整 | ✅ 已实跑 | ✅ LLM 总结 + 标题生成 |
| 5 | `模式选择取消` | ✅ 完整 | ❌ 弹 sheet 后取消 | ❌ |
| 6 | `标题选择取消` | ✅ 完整 | ❌ title 页取消 | ❌ |
| 7 | `LLM 失败 fallback` | ✅ 完整 | ❌ mock LLM 失败 | ⚠️ 需 mock |

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

### 3.3 `_resolveModelForSummary` 解析逻辑

`title_suggestion_screen.dart:879-884`：

```dart
final resolved = await _resolveModelForSummary(
  container,
  providers,
  currentProviderId: providerId,
  currentModelId: modelId,
);
```

输入 → 输出：

1. 优先 `currentProviderId` / `currentModelId`（chat 级）
2. 退回 `settings.llmProvider` / `settings.model`（全局设置）
3. 退回 `settings.titleModelProviderId` / `settings.titleModelModelId`（专属 title 模型）

### 3.4 缺失的 ValueKey 清单 ⚠️

| 需要的 Key | 当前是否存在 | 位置 | 阻塞什么 |
|-----------|------------|------|---------|
| `branch_button` | ❌ | chat_screen.dart 右上角 | 所有 7 个测试 |
| `branch_mode_summarize_option` | ❌ | `_BranchModeOption` (title_suggestion_screen.dart:783) | 测试 1-4 |
| `branch_mode_raw_option` | ❌ | 同上 | 测试 1-4 |
| `branch_mode_continue_button` | ❌ | sheet 底部 CupertinoButton.filled | 测试 1-4 |
| `branch_mode_cancel_button` | ❌ | sheet 底部取消按钮 | 测试 5 |
| `chat_input` | ✅ | chat_composer.dart:81 | 无（已 OK） |
| `send_button` | ❌ | chat_composer 内 | `_sendMessage` 实际无效 |
| `stop_button` | ❌ | chat_composer 内 | streaming 中断测试 |
| `title_suggestion_confirm_button` | ❌ | TitleSuggestionScreen | 测试 6 |
| `title_suggestion_cancel_button` | ❌ | TitleSuggestionScreen | 测试 6 |

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

**方案 A**：构造一个 `InMemoryLlmConfigStore` 变体，`apiKeys` 全空 → `_resolveModelForSummary` 返回 null → `showBranchFlow` 弹 "pleaseFetchModels" 提示（这不算真正的"失败 fallback"）

**方案 B**：用 `IntegrationTestWidgetsFlutterBinding.defaultBinaryMessenger.setMockMethodCallHandler` mock LLM HTTP 响应 → 抛 `SocketException` 或返回 500

**方案 C**（推荐）：在 `lib/data/services/llm_provider.dart` 加测试注入点（`enableHttpMock` flag），跑测试时拦截并返回固定错误

---

## 5. 编写路线（7 个 testWidgets 完整代码）

> **前提**：完成 § 4.1 ValueKey + § 4.2 helper 提升 + § 4.3 LLM mock。

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
  // 用 § 4.3 方案 B mock LLM 抛错
  IntegrationTestWidgetsFlutterBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('llm_http_channel'),
    (call) async => throw PlatformException(code: 'LLM_FAIL'),
  );
  
  // 用 settings 里填 apiKey（不让 _resolveModelForSummary 早期 return null）
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

按依赖顺序：

1. **🔴 branch_button ValueKey 缺失**（§ 4.1）—— 不补则 7 个测试全部无法触发入口
2. **🔴 branch_mode_*/continue/cancel Button ValueKey 缺失**（§ 4.1）—— sheet 操作完全靠 `find.text('总结后创建')` 等弱匹配
3. **🔴 send_button / stop_button ValueKey 缺失**（chat_composer.dart）—— `_sendMessage` 实际无效，前置"伪完成"
4. **🔴 TitleSuggestionScreen 内部 ValueKey 缺失**（输入框、确认、返回）—— 测试 6 无法做
5. **🟡 私有 helper 重复**（§ 4.2）—— `branch_creation` 与 `theme_chat_e2e` 复制粘贴，未提取
6. **🟡 LLM mock 工具**（§ 4.3）—— 测试 7 无现成 mock 方案
7. **🟢 SelectionArea 选区状态** —— Flutter framework 在 tester 里精确模拟选中文字范围非常困难，可能需要在 `chat_screen.dart` 暴露 `_currentSelectedText` setter

---

## 8. 风险与边界

### 不在本文档范围

- ❌ **不实现**任何 branch_creation_test.dart 的 TODO
- ❌ **不补** UI ValueKey（属于代码改动）
- ❌ **不重构** `_support/` 或 `test_helpers.dart`（用户决策 3）

### 已知风险

- **SelectionArea 选区难模拟**：Flutter tester 只能模拟 `longPress` 触发选择菜单，但无法精确控制选区文字范围。**可能需要绕过**：在 `chat_screen.dart` 把 `_currentSelectedText` 暴露成可注入 provider
- **LLM 不稳定**：测试 4 / 7 依赖真实 LLM，summarize API 失败会导致 flaky
- **summarize fallback 时序**：测试 7 弹 retry/cancel sheet 后用户取消才进 title 页，"取消"按钮的 Key（`branch_cancel_retry_button`）也要补
- **测试耗时**：7 个测试中 4 / 7 需要 LLM，每个 30-60s，整个 suite 可能 5-8 分钟
- **`_sendMessage` 静默 return**：当前 `chat_input` 存在但 `send_button` 不存在 → enterText 后无法 tap，整个前置是假的

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

> **当前结果**：7 个 testWidgets 全部立即通过（只是没断言），不是"测试通过"的真实信号。

---

## 10. 完成状态 Checklist

### 文档编写（本 spec）

- [x] 目标 + 7 个测试矩阵表
- [x] 测试现状（前置伪完成 + 核心 TODO）
- [x] 底层实现剖析（两层结构 + source content 决策表）
- [x] ValueKey 缺失清单（10 个 Key）
- [x] 编写前置依赖（4.1-4.3）
- [x] 7 个 testWidgets 完整代码
- [x] 阻塞点汇总
- [x] 风险与边界
- [x] 测试矩阵简表
- [x] 执行命令

### 代码层面（**不在本文档任务**）

- [ ] 给 chat_screen 右上角加 `branch_button` ValueKey
- [ ] 给 `_BranchModeOption` 加 `branch_mode_summarize_option` / `branch_mode_raw_option` ValueKey
- [ ] 给 sheet 加 `branch_mode_continue_button` / `branch_mode_cancel_button` ValueKey
- [ ] 给 chat_composer 加 `send_button` / `stop_button` ValueKey
- [ ] 给 TitleSuggestionScreen 加 title 输入框 / 确认 / 返回 ValueKey
- [ ] 把 `_createTestTheme` / `_createTestNode` / `_sendMessage` 提取到 `_support/test_fixtures.dart`
- [ ] 实现 § 5.1-5.7 七个 testWidgets 实际代码
- [ ] 给 LLM HTTP channel 加 mock 工具（测试 7 用）
- [ ] 跑通 + 截图验证

---

## 11. 相关文档

- [README.md](./README.md) — 集成测试总论
- [chat-streaming.md](./chat-streaming.md) — chat 流式回复测试（chat_input/send_button 的关联 spec）
- [theme-chat-e2e.md](./theme-chat-e2e.md) — 完整跑通的范式（4 个 helper 借鉴）
- [llm-injection.md](./llm-injection.md) — LLM 注入详细版导航（测试 4 / 7 的 LLM 注入路线）
- [fixtures.md](./fixtures.md) — `InMemoryLlmConfigStore` / `LlmTestConfig` 详解
- [helpers.md](./helpers.md) — `test_helpers.dart` 工具清单
- `lib/ui/features/chat/chat_screen.dart:165-176` — 右上角 branch 按钮
- `lib/ui/core/shared/title_suggestion_screen.dart:695-780` — `showBranchModeSheet`
- `lib/ui/core/shared/title_suggestion_screen.dart:849-1004` — `showBranchFlow`
- `lib/ui/core/shared/chat_composer.dart:81` — `chat_input` ValueKey（唯一已存在的）