# 对话流式测试（chat_streaming_test.dart）

> **文件**：[`integration_test/chat_streaming_test.dart`](../../../integration_test/chat_streaming_test.dart)（172 行，3 个 testWidgets）  
> **状态**：❌ **TODO 占位**——所有 testWidgets 都只有注释 + 简单 `enterText/tap`，**没跑通**  
> **阻塞点**：缺 `navigateToChat` helper、缺部分 ValueKey 验证

---

## 1. 覆盖场景（3 个 testWidgets）

| 测试名 | 场景 | 关键交互 | 实现状态 |
|--------|------|----------|----------|
| `发送消息并等待流式回复` | 完整流程：发 → 流式 → 停止 → 再发 | `send_button` → `stop_button` → `send_button` | ❌ TODO |
| `发送空消息` | 边界：空字符串、纯空格 | `send_button` 点击 | ❌ TODO |
| `快速连续发送消息` | 顺序性：3 条消息连发 | 多次 `send_button` 点击 | ❌ TODO |

---

## 2. 现状评估

每个 testWidgets 都遵循相同模式：

```dart
testWidgets('xxx', (tester) async {
  // 1. 启动应用
  final app = await createTestApp();
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  // TODO: 导航到对话页面
  // 这里需要根据实际的应用导航流程来实现
  // 例如：点击主题列表 -> 进入某个主题 -> 点击某个节点 -> 进入对话页面

  // 测试场景：
  // 1. ...
  // 验证点：
  // - ...

  // 示例测试步骤（需要根据实际 UI 调整）：

  // 1. 找到聊天输入框
  final chatInput = find.byKey(const ValueKey('chat_input'));
  expect(chatInput, findsOneWidget, reason: '应该找到聊天输入框');

  // 2. 输入消息
  await enterTextAndWait(tester, chatInput, '...');
  // ...
});
```

**关键问题**：
1. 没有真正的"导航到对话页"代码（停留在 TODO 注释）
2. `expect(chatInput, findsOneWidget)` 在主题列表页**必然失败**——因为聊天输入框根本不在那个页面
3. 所有断言都被注释化了（`// 验证点：...`）

---

## 3. 编写路线

### 3.1 测试 1：发送消息并等待流式回复

完整实现：

```dart
testWidgets('发送消息并等待流式回复', (tester) async {
  // 加载 LLM 配置（参考 theme_chat_e2e_test.dart）
  // Key 来自 --dart-define-from-file 注入的 TEST_LLM_CONFIG_JSON 编译期常量。
  final llmConfig = LlmTestConfig.loadFromDefine();

  // 启动 App，强制中文 locale + 注入 LLM 配置
  final app = await createTestApp(
    locale: const Locale('zh'),
    llmSettings: llmConfig.toAppSettings(),
    llmConfigStore: llmConfig.toLlmConfigStore(),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  // ──── 导航：主题列表 → 主题详情 → 节点 → 聊天页 ────
  // 复用 theme_chat_e2e_test.dart 的辅助函数
  // （或者提取到 _support/，见 helpers.md 第 8.3 节）

  await _switchToTab(tester, '主题');  // ⚠️ 需要实现或 import
  await _createTheme(tester, '聊天测试主题');
  await tester.tap(find.text('聊天测试主题'));
  await tester.pumpAndSettle();
  await _createNode(tester, '聊天测试节点');
  await tester.tap(find.text('聊天测试节点'));
  await tester.pumpAndSettle();

  // ──── 进入聊天页，开始测试 ────
  final chatInput = find.byKey(const ValueKey('chat_input'));
  expect(chatInput, findsOneWidget);
  final sendButton = find.byKey(const ValueKey('send_button'));
  expect(sendButton, findsOneWidget);

  // 第一条消息
  await enterTextAndWait(tester, chatInput, '你好');
  await tester.tap(sendButton);
  await tester.pump();

  // 等 stop_button 出现 → 流式已启动
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('stop_button')),
    timeout: const Duration(seconds: 10),
  );

  // 等 send_button 回来 → 流式已结束
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('send_button')),
    timeout: const Duration(seconds: 90),
  );

  // 用户消息应在聊天列表
  expect(find.text('你好'), findsWidgets);

  // 第二条消息（验证连续对话）
  await enterTextAndWait(tester, chatInput, '今天天气怎么样');
  await tester.tap(sendButton);
  await tester.pump();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('stop_button')),
    timeout: const Duration(seconds: 10),
  );
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('send_button')),
    timeout: const Duration(seconds: 90),
  );
});
```

