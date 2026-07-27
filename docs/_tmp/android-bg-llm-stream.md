# android-bg-llm-stream

> 状态：implementing
> 更新：2026-07-27
> 模式：litemode
> worktree：`../ThkTree-worktrees/android-bg-llm-stream`
> 分支：`ThkTree/android-bg-llm-stream`

## 1. 问题

ThkTree Chat 在 LLM 流式生成时切后台：

| 平台 | 现状 | 用户感知 |
|------|------|----------|
| iOS | `beginBackgroundTask` ~30s + `resumeInterrupted` 自动重发 | 短回复可续；长回复 partial 被删重打 |
| Android | 无保活；`resumeInterrupted` 被 `Platform.isIOS` 挡住 | isolate 挂起 → SSE 断；回前台可能把 partial **静默标成 done** |

核心缺口：

1. Android 无 Foreground Service，无法在后台继续收 SSE。
2. 磁盘有 `<!-- streaming -->` 但无 active task 时，`_read()` 内存自愈把状态改成 `done`（用户误以为完整）。
3. iOS `resumeInterrupted` → `retryLastMessage` 会删掉 partial 整段重打。
4. l10n 已有 `networkInterrupted`，UI 未接。

## 2. 目标（一句话）

**Android 用 FGS 尽量收完流；双端统一 `interrupted` 语义——保留 partial、显式标未完成、用户决定重试。**

## 3. 非目标

- WorkManager 接 SSE
- SSE 下沉 Kotlin/OkHttp
- Lab / title suggestion 等短任务保活
- 「继续生成」（续写 partial）— 后续专项
- Play 上架素材

## 4. 方案摘要

### 4.1 Android Foreground Service

- 扩展 `BackgroundTaskBridge`：Android 走同一 MethodChannel `thktree/background_task`
- **`startTask` 时立即 `begin()`**（满足 Android 12+ 前台启动 FGS 约束）
- 低打扰通知：「正在生成回复…」；点击 deep link 回 chat
- **`begin/end` 引用计数**：多 node 并发流时，最后一个结束才 stop FGS

### 4.2 `interrupted` 状态（双端）

- 新增 `SessionMessageStatus.interrupted`
- 磁盘 marker：`<!-- interrupted -->`（与 `streaming` / `error` 并列）
- 中断且有可读 partial → `interruptAssistant()` 保留 body + 写 marker
- partial 几乎为空（`< 32` 字符 trim 后）→ 仍可自动 retry（与 ADR-016 短中断一致）

### 4.3 恢复策略调整（相对 ADR-016）

| 条件 | 旧行为 | 新行为 |
|------|--------|--------|
| 有 partial + 流已死 | iOS：删 assistant 重发 | 标 `interrupted`，UI 提示 + 手动重试 |
| 无 partial + 流已死 | 自动重发 | 不变：自动 retry |
| 流仍活（FGS/30s 内） | 无缝续 | 不变 |

ADR-016 仍有效于「空 partial 自动重发」；**有内容时不再 silent retry**。

### 4.4 `_read()` 自愈修正

- 禁止把 orphan `streaming` 静默映射为 `done`
- 无 active task 的 `streaming` → 解析为 `interrupted`（或触发 `interruptAssistant` 落盘）

## 5. 文件触达面（预估）

| 层 | 文件 |
|----|------|
| Dart 模型 | `session_markdown.dart`, `session_store.dart` |
| 调度 | `chat_task_service.dart`, `background_task_bridge.dart`, `chat_controller.dart` |
| UI | `message_bubble.dart`, `app_en.arb`, `app_zh.arb` |
| Android | `LlmStreamForegroundService.kt`, `BackgroundTaskPlugin.kt`, `MainActivity.kt`, `AndroidManifest.xml` |
| iOS | `BackgroundTaskHandler.swift`（引用计数） |
| 测试 | `test/session_markdown_interrupted_test.dart`, `test/background_task_bridge_test.dart`, `test/chat_task_service_interrupted_test.dart` |
| 文档 | ADR-017 草案、`storage-format.md` §4.4 增补 |

## 6. 验收

- [ ] Android：发消息后切后台 60s+，回前台见完整回复或 `interrupted` 气泡（非 silent done）
- [ ] Android：通知栏在流期间可见，结束后消失
- [ ] 双端：partial 中断显示「回复未完成」+ 重试按钮
- [ ] 双端：空 partial 仍自动 retry
- [ ] `flutter test` 新增用例全绿；`flutter analyze` 无新增 error

## 7. 风险

- 国产 ROM 仍可能杀 FGS → `interrupted` 兜底必需
- ADR-016 行为变更需在新 ADR 中说明「有 partial 不自动重发」
- `findInterrupted` 需同时识别 `streaming`（进程刚杀）与 `interrupted`（已落盘）

## 8. 关联

- [ADR-016](../decisions/ADR-016-iOS-LLM-流式中断恢复策略-disk-first-自动重发-30s-边界.md)
- [cross-platform-android-enablement.md](./cross-platform-android-enablement.md) C2 后续项
- 实现计划：`docs/superpowers/plans/2026-07-27-android-bg-llm-stream.md`
