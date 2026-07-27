## ADR-029: Android Chat 流式 FGS 与 interrupted partial 语义

2026-07-27 决定。Android 切后台时 Dart isolate 会被挂起，Dio SSE 中断；iOS 仅有 ~30s `beginBackgroundTask` 窗口。双端需统一「partial 保留 + 显式未完成」语义，避免用户把截断回复当作完整答案。

背景：[`BackgroundTaskBridge`](../../lib/data/services/background_task_bridge.dart) 原先仅 iOS 生效；[`ChatController._read`](../../lib/ui/features/chat/chat_controller.dart) 会把 orphan `streaming` 静默映射为 `done`；[`resumeInterrupted`](../../lib/data/services/chat_task_service.dart) 对有内容的 partial 会 `retryLastMessage` 整段重打。Android 启用文档见 [`docs/_tmp/android-bg-llm-stream.md`](../_tmp/android-bg-llm-stream.md)。

决策：

1. **Android Foreground Service（dataSync）** — Chat 流 [`startTask`](../../lib/data/services/chat_task_service.dart) 开始时立即 `BackgroundTaskBridge.begin()`，低打扰通知「正在生成回复…」，末流 `end()` 后移除。不绑 Lab / title suggestion 等短任务。
2. **Bridge 引用计数** — Dart + iOS + Android 三端：`0→1` 启原生保活，`1→0` 释放；支持多 node 并发流。
3. **`interrupted` 终态** — 磁盘 `<!-- interrupted -->`；[`SessionMessageStatus.interrupted`](../../lib/data/services/session_markdown.dart)；UI 显示「回复未完成」+ 重试。保留 body，不假装 `done`。
4. **恢复分层** — `findInterrupted()` 仍只扫 `<!-- streaming -->`。partial ≥ 32 字符 → `interruptAssistant`；否则沿用 [ADR-016](ADR-016-iOS-LLM-流式中断恢复策略-disk-first-自动重发-30s-边界.md) 自动 retry。有 partial 时**不** silent 重打。

相对 ADR-016：空 partial 自动重发不变；**有 partial 时从「删 assistant 重发」改为 interrupted 终态**，需用户点重试。

放弃：WorkManager 接 SSE；SSE 下沉 Kotlin；「继续生成」（续写 partial）留后续专项。

影响：`android/.../LlmStreamForegroundService.kt`、`BackgroundTaskPlugin.kt`、`session_markdown.dart`、`session_store.dart`、`chat_task_service.dart`、`chat_controller.dart`、`message_bubble.dart`、`BackgroundTaskHandler.swift`（refcount）。
