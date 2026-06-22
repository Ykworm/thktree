# 对话后台中断恢复测试（chat_async_recovery_test.dart）

> **文件**：[`integration_test/chat_async_recovery_test.dart`](../../../integration_test/chat_async_recovery_test.dart)（442 行，4 个 testWidgets）
> **状态**：✅ **完整可跑通**（Test 1 是 focused 测试，无需 LLM Key；Test 2/3/4 用 mock Bridge + mock LlmClient 避免真发 API）
> **设计**：**不进 chat_screen UI**，直接构造 ProviderContainer + override `chatTaskServiceProvider`，绕过 chat_screen 初始化链路，专注验 ChatTaskService 服务层契约

---

## 1. 覆盖场景（4 个 testWidgets）

| 测试名 | 场景 | 关键交互 | 实现状态 |
|--------|------|----------|----------|
| `findInterrupted 返回含 streaming 标记的 node` | focused：磁盘扫描契约（new + legacy 两种 marker 格式） | 写 3 个 session.md（2 个含 marker / 1 个无）→ `SessionStore.findInterrupted()` | ✅ |
| `resumeInterrupted 把磁盘中断 node 入队 + 启动串行 loop` | 串行排队 + loop 启动 + 磁盘 marker 清副作用 | `_createTestEnv(2 个中断 node)` → `service.resumeInterrupted()` → 验 `resumeQueueLength` / `isResuming` / 磁盘 marker 被清 | ✅ |
| `cancelResumeQueue 清空 queue + generation 自增让 loop 退出` | 取消语义：queue 清空 + 不抛错 + 二次入队后能 cancel | 入队 → cancel → 验 queue 清空 + 二次入队后立即 cancel | ✅ |
| `startTask → onDone 期间 bridge.begin/end 各 1 次` | bridge 配对契约 | `_CountingBridge` → `startTask` + `_NoopLlmClient` → 验 begin/end 各 1 次 | ✅ |

---

## 2. 现状评估

### 2.1 测试设计原则

- **不进 UI**：不调 chat_screen / chat_controller，直接构造 `ProviderContainer` + override `chatTaskServiceProvider`，绕过 chat_screen 初始化链路
- **聚焦 service 契约**：Test 2/3/4 验 ChatTaskService 的状态机（`resumeQueueLength` / `isResuming` / `generation`），不验流式文字内容
- **Mock 而不是真发**：用 `_CountingBridge` / `_NoopLlmClient` 替换原生 MethodChannel 和 LLM 调用，避免 flake
- **磁盘为真相源**：所有中断状态从 `themes/<themeId>/<nodeId>/session.md` 读，不依赖任何 in-memory 状态

### 2.2 Test 1 是 focused 测试

`SessionStore.findInterrupted()` 是纯磁盘扫描逻辑（解析 YAML + 流式标记匹配），不需要 Provider 也不需要 LLM Key，**可独立跑绿**：

```bash
flutter test integration_test/chat_async_recovery_test.dart \
  --plain-name 'findInterrupted' -d "iPhone 15 Pro"
```

适合作为重构 `SessionStore.findInterrupted()` 时的回归 baseline。

### 2.3 Test 2/3/4 的 mock 链路

```
Test 2/3/4 入口
  ↓
_createTestEnv(initialNodes) — 准备临时 theme 目录 + 写初始 session.md
  ↓
ProviderContainer(overrides: [
  appSettingsProvider.overrideWith((ref) async => fakeSettings),    // 假 AppSettings
  llmConfigStoreProvider.overrideWithValue(fakeConfigStore),        // 空 InMemoryLlmConfigStore
  sessionStoreProvider.overrideWith((ref) async => stubSessionStore), // 只实现 2 个方法的 stub
  chatTaskServiceProvider.overrideWith(() => ChatTaskService(bridge: _CountingBridge())),
])
  ↓
container.read(chatTaskServiceProvider.notifier)
  ↓
service.resumeInterrupted() / service.cancelResumeQueue() / service.startTask(...)
  ↓
验 service.resumeQueueLength / isResuming / bridge.beginCount / bridge.endCount
```

---

## 3. Mock 类设计

### 3.1 `_CountingBridge extends BackgroundTaskBridge`

计数 `begin()` / `end()` 调用次数，用于验证 `startTask` 时桥接口的配对契约：

```dart
class _CountingBridge extends BackgroundTaskBridge {
  _CountingBridge() : super(methodChannel: const MethodChannel('thktree/background_task_mock'));

  int beginCount = 0;
  int endCount = 0;

  @override
  Future<String?> begin() async {
    beginCount++;
    return 'mock-task-id';
  }

  @override
  Future<bool> end() async {
    endCount++;
    return true;
  }
}
```

⚠️ 注意：`begin()` 返回 mock task-id（任意字符串），`end()` 返回 true——这是 BackgroundTaskBridge 抽象方法的最小实现，**不真发 MethodChannel 调用**（channel name `thktree/background_task_mock` 在 Simulator 进程无 native handler，但因 override 了方法体不会触发）。

### 3.2 `_NoopLlmClient extends LlmClient`