### 3.2 测试 2：发送空消息

```dart
testWidgets('发送空消息', (tester) async {
  // ... 启动 App + 导航到聊天页（复用测试 1 的前置） ...

  final chatInput = find.byKey(const ValueKey('chat_input'));
  final sendButton = find.byKey(const ValueKey('send_button'));

  // 发送空字符串
  await enterTextAndWait(tester, chatInput, '');
  await tester.tap(sendButton);
  await tester.pump();

  // 期望：流式不启动（stop_button 不应出现）
  await tester.pump(Duration(seconds: 2));
  expect(find.byKey(const ValueKey('stop_button')), findsNothing);

  // 发送纯空格
  await enterTextAndWait(tester, chatInput, '   ');
  await tester.tap(sendButton);
  await tester.pump();

  await tester.pump(Duration(seconds: 2));
  expect(find.byKey(const ValueKey('stop_button')), findsNothing);
});
```

### 3.3 测试 3：快速连续发送消息

```dart
testWidgets('快速连续发送消息', (tester) async {
  // ... 启动 App + 导航到聊天页 ...

  final chatInput = find.byKey(const ValueKey('chat_input'));
  final sendButton = find.byKey(const ValueKey('send_button'));

  // 快速连发 3 条
  await enterTextAndWait(tester, chatInput, '第一条');
  await tester.tap(sendButton);
  await tester.pump();

  // 注意：第一条还在流式时，send_button 应该是 stop_button
  // 所以"快速连发"实际只发出去第一条，第二条要等流式结束
  // 真实场景下用户可能等待或输入新的
  // 此测试主要验证：消息不会丢、顺序不乱

  await waitForWidget(
    tester,
    find.byKey(const ValueKey('send_button')),
    timeout: const Duration(seconds: 90),
  );

  await enterTextAndWait(tester, chatInput, '第二条');
  await tester.tap(sendButton);
  await tester.pump();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('send_button')),
    timeout: const Duration(seconds: 90),
  );

  await enterTextAndWait(tester, chatInput, '第三条');
  await tester.tap(sendButton);
  await tester.pump();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('send_button')),
    timeout: const Duration(seconds: 90),
  );

  // 验证 3 条用户消息都在
  expect(find.text('第一条'), findsWidgets);
  expect(find.text('第二条'), findsWidgets);
  expect(find.text('第三条'), findsWidgets);
});
```

---

## 4. 依赖 helpers

来自 [`integration_test/test_helpers.dart`](../../../integration_test/test_helpers.dart)：

- `enterTextAndWait` — 输入文本
- `waitForWidget` — 等待按钮状态变化
- `pumpAndSettleWithTimeout` — 等待 UI 稳定

## 5. 依赖 _support/fixtures

来自 [`integration_test/_support/llm_test_config.dart`](../../../integration_test/_support/llm_test_config.dart)：

- `LlmTestConfig.loadFromDefine()` — 同步从编译期常量读 LLM Key 配置（推荐）
- `config.toAppSettings()` — 转 AppSettings
- `config.toLlmConfigStore()` — 转 InMemoryLlmConfigStore

