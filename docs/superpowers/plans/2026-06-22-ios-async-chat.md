# iOS 异步聊天 — LLM 流式中断恢复（writing-plans）

> **草稿来源**：[docs/_tmp/ios-async-chat.md](../_tmp/ios-async-chat.md)（已通过用户拍板，5 项决策全 A）
> **任务类型**：普通功能（非 Bug 修复 / 非集成测试）
> **平台范围**：iOS-only
> **目标**：APP 切后台后，`beginBackgroundTask` 给短回复（<30s）续命；切回前台时扫描磁盘 `<!-- streaming -->` 标记，对所有未完成对话自动串行排队重发，长回复（≥30s）走兜底重发路径

## Architecture 概览

```
iOS Layer (Swift)                         Flutter Layer (Dart)
─────────────────                         ──────────────────
Info.plist                                 lib/data/services/
  UIBackgroundModes=[processing]            ├── chat_task_service.dart
                                            │     + resumeInterrupted()
AppDelegate.swift                           │     + cancelResumeQueue()
  + didInitializeImplicitFlutterEngine      │     + BackgroundTaskBridge 集成
                                            │
BackgroundTaskHandler.swift (new)           ├── session_store.dart
  MethodChannel "thktree/background_task"    │     + findInterrupted()
  begin/endBackgroundTask                    │
                                            lib/ui/features/chat/
                                            └── chat_controller.dart
                                                  复用 retryLastMessage() → removeLastAssistantMessage + sendUserMessage

                                            lib/main.dart
                                              AppLifecycleObserver (ConsumerStatefulWidget + WidgetsBindingObserver)
                                              on AppLifecycleState.resumed → chatTaskServiceProvider.resumeInterrupted()
```

## Open Questions（草稿遗留）— 全部已定

| 问题 | 决策 |
|------|------|
| 续传时如何衔接 assistant 历史 | 复用 `ChatController.retryLastMessage()`（chat_controller.dart:264），它已实现 `removeLastAssistantMessage` + `sendUserMessage` |
| 重发前是否清 `<!-- streaming -->` 标记 | 是。`SessionStore.finishStreamingMessage(nodeId)` 已存在可复用 |
| `finishAssistant` 清理路径是否完整 | 已完整，不动 |
| 切回前台二次提示 | 不弹提示，直接 watch Riverpod state；UI 自然走"流式生成"展示 |
| 串行排队可打断 | 暴露 `cancelResumeQueue()` 方法，用户手动停止按钮调用 |

---

## Task 1：iOS Info.plist 加 `UIBackgroundModes`

**类型**：原生配置改动

**文件**：`ios/Runner/Info.plist`

**改动**：在 `<dict>` 内新增（位置：`UIApplicationSceneManifest` 之前）：

```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
</array>
```

**验收**：
- `flutter build ios --release --no-codesign` 通过
- `plutil -p ios/Runner/Info.plist | grep UIBackgroundModes` 输出包含 `processing`

**理由**：声明 `processing` 后台模式让 App Store 审核理解应用有持续任务意图（虽然 `beginBackgroundTask` 本身不需要 UIBackgroundModes，但声明更友好且符合 Apple 审核建议）。

---

## Task 2：新增 iOS `BackgroundTaskHandler.swift`

**类型**：新文件

**文件**：`ios/Runner/BackgroundTaskHandler.swift`（新增）

**实现要点**：
- 类签名：`public class BackgroundTaskHandler: NSObject, FlutterPlugin`
- 静态方法 `register(with:)`：仿 `TtsPlugin.swift` 创建 MethodChannel "thktree/background_task"
- 实例属性：`private var backgroundTask: UIBackgroundTaskIdentifier = .invalid`
- `handle(_:result:)` 处理 3 个方法：
  - `"begin"` → `UIApplication.shared.beginBackgroundTask(withName: "thktree_llm_stream") { [weak self] in self?.endBackgroundTask() }`；返回 identifier 字符串（`"\(backgroundTask.rawValue)"`）
  - `"end"` → 若 `backgroundTask != .invalid` 则 `UIApplication.shared.endBackgroundTask(backgroundTask)`，置 `.invalid`，返回 `true`
  - `"isActive"` → 返回 `backgroundTask != .invalid`
- 边界：多次 `begin` 应先 `end` 旧的（避免 identifier 泄漏），返回新的 identifier

