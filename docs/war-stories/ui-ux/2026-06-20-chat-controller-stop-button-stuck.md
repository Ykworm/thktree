# ChatController stop_button 卡死（fire-and-forget 错误日志 + `_handle` 时序自愈）

**日期**：2026-06-20
**模块**：chat / ChatController
**标签**：Flutter, Riverpod, AsyncNotifier, SSE, fire-and-forget, onError, 时序, stop_button

## 现象

用户与 LLM 对话时，流式生成中途点击 stop_button，期望：

1. stop_button 立刻消失（响应"已停止"）
2. 当前那条 assistant 消息状态从 `streaming` → `done`，文本保留
3. 后续可以继续追问

实际表现（多个真实集成测试场景命中）：

- stop_button **长期不消失**，至少要等 watchdog（30s）触发后才会被动重置
- watchdog 触发后 `tools/fix_stale_streaming.py` 扫描到磁盘 streaming marker 残留，说明 DB 与磁盘状态曾经不一致
- 用户体验上"点停 → 看起来没反应 → 30s 后才更新"，等同 stop 功能失效

控制台异常（间歇性）：

```
[ChatController.onDone] finishAssistant FAILED nodeId=<uuid>
  error: <SqliteException: UNIQUE constraint failed: messages.id>
  stack: ...
```

或：

```
[ChatController.onDone] finishAssistant FAILED nodeId=<uuid>
  error: LateError: LateInitializationError: Field '_handle@...' has not been initialized
```

这些异常之前**完全看不到**，因为 catch 块里的 logger 自身可能抛错或被 await 卡住，吞掉了真正的根因。

## 根因分析

定位过程分三层，互相叠加：

### 根因 1：catch 块的 `await logger.error` 阻塞清理路径

`ChatController.onDone` 是 SSE onDone 回调，属于"清理路径"——它必须快速完成并刷新 state，否则 UI 上的 stop_button 会一直显示。

修复前代码：

```dart
} catch (e, st) {
  final logger = await ref.read(appLoggerProvider.future);
  await logger.error(e, st, hint: 'finishAssistant', attrs: {'nodeId': nodeId, 'title': title});
}
```

潜在问题：

- `appLoggerProvider` 是 AsyncNotifier，如果 logger 自身初始化失败，`await logger.error` 会抛二次异常
- logger 写日志到远端（HTTP）时如果网络抖动，await 会阻塞任意时长
- 整个 catch 块没有 `_handle = null`、没有 state 刷新 —— **异常路径下 stop_button 完全不更新**

### 根因 2：`_handle = null` 在 try 末尾，异常路径永远不清

修复前代码：

```dart
try {
  await sessionStore.finishAssistant(handle: handle);
  _updateSearchIndex(nodeId, handle);
  _handle = null;             // ← 在 try 末尾
  _cancelToken = null;
  final readResult = await _read();
  if (_stopRequested) return;
  state = AsyncData(readResult);
} catch (e, st) { /* 异常路径不清理 */ }
```

异常路径下 `_handle` 保留旧值 → 下次 `_read()` 进来时：

- `_read()` 内部有自愈逻辑：`if (hasStreaming && _handle == null) 把残留 streaming 修成 done`
- 但因为 `_handle != null`，自愈分支永远走不到
- 磁盘 streaming marker 残留 → 必须等 30s watchdog 兜底

### 根因 3：catch 块无 UI 兜底，state 完全不刷新

修复前 catch 块只做"日志上报"，没做任何 `state = ...`：

- 即便 stop 成功，UI 不知道
- 即便 stop 失败，UI 也不知道
- 用户视角：stop_button 卡住 → 整条消息看起来在持续 streaming

### 根因 4（次要）：详细日志被吞

catch 块只 `logger.error(e, st)`，**没有任何控制台 dev.log**。当 logger 自身有问题时，根因完全丢失，定位极困难。

## 解决方案

三层防线，任一层独立失效都能让 stop_button 消失：

### 防线 1：fire-and-forget 错误日志

新增 `_safeLogError` IIFE 包装，确保 logger 永远不阻塞调用方：

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

要点：

- 外层 IIFE 自执行（fire-and-forget）→ 调用方立刻返回
- 内层 try-catch 吞掉 logger 二次异常 → 不会再往上抛
- 即使 logger 自身初始化失败或网络超时，catch 块都不被阻塞

### 防线 2：立即清 `_handle` / `_cancelToken`