`const _NoopLlmClient()` —— 立即 yield `'mock-reply'` 单 token 后结束，不真发 HTTP：

```dart
class _NoopLlmClient extends LlmClient {
  const _NoopLlmClient();

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
  }) async* {
    yield 'mock-reply';
  }
}
```

只用于 Test 4（`startTask` 路径需要 `Stream<String>` 才能触发 onDone）。

### 3.3 `_StubSessionStore implements SessionStore`

只实现 ChatTaskService 测试路径用到的 2 个方法，其他方法 `noSuchMethod` 抛 `UnimplementedError`：

```dart
class _StubSessionStore implements SessionStore {
  _StubSessionStore(this._sessionPaths);
  final Map<String, String> _sessionPaths;

  @override
  Future<String> Function(String) get getSessionPathForNode =>
      (String nodeId) async => _sessionPaths[nodeId] ?? '';

  @override
  Future<bool> finishStreamingMessage({required String nodeId}) async {
    // 移除尾部 streaming 标记（new + legacy 两种格式）
    final path = _sessionPaths[nodeId];
    if (path == null) return false;
    final file = File(path);
    if (!await file.exists()) return false;
    final content = await file.readAsString();
    String stripped = content;
    if (stripped.endsWith('\n<!-- streaming -->\n')) {
      stripped = stripped.substring(0, stripped.length - '\n<!-- streaming -->\n'.length);
    } else if (stripped.endsWith('<!-- streaming -->\n')) {
      stripped = stripped.substring(0, stripped.length - '<!-- streaming -->\n'.length);
    }
    await file.writeAsString(stripped);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_StubSessionStore: 未实现 ${invocation.memberName}（仅供 chat_async_recovery_test 用）',
    );
  }
}
```

⚠️ `noSuchMethod` 抛错是**有意设计**——如果 ChatTaskService 哪天新增了对其他 SessionStore 方法的调用，测试会立即在第一个错误方法上炸出来，**防止悄悄过测试**。

---

## 4. 依赖 helpers

**无需** `integration_test/_support/test_helpers.dart` 的 UI 工具函数（不进 UI）。

私有 helper（文件内）：

- `_createTestEnv({required initialNodes})` — 构造 ProviderContainer + 写临时 theme 目录 + 准备 stub
- `_StubSessionStore` — 聚焦 2 个方法的 stub（见 § 3.3）
- `_CountingBridge` / `_NoopLlmClient` — 见 § 3.1 / § 3.2

---

## 5. 依赖 _support/fixtures

来自 [`integration_test/_support/in_memory_llm_config_store.dart`](../../../integration_test/_support/in_memory_llm_config_store.dart)：

- `InMemoryLlmConfigStore(providers: const [], apiKeys: const {})` — 空 store，测试用

来自 [`integration_test/_support/llm_test_config.dart`](../../../integration_test/_support/llm_test_config.dart)：

- ❌ **本测试不依赖 `LlmTestConfig.loadFromDefine()`** —— 因为不进 chat_screen 链路，fake `AppSettings` 直接 override `appSettingsProvider` 即可