**参考**：[TtsPlugin.swift](file:///Users/yuweikang/dev/ykcode/ThkTree/ios/Runner/TtsPlugin.swift)（186 行，FlutterPlugin + FlutterMethodChannel 注册模式）

**验收**：
- Swift 编译通过（`cd ios && pod install` → `xcodebuild build -workspace Runner.xcworkspace -scheme Runner`）
- 在 Swift 测试桩中调用 `begin` 后能拿到非 `invalid` identifier

---

## Task 3：iOS `AppDelegate.swift` 注册 `BackgroundTaskHandler`

**类型**：原生注册

**文件**：`ios/Runner/AppDelegate.swift`

**改动**：在 `didInitializeImplicitFlutterEngine` 的 `TtsPlugin.register` 行后追加一行：

```swift
BackgroundTaskHandler.register(with: self)
```

**参考**：[AppDelegate.swift:19-25](file:///Users/yuweikang/dev/ykcode/ThkTree/ios/Runner/AppDelegate.swift#L19-L25)

**验收**：`grep BackgroundTaskHandler ios/Runner/AppDelegate.swift` 输出 1 行

---

## Task 4：Flutter `BackgroundTaskBridge`（MethodChannel 客户端）

**类型**：新文件

**文件**：`lib/data/services/background_task_bridge.dart`（新增）

**类设计**：

```dart
class BackgroundTaskBridge {
  static const _channel = MethodChannel('thktree/background_task');

  Future<String?> begin() async {
    try {
      final id = await _channel.invokeMethod<String>('begin');
      return id;
    } on PlatformException catch (e, st) {
      AppLogger.instance.error(e, st, hint: 'BackgroundTaskBridge.begin');
      return null;
    }
  }

  Future<bool> end() async {
    try {
      final ok = await _channel.invokeMethod<bool>('end') ?? false;
      return ok;
    } on PlatformException catch (e, st) {
      AppLogger.instance.error(e, st, hint: 'BackgroundTaskBridge.end');
      return false;
    }
  }

  Future<bool> isActive() async {
    try {
      return await _channel.invokeMethod<bool>('isActive') ?? false;
    } on PlatformException catch (e, st) {
      AppLogger.instance.error(e, st, hint: 'BackgroundTaskBridge.isActive');
      return false;
    }
  }
}
```

**关键约束**：
- **不抛异常** — bridge 调用一律 swallow PlatformException，记日志后返回 fallback（这是 best-effort 工具，不能因为 platform 不支持就阻塞主流程）
- 非 iOS 平台：`begin` 直接返回 null（不调 channel），`end` / `isActive` 返回 false
- `AppLogger.instance` 来自 [app_logger.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/core/app_logger.dart)（现有单例）

**验收**：
- `dart analyze lib/data/services/background_task_bridge.dart` 无 error
- 集成测试桩可 mock MethodChannel 验证调用次数

---

## Task 5：`SessionStore.findInterrupted()` — 扫描磁盘中断消息

**类型**：核心逻辑新增

**文件**：`lib/data/stores/session_store.dart`

**改动**：

新增静态方法（或实例方法，由你定）：

```dart
/// 扫描所有 session.md，找出含 `<!-- streaming -->` 标记的（nodeId, msgId）对。
/// 返回结构：`List<({String nodeId, String sessionPath})>`
///
/// 实现：
/// 1. 读所有 theme 目录（getApplicationDocumentsDirectory() 下）
/// 2. 遍历每个 theme 下的所有 node 目录
/// 3. 读 `<nodeDir>/session.md`（如有），扫描是否含 `_streamingMarker`
/// 4. 含标记 → 加入结果列表
///
/// 性能：扫盘全文件 I/O；只在 AppLifecycleState.resumed 触发一次；
/// 用 FileWriteQueue 之外独立并发（不阻塞正在写的 session.md）
Future<List<({String nodeId, String sessionPath})>> findInterrupted() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final themesDir = Directory(p.join(docsDir.path, 'themes'));
  if (!await themesDir.exists()) return const [];

  final results = <({String nodeId, String sessionPath})>[];
  await for (final themeDir in themesDir.list(followLinks: false)) {
    if (themeDir is! Directory) continue;
    await for (final nodeDir in themeDir.list(followLinks: false)) {
      if (nodeDir is! Directory) continue;
      final sessionPath = p.join(nodeDir.path, 'session.md');
      final file = File(sessionPath);
      if (!await file.exists()) continue;
      final content = await file.readAsString();
      if (content.contains(_streamingMarker) || content.contains(_legacyStreamingMarker)) {
        results.add((nodeId: p.basename(nodeDir.path), sessionPath: sessionPath));
      }
    }
  }
  return results;
}
```

**关键约束**：
- 用 `path` 包（已在 store 里 import）
- 用 `getApplicationDocumentsDirectory`（已有依赖 `path_provider`）
- 不复用 `FileWriteQueue`（避免被正常写阻塞）
- 处理 legacy marker（已存在的 `_legacyStreamingMarker`）

**验收**（高风险纯逻辑 + 数据格式校验 → 适合补 focused test）：
- focused test 1：构造 3 个 node dir，其中 2 个含 `<!-- streaming -->` 标记，调用 `findInterrupted()` 返回恰好 2 项
- focused test 2：空 themesDir → 返回 `[]`
- focused test 3：含 legacy marker `<!-- streaming -->\n`（无前置换行）也能识别

> **测试位置**：因项目禁用单测（参见 [FEATURES.md](../FEATURES.md) "2026-06-20 单测文件全量清理"），用 [integration_test 目录](../_shared/integration-testing/README.md) 下新增 `integration_test/session_recovery_test.dart`（用 `dart:io` 在 temp 目录构造 fake 目录结构，测完后清理）

---

## Task 6：`ChatTaskService.resumeInterrupted()` 串行排队 + `cancelResumeQueue()`

**类型**：核心服务扩展

**文件**：`lib/data/services/chat_task_service.dart`

**改动**：

新增依赖：
- `import 'package:thk_tree/data/services/background_task_bridge.dart';`
- 字段 `_bridge = BackgroundTaskBridge()`
- 字段 `_resumeQueue = <String>[]`（待重发的 nodeId 队列）
- 字段 `_isResuming = false`（是否正在串行执行）
- 字段 `_resumeGeneration = 0`（每次 cancelResumeQueue 递增，旧的串行循环检测到 generation 变化就退出）

新增方法：

```dart
/// 扫描磁盘中断消息，串行排队重发。
///
/// 流程：
/// 1. 调 sessionStore.findInterrupted() 拿到 [(nodeId, sessionPath), ...]
/// 2. 过滤：当前 hasTask(nodeId) 的不重发（流还活着）
/// 3. 过滤：nodeId 已在 _resumeQueue 中不重复入队
/// 4. 调 sessionStore.finishStreamingMessage(nodeId) 清掉 `<!-- streaming -->` 标记
/// 5. 入队；串行从队首取一个，调 _retry(nodeId)（见下）
///
/// 串行执行在 _resumeLoop() 私有方法里；新调用 resumeInterrupted() 不重启 loop。
Future<void> resumeInterrupted() async {
  if (!Platform.isIOS) return;  // 仅 iOS；Android 走自然恢复

  final sessionStore = ref.read(sessionStoreProvider).value;
  if (sessionStore == null) {
    logger?.warn?.('resumeInterrupted: sessionStore not ready, defer');
    return;
  }

  final interrupted = await sessionStore.findInterrupted();
  if (interrupted.isEmpty) return;

  // 去重 + 过滤活跃任务
  final newItems = interrupted
      .where((item) => !hasTask(item.nodeId))
      .where((item) => !_resumeQueue.contains(item.nodeId))
      .toList();

  if (newItems.isEmpty) return;

  // 清掉磁盘标记（避免下次 _read 又判为 streaming）
  for (final item in newItems) {
    try {
      await sessionStore.finishStreamingMessage(item.nodeId);
    } catch (e, st) {
      logger?.error?.('resumeInterrupted: finishStreamingMessage failed', e, st);
    }
    _resumeQueue.add(item.nodeId);
  }

  logger?.info?.('resumeInterrupted: enqueued ${newItems.length} node(s)');

  if (!_isResuming) {
    unawaited(_resumeLoop());
  }
}

/// 串行执行队列：每次取一个 nodeId，调 ChatController.retryLastMessage() 路径。
Future<void> _resumeLoop() async {
  _isResuming = true;
  final myGen = ++_resumeGeneration;
  try {
    while (_resumeQueue.isNotEmpty && myGen == _resumeGeneration) {
      final nodeId = _resumeQueue.removeAt(0);
      try {
        await _retry(nodeId);
      } catch (e, st) {
        logger?.error?.('resumeInterrupted: retry failed for $nodeId', e, st);
      }
    }
  } finally {
    if (myGen == _resumeGeneration) {
      _isResuming = false;
    }
  }
}

/// 委托给 ChatController.retryLastMessage(nodeId)。
/// 必须用 Riverpod 拿到 ChatControllerProvider 实例（family by nodeId）。
Future<void> _retry(String nodeId) async {
  // 关键：需要 chatControllerProvider(nodeId) 的 notifier；
  // provider 接受 ChatControllerParams(nodeId, title, autoTriggerReply: false)
  // title 通过 nodeStore 取
  final nodeStore = _nodeStore;
  if (nodeStore == null) {
    logger?.warn?.('_retry: nodeStore not ready, skip $nodeId');
    return;
  }
  final row = await nodeStore.getNodeRow(nodeId: nodeId);
  final title = row['title'] as String? ?? '';
  final params = ChatControllerParams(
    nodeId: nodeId,
    title: title,
    autoTriggerReply: false,
  );
  final controller = ref.read(chatControllerProvider(params).notifier);
  await controller.retryLastMessage();
}

/// 用户主动取消：清空队列 + 递增 generation 让正在跑的 loop 退出。
void cancelResumeQueue() {
  _resumeQueue.clear();
  _resumeGeneration++;
  logger?.info?.('cancelResumeQueue: cleared');
}
```

**关键约束**：
- `logger` 字段已存在于 `ChatTask`；service 层若没有 logger，需要新增（参考 `AppLogger.instance` 或私有 `Logger('ChatTaskService')`）
- `_nodeStore` 字段：service 已有 `initializeServices(searchService, nodeStore)`，把 `nodeStore` 存为私有字段
- `chatControllerProvider` 来自 [chat_controller.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/features/chat/chat_controller.dart) — 需 import 该文件
- `ChatControllerParams` 已 export
- `retryLastMessage()` 已是 public 方法（chat_controller.dart:264）

**与 BackgroundTaskBridge 集成**（Task 7 详细化）：
- `startTask` 开头调 `_bridge.begin()` 拿 background task id
- `onDone` / `onError` / 用户 stop 路径调 `_bridge.end()` 释放
- 30s 边界：iOS 自动杀 process 时 handler 闭包会调 `endBackgroundTask`，bridge 端在 `_end` 时 swallow 错误

---

## Task 7：`ChatTaskService` 集成 `BackgroundTaskBridge`（短回复后台保活）

**类型**：服务扩展

**文件**：`lib/data/services/chat_task_service.dart`（同 Task 6，可一起改）

**改动点**：

1. 在 `startTask` 开头插入：
```dart
final bgId = await _bridge.begin();
logger?.info?.('startTask: bg task started', {'bgId': bgId});
```

2. 在 `ChatTask` 完成后清理路径（onDone / onError / 用户取消 / generation 不匹配时）：
```dart
await _bridge.end();
```

3. `stopTask` 同步调 `_bridge.end()`

**关键约束**：
- **`end` 在 `onDone` 路径里必须 await 完再 return** — 否则 iOS 30s 窗口已关，LLM 流刚好完成写盘会出问题
- `begin` 在非 iOS 平台返回 null，仍继续正常 LLM 调用（不能因为拿不到 bg task 就拒绝 stream）
- 若 `begin` 失败（PlatformException），记 WARN 日志，不影响主流程

**验收**：
- dart analyze 无新增 error
- 集成测试（Task 9）验证：mock bridge → 验证 `begin` / `end` 调用次数

---

## Task 8：`AppLifecycleObserver` 在 `main.dart`

**类型**：生命周期集成

**文件**：`lib/main.dart`

**新增组件**：

```dart
class AppLifecycleObserver extends ConsumerStatefulWidget {
  const AppLifecycleObserver({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 切回前台：触发重发扫描
      ref.read(chatTaskServiceProvider.notifier).resumeInterrupted();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

**集成位置**：widget tree 中 `ChatTaskServiceInitializer` 之后包一层 `AppLifecycleObserver`（参考 [main.dart:ChatTaskServiceInitializer](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/main.dart) 模式）

**关键约束**：
- `WidgetsBindingObserver` 已存在（参考 `AuthGate` 若有，或 BiometricService）
- `chatTaskServiceProvider.notifier` 必须已初始化（ChatTaskServiceInitializer 已确保）
- `resumeInterrupted()` 是 fire-and-forget（不 await），UI 不阻塞

**验收**：
- 集成测试（Task 9）模拟 lifecycle 切换
- 手工验证：真机切后台 → 杀 LLM → 切回 → 流自动重发

---

## Task 9：`integration_test/chat_async_recovery_test.dart`

**类型**：集成测试新增

**文件**：`integration_test/chat_async_recovery_test.dart`（新增）

**测试用例设计**：

### Test 1：`扫描磁盘中断消息（focused）`

```dart
testWidgets('findInterrupted 返回含 streaming 标记的 node', (tester) async {
  // 准备：在 AppPaths.tempDir 下造 3 个 node：
  //   - node_a/session.md 含 `<!-- streaming -->` 标记
  //   - node_b/session.md 含 legacy 标记 `<!-- streaming -->\n`（无前置换行）
  //   - node_c/session.md 无标记
  // 调 SessionStore.findInterrupted() → 期望返回 2 项（node_a + node_b）
  // 清理：删除 temp 目录
});
```

### Test 2：`resumeInterrupted 串行排队`

```dart
testWidgets('resumeInterrupted 串行重发 2 个中断 node', (tester) async {
  final config = LlmTestConfig.loadFromDefine();
  final app = await createTestApp(
    llmSettings: config.toAppSettings(),
    llmConfigStore: config.toLlmConfigStore(),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  // 导航到 chat_screen，发第 1 条消息，等流式完成
  // 模拟"后台中断"：手动构造 node_b/session.md 含 streaming 标记
  // 调用 chatTaskServiceProvider.notifier.resumeInterrupted()
  // 期望：node_a + node_b 都重发，且 2 次重发不并发（用时间戳断言串行）
});
```

### Test 3：`cancelResumeQueue 中断排队`

```dart
testWidgets('cancelResumeQueue 清空未执行队列', (tester) async {
  // 准备：构造 3 个含 streaming 标记的 node
  // 调用 resumeInterrupted() 启动串行
  // 立即调 cancelResumeQueue()
  // 期望：队列清空，正在跑的继续跑完，后续不再触发
});
```

### Test 4：`BackgroundTaskBridge 调用次数`（仅 iOS 真机）

```dart
testWidgets('startTask → onDone 期间 bridge.begin/end 各 1 次', (tester) async {
  // 真实 LLM 链路；用 mock MethodChannel handler 计数
});
```

**运行命令**（参考 [chat-streaming.md § 7](../_shared/integration-testing/chat-streaming.md#7-跑通步骤)）：

```bash
dart run tools/gen_dart_define.dart \
  $HOME/.thktree/test_llm_config.json \
  build/dart_define.json
flutter test integration_test/chat_async_recovery_test.dart \
  --dart-define-from-file=build/dart_define.json \
  -d "iPhone 15 Pro"
```

**验收**：4 个 testWidgets 全绿（Test 1 不需要 LLM Key，可单独跑）

---

## Task 10：真机 30s 边界手工验证

**类型**：手动验证步骤

**触发条件**：Task 9 集成测试全绿后

**验证矩阵**：

| 场景 | 期望结果 |
|------|---------|
| 短回复（<5s）：发问 → 立即切后台 → 等 5s → 切回 | 已生成完整消息在 chat list；流仍在 watch state 中（无重发触发） |
| 长回复（≥30s）：发长问 → 切后台 → 等 35s → 切回 | 检测到 streaming 标记 → 自动重发整段；loading UI；已生成内容作为 history 附在新请求 |
| 切回时手动停止按钮 | 取消重发；session.md 标记清干净（不再有 `<!-- streaming -->`） |
| 杀进程 → 重启 APP | 启动时扫描磁盘，触发 resumeInterrupted（ChatTaskServiceInitializer 后） |
| 真机锁屏 60s → 解锁 | 与"切后台"等效 |

**验收 checklist**：
- [ ] 短回复场景：无需用户操作，自动接续
- [ ] 长回复场景：自动重发且不停重复
- [ ] 停止按钮可中断重发
- [ ] 重启 APP 后磁盘残留能被恢复
- [ ] log 中 `resumeInterrupted: enqueued N node(s)` 正确输出

---

## Task 11：文档同步（context-sync 阶段执行）

**类型**：文档更新（不在本次写代码的范围；执行时走 ctsync）

**预计影响**（仅列出文件名，具体改动在执行 ctsync 时确认）：

- `docs/DECISIONS.md` — 新增 ADR-015：iOS 后台 30s 边界 + 串行重发策略
- `docs/FEATURES.md` — 在 § 3 对话模块新增一行："iOS 后台流式恢复"
- `docs/modules/chat/README.md` — 在 § 维护要点新增"iOS 切后台中断恢复"小节
- `docs/_shared/integration-testing/chat-streaming.md` 或新建 `chat-async-recovery.md` — 记录测试约定

**执行时机**：所有代码 commit + 集成测试绿 + 真机 30s 验证通过后，用户触发"同步文档"

---

## 验收总览

| 层级 | 方式 | 命令 / 步骤 |
|------|------|------------|
| 静态检查 | `dart analyze` | `flutter analyze` 无新增 error/warning |
| iOS 构建 | xcodebuild | `cd ios && xcodebuild build -workspace Runner.xcworkspace -scheme Runner` 通过 |
| Focused 集成 | `findInterrupted` focused test | Test 1 独立跑绿 |
| 关键路径集成 | 串行重发 + cancel + bridge | Test 2/3/4 全绿 |
| 真机边界 | 30s 短回复 + 长回复 | Task 10 checklist 全 ✓ |

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| iOS 30s 边界硬限制，长回复必断 | 已确认走"自动重发"路径；LLM provider 不支持 SSE resume 是已知约束 |
| 串行重发时 LLM rate limit | 串行即避坑；后续若要并发上限，单独 ADR |
| 切回前台时用户已离开 chat 页面 | ChatController 按 family by nodeId 隔离；不同页面各自触发 watch，不互相阻塞 |
| `cancelResumeQueue` 与正在跑的 retryLastMessage 冲突 | generation 自增；正在跑的任务跑完一次就退出 loop；新调度的 retryLastMessage 走 ChatTaskService 的 stopTask 路径 |
| Android 平台兼容性 | Task 6 入口判断 `Platform.isIOS`，非 iOS 静默 no-op；本任务只覆盖 iOS |

## 涉及文件汇总

**新增**：
- `ios/Runner/BackgroundTaskHandler.swift`
- `lib/data/services/background_task_bridge.dart`
- `integration_test/chat_async_recovery_test.dart`
- `docs/superpowers/plans/2026-06-22-ios-async-chat.md`（本文件）

**修改**：
- `ios/Runner/Info.plist`（+UIBackgroundModes）
- `ios/Runner/AppDelegate.swift`（+BackgroundTaskHandler.register）
- `lib/data/stores/session_store.dart`（+findInterrupted）
- `lib/data/services/chat_task_service.dart`（+resumeInterrupted + cancelResumeQueue + bridge 集成）
- `lib/main.dart`（+AppLifecycleObserver）

**worktree**：

```bash
git worktree add ../ThkTree-worktrees/ios-async-chat -b codex/ios-async-chat
```

## 引用

- 草稿：[docs/_tmp/ios-async-chat.md](../_tmp/ios-async-chat.md)
- 复用方法：[ChatController.retryLastMessage](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/features/chat/chat_controller.dart) — 找最后非 streaming assistant + 配对 user + removeLastAssistantMessage + sendUserMessage
- 复用方法：[SessionStore.finishStreamingMessage](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/data/stores/session_store.dart) — 清 `<!-- streaming -->` 标记
- 参考实现：[TtsPlugin.swift](file:///Users/yuweikang/dev/ykcode/ThkTree/ios/Runner/TtsPlugin.swift) — FlutterPlugin + MethodChannel 注册模式
- 测试规范：[docs/_shared/integration-testing/chat-streaming.md](../_shared/integration-testing/chat-streaming.md) — `createTestApp` + `LlmTestConfig.loadFromDefine` + `enterTextAndWait`