把清理挪到 try 块开头（在 `if (_stopRequested) return` 之后、`sessionStore.finishAssistant` 之前）：

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
  } catch (e, st) { /* ...防线 3... */ }
}
```

这样无论 finishAssistant 成功 / 抛错，`_handle` 都已置 null，下次 `_read()` 进来时自愈逻辑必然生效。

### 防线 3：catch 块兜底 `_read()` + dev.log 暴露根因

```dart
} catch (e, st) {
  // 详细日志：暴露 catch 进入的根因（之前被 logger.await 默默吞掉）
  dev.log('[ChatController.onDone] finishAssistant FAILED nodeId=$nodeId', name: 'ChatController');
  dev.log('  error: $e', name: 'ChatController');
  dev.log('  stack: $st', name: 'ChatController');

  // Fire-and-forget logger（避免 logger await 阻塞清理路径）
  _safeLogError(e, st, 'finishAssistant');

  // 兜底刷新 UI：无论 finishAssistant 是否成功，必须让 stop_button 消失。
  // _handle 已置 null → _read() 自愈逻辑生效
  try {
    final readResult = await _read();
    if (_stopRequested) return;
    state = AsyncData(readResult);
  } catch (readError, readSt) {
    dev.log('[ChatController.onDone] _read fallback FAILED: $readError', name: 'ChatController');
    dev.log('  stack: $readSt', name: 'ChatController');
    // 最后兜底：基于现有 state 触发刷新（让 UI 重新评估 stop_button）
    final fallback = state.value ?? const <SessionMessage>[];
    state = AsyncData(fallback);
  }
}
```

要点：

- `dev.log` 永远先打出来，确保即使 logger 失败也能定位
- `_safeLogError` 是 best-effort，不阻塞
- `_read()` 兜底读一次（即使抛错也会触发自愈逻辑）
- 最后 `state = AsyncData(fallback)` 用现有 state 触发刷新——**保证 stop_button 至少评估一次**

## 验证

### 静态检查

- `flutter analyze` 无错（无新增 warning）
- diff 文件数：1 个（`lib/ui/features/chat/chat_controller.dart`，+47 行）

### 集成测试

现有 `integration_test/chat_streaming_test.dart` 覆盖 stop 路径（点 stop → 验证 stop_button 消失 + 消息状态为 done）。本次修复前会偶发失败（watchdog 30s 后才恢复），修复后稳定通过。

### 手工验证（4 类场景）

| 场景 | 期望 | 修复前 | 修复后 |
|------|------|--------|--------|
| 正常 stop | 200ms 内 stop_button 消失 | ✅ | ✅ |
| stop 后立即追问 | 新消息正常发送 | ✅ | ✅ |
| stop 时 finishAssistant 抛错（构造 unique violation） | 1s 内 stop_button 消失 + 控制台 dev.log 可见 | ❌ 30s 后才消失 | ✅ |
| stop 时 logger 远端不可达 | 同上 | ❌ 30s 后才消失 | ✅ |

### 关键代码（chat_controller.dart）

完整 diff 47 行，主要包含：

1. 新增 `_safeLogError` 私有方法（14 行）
2. `onDone` 回调重写：`_handle` 提前清 + catch 块双层 try + dev.log（33 行）

## 相关文件

- `lib/ui/features/chat/chat_controller.dart` — 修改，`_safeLogError` + `onDone` 三层防线

## 参考链接

- [CHANGELOG/2026-06-20-stop-button-stuck.md](../CHANGELOG/2026-06-20-stop-button-stuck.md) — 本次修复的 changelog
- [ARCHITECTURE.md](../ARCHITECTURE.md) — `AsyncNotifier + SSE` 清理路径的设计约定
- `tools/fix_stale_streaming.py` — 30s watchdog 兜底脚本（修复后理论上不再触发，作为最后防线保留）

## 复盘

### 为什么一开始没发现

1. **正常 stop 路径完全正常** —— 只有当 `sessionStore.finishAssistant` 抛错（SQLite 锁、unique violation、磁盘满等）时才会卡死。生产环境磁盘正常、网络稳定时几乎不触发
2. **watchdog 30s 后能兜底** —— 表现为"stop 卡一下"，不会永久卡住，初版以为可接受
3. **catch 块日志被 logger.await 吞掉** —— 看不到根因，无法定位"是哪一层卡住"
4. **集成测试覆盖的是 happy path** —— 没有构造异常 finishAssistant 的测试场景

### 以后如何避免同类问题

1. **所有 `AsyncNotifier` 的 catch 块必须非阻塞** —— 不要 `await logger.error`，统一走 `_safeLogError`（或其他 fire-and-forget 包装）
2. **清理路径必须先清理再 try** —— `_handle = null` 这种"清完才能让自愈逻辑生效"的语句不能放在 try 末尾
3. **catch 块必须有 UI 兜底** —— `state = AsyncData(...)` 不能省，否则用户看不到反馈
4. **catch 块先 `dev.log` 再上报** —— `dev.log` 是 dart:developer，无依赖、必成功；远端 logger 是 best-effort
5. **集成测试要构造异常路径** —— happy path 通过不代表异常路径稳定，构造 unique violation / 网络失败 / 磁盘满的端到端用例
6. **保留 watchdog 兜底但要告警** —— watchdog 不该"静默兜底"，应触发告警/统计，便于发现"主路径已坏"

### 模式总结：`AsyncNotifier + 流式回调`的清理路径铁律

适用于所有 `AsyncNotifier` + SSE / WebSocket / 长连接场景的 onDone / onError 回调：

1. **立即清状态**（`_handle = null` 等）—— 在 try 开头，不要依赖 try 末尾
2. **catch 块非阻塞**（fire-and-forget logger）—— 不允许 `await logger.error`
3. **catch 块必刷新 state**（`_read()` 兜底 + AsyncData 兜底）—— 保证 UI 至少评估一次
4. **catch 块先 dev.log** —— 暴露根因，不被 logger 吃掉
5. **集成测试要构造异常 finishAssistant** —— happy path 通过不代表生产稳定

这个模式可推广到：

- `ChatController.onError`（当前未实现，同类风险）
- 未来的 WebSocket controller（同样有 onDone / onError）
- 任何"流式回调 → 同步状态"的场景