⚠️ 但 Test 2/3/4 仍需 `--dart-define-from-file=build/dart_define.json` 才能通过 `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` 检查（否则 LlmTestConfig 在 setup 阶段抛 StateError，参考 [README.md § 8.3](./README.md#83-常见错误)）。

---

## 6. 阻塞点

### 6.1 临时 theme 目录的清理

Test 1/4 自建临时 theme 目录，try/finally 或 addTearDown 强制清理；Test 2/3 用 addTearDown。但 `getApplicationDocumentsDirectory()` 在 iOS Simulator 里指向 app sandbox，**清理失败不会污染其他测试**（每个测试用 `microsecondsSinceEpoch` 后缀区分 themeId）。

### 6.2 `_nodeStore == null` 时 _retry 立即返回

Test 2 的关键行为：`service.resumeInterrupted()` 启动 loop 后立即调 `_retry`，但 `_nodeStore == null`（测试未注入），所以 `_retry` 直接 return → loop 几乎同步退出。

这意味着 Test 2 实际验证的是：

- ✅ 入队动作（`resumeQueueLength == 2`）
- ✅ loop 启动语义（`isResuming == true` 期间）
- ✅ `finishStreamingMessage` 副作用被触发（磁盘 streaming 标记被清掉）

而不是验证真正的"串行逐个重发"——后者需要 mock 一个慢 LlmClient 才能验（**当前未实现**，见 § 8.2 改进建议）。

### 6.3 Test 3 的"中途中断"难以 mock

Test 3 想验证"loop 已启动但 queue 还有未执行项时 cancel"，但当前 `_nodeStore == null` 导致 loop 同步退出，没法构造"loop 在跑"的状态。

简化方案（当前实现）：

1. 先调 `resumeInterrupted()` 让所有 node 入队，等 loop 退出
2. 调 `cancelResumeQueue()` 验证不抛错 + 状态正确
3. 再次入队后立即 cancel，验证 cancel 能清空

**未覆盖**：loop 在跑时 cancel 真的中断了 `_retry` 调用的场景——见 § 8.3 改进建议。

### 6.4 chat_screen 未参与

本测试不进 chat_screen，所以**未验证**以下 UI 层契约：

- `chat_controller` 监听 ChatTaskService state → send_button / stop_button 状态切换
- App 切后台 → foreground 时 chat_screen 触发 `resumeInterrupted`
- resume 期间 UI 显示"恢复中..."提示

这些 UI 契约属于端到端集成测试范畴（可能放在 theme-chat-e2e.md 后续 round），**当前不在 chat_async_recovery 范围**。

---

## 7. 跑通步骤

```bash
# 1. 创建 Key 配置文件（首次；推荐放 ~/.thktree/，不入仓）
mkdir -p ~/.thktree
cp docs/_tmp/2026-06-20-llm-test-config-redesign.md ~/.thktree/test_llm_config.example.md   # 参考 JSON 结构
$EDITOR ~/.thktree/test_llm_config.json
# 填入真 Key（参考 docs/_tmp/2026-06-20-llm-test-config-redesign.md § 7 JSON 结构）

# 2. 启动 iOS Simulator
open -a Simulator

# 3. 经生成器压缩为 build/dart_define.json（不在 dart-define value 里留字面 \n）
dart run tools/gen_dart_define.dart \
  $HOME/.thktree/test_llm_config.json \
  build/dart_define.json

# 4. 跑全部 4 个测试
flutter test integration_test/chat_async_recovery_test.dart \
  --dart-define-from-file=build/dart_define.json \
  -d "iPhone 15 Pro"

# 5. 只跑 Test 1（focused，不需要 LLM Key，但仍需 dart-define 让 binding 初始化通过）
flutter test integration_test/chat_async_recovery_test.dart \
  --plain-name 'findInterrupted' -d "iPhone 15 Pro"

# 6. 只跑 Test 4（bridge.begin-end 配对）
flutter test integration_test/chat_async_recovery_test.dart \
  --plain-name 'startTask' \
  --dart-define-from-file=build/dart_define.json \
  -d "iPhone 15 Pro"
```

---

## 8. 改进建议

### 8.1 抽 _createTestEnv 到 _support/

`_createTestEnv` 是稳定的 helper，未来其他 ChatTaskService 测试（如 retry / cancel / concurrency）会复用。可考虑抽到 `integration_test/_support/chat_task_test_env.dart`。

### 8.2 慢 LlmClient 模拟串行重发

Test 2 缺"loop 真的在逐个重发"的验证。可改造 `_NoopLlmClient` 加 `Duration delay` 参数：

```dart
class _DelayedNoopLlmClient extends LlmClient {
  _DelayedNoopLlmClient({this.delay = const Duration(milliseconds: 100)});
  final Duration delay;

  @override
  Stream<String> streamChatCompletion({...}) async* {
    await Future<void>.delayed(delay);
    yield 'mock-reply';
  }
}
```

然后 Test 2 注入 mock `_nodeStore`（让 `_retry` 不再走 early return），验 `queue` 长度从 2 → 1 → 0 的过程。

### 8.3 验 cancel 真的中断 loop

Test 3 可构造"loop 在 sleep 期间被 cancel"场景：

- `_DelayedNoopLlmClient(delay: 1s)`
- `resumeInterrupted()` 启动 loop
- 立即 `cancelResumeQueue()`
- 验 `generation` 自增，下次 `_retry` 检查 `generation != startGeneration` 时退出
- 验 `queue` 清空，且当前 task 没生成 `'mock-reply'`

### 8.4 加 chat_screen E2E 测试

本测试不进 UI，建议后续加 `theme_chat_e2e` 的扩展版，验"切后台 → 切回 → UI 显示恢复中 → resume 完成后 chat list 完整"。

### 8.5 _CountingBridge 暴露 task-id 序列

如未来需要验"begin/end 嵌套"（如并发任务），可让 `_CountingBridge` 记录每次 begin 的 task-id 和对应 end 的时间戳，验 begin→end 是栈式配对。

---

## 9. 相关文档

- [README.md](./README.md#10-测试现状速览表) — 总论速览表（chat_async_recovery 行已加入）
- [theme-chat-e2e.md](./theme-chat-e2e.md) — 完整 UI E2E 测试范例（可作为 chat_screen 端到端扩展基础）
- [fixtures.md](./fixtures.md) — LLM 注入 / InMemoryLlmConfigStore 详解
- [helpers.md](./helpers.md) — test_helpers.dart 工具函数
- [chat-streaming.md](./chat-streaming.md) — 流式测试 spec（UI 链路，进 chat_screen）
- [lib/data/services/chat_task_service.dart](../../../lib/data/services/chat_task_service.dart) — 被测主体（`resumeInterrupted` / `cancelResumeQueue` / `startTask`）
- [lib/data/services/background_task_bridge.dart](../../../lib/data/services/background_task_bridge.dart) — Bridge 抽象基类
- [lib/data/stores/session_store.dart](../../../lib/data/stores/session_store.dart) — `findInterrupted` 静态方法定义处
- [docs/DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界](../../DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界) — 策略 ADR
- [docs/_tmp/ios-async-chat.md](../../_tmp/ios-async-chat.md) — brainstorming 草稿
