# ChatController stop_button 卡死 bug 修复

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-20 |
| 范围 | chat 模块（`ChatController.onDone` 错误日志 + 时序清理） |
| 设计文档 | （无，本次属于 bug 修复，非新功能设计） |
| War Story | [`docs/war-stories/ui-ux/2026-06-20-chat-controller-stop-button-stuck.md`](../war-stories/ui-ux/2026-06-20-chat-controller-stop-button-stuck.md) |
| 状态 | ✅ 完成 |

## 背景

用户在新对话中点 `stop_button` 后，进程不响应、watchdog 触发；磁盘上 `session.md` 残留 `<!-- streaming -->` 标记；用户重启 app 看到那条 assistant 消息卡在"加载中"无法重试。

链路：`ChatController.sendUserMessage` → `LlmApiClient.stream` → SSE `onDone` → `await sessionStore.finishAssistant(handle)` → 异常 → catch 块 `await logger.error(...)` → 进程卡在 await 上，清理路径永不执行。

## 根因

`onDone` 的 catch 块里直接 `await ref.read(appLoggerProvider.future)` 后再 `await logger.error(...)`。`logger` 是 `AsyncNotifier` 实现的 AsyncValue 类型，第一次 `await` 触发 provider 初始化（潜在锁竞争），第二次 `await` 又是 IO 操作——这两步任一被阻塞，catch 块就不会返回。同时：

- `_handle = null` 和 `_cancelToken = null` 写在 `try` 块内最末尾；`finishAssistant` 抛错时这两行永远不会执行
- `_read()` 的自愈逻辑（`hasStreaming && _handle == null` → 视为 done）依赖 `_handle == null` 才生效
- 兜底刷新 UI 也只在 try 内；catch 内除了 `logger.error` 外没有任何兜底

最终表现：磁盘 `<!-- streaming -->` 永久残留、UI 永远显示 `stop_button`、用户无法重试也无法继续对话。

## 方案

走 **方案 A：三层防线**——fire-and-forget 错误日志 + 立即清状态 + 兜底 `_read()`。

### 第 1 层：fire-and-forget 错误日志

新加 `_safeLogError(...)` 私有方法，把 `await logger.error` 包成 IIFE（`() async { try { ... } catch (_) {} }();`），catch 块不再 `await`，立即返回，清理路径不再被 logger 阻塞。

### 第 2 层：立即清状态

把 `_handle = null` / `_cancelToken = null` 移到 `try` 块**顶部**（`finishAssistant` 之前）。即使 `finishAssistant` 抛错，这两个清理动作也已经执行。

### 第 3 层：兜底 `_read()`

catch 块内、记完日志后，**无条件** `await _read()` 刷新一次 UI。最差情况（`_read` 也抛错）下再降级用 `state.value ?? []` 作为 fallback，至少让 `stop_button` 消失、UI 恢复响应。

## 实施内容

### 修改文件（1）

```
lib/ui/features/chat/chat_controller.dart  # _safeLogError 新方法 + onDone 三层防线
```

### 关键改动

**`chat_controller.dart` — `_safeLogError` 新方法：**

```dart
/// Fire-and-forget error log. Never blocks caller (unlike raw `await logger.error`).
///
/// 关键设计：catch 块必须非阻塞，否则异常处理会卡住后续清理和 state 刷新。
/// 历史 onDone catch 路径 stop_button 卡死的根因之一就是 logger.await 阻塞了清理路径。
void _safeLogError(Object e, StackTrace st, String hint, {Map<String, Object?>? attrs}) {
  () async {
    try {
      final logger = await ref.read(appLoggerProvider.future);
      final fullAttrs = <String, Object?>{'nodeId': nodeId, 'title': title, ...?attrs};
      await logger.error(e, st, hint: hint, attrs: fullAttrs);
    } catch (_) {}
  }();
}
```

**`chat_controller.dart` — `onDone` 清理路径（关键 diff）：**

```dart
onDone: () async {
  final handle = _handle;
  if (handle == null) return;

  // 关键修复：立即清理 _handle，让 _read() 自愈逻辑（_read 内的
  // `hasStreaming && _handle == null` 分支）生效。
  // 即使 finishAssistant 抛错导致磁盘 streaming marker 残留，
  // 下一次 _read() 也会把残留 streaming 状态修正为 done，让 stop_button 消失。
  _handle = null;
  _cancelToken = null;

  try {
    if (_stopRequested) return;
    await sessionStore.finishAssistant(handle: handle);
    _updateSearchIndex(nodeId, handle);
    final readResult = await _read();
    if (_stopRequested) return;
    state = AsyncData(readResult);
  } catch (e, st) {
    // 详细日志：暴露 catch 进入的根因（之前被 logger.await 默默吞掉）
    dev.log('[ChatController.onDone] finishAssistant FAILED nodeId=$nodeId', name: 'ChatController');
    dev.log('  error: $e', name: 'ChatController');
    dev.log('  stack: $st', name: 'ChatController');

    // Fire-and-forget logger（避免 logger await 阻塞清理路径）
    _safeLogError(e, st, 'finishAssistant');

    // 兜底刷新 UI：无论 finishAssistant 是否成功，必须让 stop_button 消失。
    try {
      final readResult = await _read();
      if (_stopRequested) return;
      state = AsyncData(readResult);
    } catch (readError, readSt) {
      dev.log('[ChatController.onDone] _read fallback FAILED: $readError', name: 'ChatController');
      final fallback = state.value ?? const <SessionMessage>[];
      state = AsyncData(fallback);
    }
  }
},
```

## 验证

| 类别 | 状态 |
|---|---|
| `flutter analyze` | ✅ 无错（增量） |
| 集成测试 `chat_streaming_test.dart` | ✅ 既有流式边界用例通过 |
| 场景覆盖（手工） | ① 流式正常完成 ② 用户中途 stop ③ SSE 网络中断（`<!-- error: network -->` 落盘）④ 上一次流式异常残留 streaming marker 时再次进入页面（自愈为 done） |

## 已知风险（留给后续决定）

- `logger` provider 初始化失败时（极少见，理论上仅在 logger 文件系统被锁时发生），fire-and-forget catch 内的 `await` 会被外层 catch 吞掉，日志丢失但不影响 UI。后续如发现"日志丢失"成为问题，可在 `_safeLogError` 内加一层 fallback 写到 `dart:developer log`。
- 本次仅修复 `onDone` 路径；`onError` / `cancelToken.cancel()` / `state = AsyncError(...)` 等其他异常入口**未同步应用**三层防线。当前没有观察到这些路径的卡死现象，但理论上有同类风险。后续如发现，再按同样模式扩展。

## 关联

- [docs/war-stories/ui-ux/2026-06-20-chat-controller-stop-button-stuck.md](../war-stories/ui-ux/2026-06-20-chat-controller-stop-button-stuck.md) — 同类问题 war story
- [docs/_tmp/2026-06-20-model-config-redesign.md](../_tmp/2026-06-20-model-config-redesign.md) — 同日 chat 模块的模型配置 redesign 草稿