**所有 chat 相关测试都需要这个**（否则 chat_controller 路径 B 拿不到 Key，详见 [fixtures.md 第 4 节](./fixtures.md#4-toappsettings-vs-tollmconfigstore-双注入)）。

---

## 6. 阻塞点

### 6.1 `_switchToTab` / `_createTheme` / `_createNode` 未 import

这些 helper 在 `theme_chat_e2e_test.dart` 文件底部**私有定义**：

```dart
// integration_test/theme_chat_e2e_test.dart:163-207
Future<void> _switchToTab(WidgetTester tester, String label) async { ... }
Future<void> _createTheme(WidgetTester tester, String title) async { ... }
Future<void> _createNode(WidgetTester tester, String title) async { ... }
```

**chat_streaming_test.dart 要用的话**有 2 个选择：
1. 复制一份到本文件底部（**有重复**，违背 DRY）
2. 把这些 helper 提到 `_support/test_helpers.dart`（**推荐**，见 helpers.md 第 8.3 节）

### 6.2 ValueKey 待核实

文件用了以下 Key，**实际生产 widget 必须存在**：

- ✅ `chat_input`（已确认存在）
- ✅ `send_button`（已确认存在）
- ✅ `stop_button`（已确认存在）
- ⚠️ `add_button` / `title_input` / `confirm_button`（来自 `test_helpers.dart` 的 `createTestNode`，可能是泛化的，需要核实）
- ⚠️ `add_theme_button` / `theme_title_input` / `theme_create_button`（`theme_chat_e2e` 已加，但需确认在 chat_streaming 测试中可见）

### 6.3 聊天页是否有 LLM 流式超时配置

`theme_chat_e2e_test.dart` 用 90 秒超时是经验值。如果 chat_streaming 测试在生产 widget 改了超时逻辑，要同步更新。

---

## 7. 跑通步骤

```bash
# 1. 创建 Key 配置文件（首次；推荐放 ~/.thktree/，不入仓）
mkdir -p ~/.thktree
cp docs/_tmp/2026-06-20-llm-test-config-redesign.md ~/.thktree/test_llm_config.example.md   # 参考 JSON 结构
$EDITOR ~/.thktree/test_llm_config.json
# 填入真 Key（参考 docs/_tmp/2026-06-20-llm-test-config-redesign.md 第 7 节 JSON 结构）

# 2. 启动 iOS Simulator
open -a Simulator

# 3. 经生成器压缩为 build/dart_define.json（不在 dart-define value 里留字面 \n）
dart run tools/gen_dart_define.dart \
  $HOME/.thktree/test_llm_config.json \
  build/dart_define.json

# 4. 跑测试
flutter test integration_test/chat_streaming_test.dart \
  --dart-define-from-file=build/dart_define.json \
  -d "iPhone 15 Pro"

# 5. 跑指定测试
flutter test integration_test/chat_streaming_test.dart \
  --plain-name "发送空消息" \
  --dart-define-from-file=build/dart_define.json \
  -d "iPhone 15 Pro"
```

---

## 8. 改进建议

1. **共享前置**：把导航代码（创建主题→节点→进聊天页）抽成 `setUp` 或私有 helper
2. **提取 LLM 加载到 setUpAll**：避免每个 testWidgets 重复 `LlmTestConfig.loadFromDefine`
3. **改用 ValueKey 定位**：所有 `find.text` 都换成 `find.byKey`，提高稳定性
4. **共享 helper 到 _support/**：见 helpers.md 第 8.3 节
5. **CI 注入**：CI runner 在 `~/.thktree/test_llm_config.json` 预置 Key，命令行只传路径，不把 Key 写进任何脚本

---

## 9. 相关文档

- [README.md](./README.md#10-测试现状速览表) — 总论速览表
- [theme-chat-e2e.md](./theme-chat-e2e.md) — 完整可跑通的范例
- [fixtures.md](./fixtures.md) — LLM 注入详解
- [helpers.md](./helpers.md) — 工具函数
- [lib/ui/features/chat/chat_screen.dart](../../../lib/ui/features/chat/chat_screen.dart) — 聊天页 widget（ValueKey 核实）