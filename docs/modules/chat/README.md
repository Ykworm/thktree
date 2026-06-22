# Chat 模块

> ⚠️ **AI 改模块前必读**
> 1. **SSE 流式是核心体验**——事件顺序/心跳/`[DONE]` 终止/错误重连都在 `ChatController` + `LlmApiClient`；不要在 widget 里裸用 `http.Client`。
> 2. **节点作用域**——对话只挂在某个 `Node.id` 下，换节点要重建 controller；别跨节点共享消息流。
> 3. **Provider 解耦**——`ChatScreen` 只读 `chatControllerProvider(family: nodeId)`，不要传 controller 实例；交由 Riverpod 生命周期管。
> 4. **分层：UI 同步层 vs 服务层**——`ChatController` 只负责 watch Riverpod state 与绑定 Widget；**后台中断恢复 / 串行重发 / bridge.begin-end 包裹** 在 `ChatTaskService`（`lib/data/services/chat_task_service.dart`）里。续传/重发决策**不下沉到 widget**。变更前必读 [ADR-015](../../DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界)。
> 5. **标题自动建议**（`TitleSuggestionService`）的触发时机未决策，**别预设自动调用**，要加问用户。

## 职责

对话模块。承载 LLM 多轮对话的完整交互：消息流渲染、流式响应、模型选择、消息编辑/重试、笔记→对话的自动续聊、iOS 后台中断恢复。

## 功能列表

- 流式对话（SSE）：打字机效果逐字渲染 LLM 回复
- 多消息分支：单节点内可编辑/重试生成新回复
- 模型选择：对话页内切换 LLM（panel 抽屉）
- 自动续聊：从笔记节点跳入对话时，自动用笔记内容作为上下文发起新对话
- 消息编辑：编辑用户消息后重发，仅影响当前节点
- 消息复制：长按复制单条消息
- iOS 后台中断恢复：App 切后台时 `beginBackgroundTask` 续命 30s；切回扫描磁盘 `<!-- streaming -->` 标记触发自动重发，串行排队（仅 iOS，详见 [ADR-015](../../DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界)）

## 代码文件

| 文件 | 角色 | 行数 |
|------|------|------|
| `lib/ui/features/chat/chat_screen.dart` | 对话页主屏幕（消息列表 + 输入框） | 419 |
| `lib/ui/features/chat/chat_controller.dart` | UI 同步层 StateNotifier：watch Riverpod state / 绑定 Widget / 发送触发委托给 ChatTaskService | 重构后缩减 |
| `lib/ui/features/chat/chat_screen_launch_params.dart` | 启动参数（autoTriggerReply 等） | 16 |
| `lib/ui/features/chat/widgets/model_selector_panel.dart` | 模型选择抽屉 | - |
| `lib/data/services/chat_task_service.dart` | 服务层调度器：串行重发 queue + generation token + bridge.begin/end 包裹 + resumeInterrupted / cancelResumeQueue 入口 | 新增 |
| `lib/data/services/background_task_bridge.dart` | iOS `beginBackgroundTask` MethodChannel 客户端（`begin()` / `end(taskId)`），可注入 | 新增 |
| `ios/Runner/BackgroundTaskHandler.swift` | Swift MethodChannel handler + `UIApplication.beginBackgroundTask` 调用 + `expirationHandler` 释放 | 新增 |
| `lib/ui/core/shared/message_bubble.dart` | 消息气泡（user + assistant，GptMarkdown 渲染 + LaTeX 注入） | 388 |
| `lib/ui/core/shared/markdown_builders.dart` | GptMarkdown 自定义构建器（含 `buildLatex`——`FittedBox(scaleDown)` 包裹 `Math.tex`） | 61 |
| `integration_test/chat_async_recovery_test.dart` | 后台中断恢复集成测试（4 个 testWidgets：findInterrupted / resumeInterrupted / cancelResumeQueue / bridge.begin-end 配对） | 新增 |

## 子文档

- 集成测试 — 对话流式（含流式边界用例 / 空消息 / 快速连续发送）：[docs/_shared/integration-testing/chat-streaming.md](../../_shared/integration-testing/chat-streaming.md)
- 集成测试 — 后台中断恢复（iOS only，ChatTaskService + BackgroundTaskBridge）：[docs/_shared/integration-testing/chat-async-recovery.md](../../_shared/integration-testing/chat-async-recovery.md)
- 集成测试总论 / fixtures / helpers：[docs/_shared/integration-testing/README.md](../../_shared/integration-testing/README.md)

## 关键设计原则

- **流式优先**：所有 LLM 调用走 SSE，UI 不阻塞；失败可重试且断点续传
- **节点作用域**：消息编辑/重试只影响当前节点，不污染父节点（参考 storage-format 双向链）
- **autoTriggerReply 启动参数**：笔记详情跳对话时携带笔记内容，controller 初始化时自动发起一轮
- **Provider 解耦**：模型配置由 LLM 模块提供，chat 模块只读不写
- **聊天记录持久化**：通过 ChatRepository（domain 层）写入 SQLite，会话元数据 + 消息按节点 ID 索引
- **分层：UI 同步层 vs 服务层**：`ChatController` 只负责 watch Riverpod state / 绑定 Widget；后台中断恢复（串行重发 / bridge.begin-end 包裹 / generation token）在 `ChatTaskService` 里。续传/重发决策**不下沉到 widget**。
- **disk-first 中断恢复**：磁盘 `session.md` 的 `<!-- streaming -->` 标记是中断判定唯一真相源。`SessionStore.findInterrupted()` 扫描 → `ChatTaskService.resumeInterrupted()` 入队 → 串行重发。`ChatTaskService` 不自维护"中断状态"。
- **30s 边界**：短回复（< 30s）由 iOS `beginBackgroundTask` 真在后台跑完、切回时流仍存活 → 无缝接续渲染；长回复（≥ 30s）iOS 挂起 process、流被冻 → 检测到流已关闭 → 自动重发。**桥接可注入**（`BackgroundTaskBridge` 可 override，test 用 `_CountingBridge` 计数验证 begin/end 配对）。
- **串行排队**：切回时扫到 N 个未完成 → 一次 1 个重发，跑完/失败/用户停止 才下一个。`generation` token 自增保证 cancel 后正在跑的任务能被 loop 退出条件识别。

## 维护要点

- 改 chat_screen 布局前必读 [notes 模块 README](../notes/README.md)，两者 UI 风格共用 Large Title + slivers
- 新增 LLM provider 时，模型选择 panel 会自动出现（无需改 chat 代码），但要在 llm 模块注册 provider
- 流式断网/超时处理：参考 `integration_test/chat_streaming_test.dart` 的边界用例
- 注意 `autoTriggerReply` 启动参数与 notes 模块的"从笔记续聊"按钮联动
- **LaTeX 公式渲染**：assistant 消息走 `lib/ui/core/shared/markdown_builders.dart` 的 `buildLatex`（`SelectableAdapter` + `Math.tex` + `FittedBox(scaleDown)`，解决 `flutter_math_fork 0.7.4` 的 `RenderLine` 溢出）。其他 4 处 `GptMarkdown` 调用（`lib/main.dart`、`lib/ui/features/notes/note_detail_screen.dart`、`lib/ui/core/shared/share_card_widget.dart`、`lib/ui/features/settings/tts_player_screen.dart`）暂未注入 `latexBuilder`，新增 LaTeX 上下文时需主动复测。详见 [war-story](../../war-stories/ui-ux/2026-06-18-gptmarkdown-latex-renderline-overflow.md) 与 [CHANGELOG/2026-06-18](../../CHANGELOG/2026-06-18-latex-overflow-fix.md)。

## 相关历史

- 2026-05：聊天流式响应首次落地（SSE + Riverpod AsyncNotifier）
- 2026-05：模型选择 panel 加入，支持运行期切换
- 2026-05：与笔记模块打通双向跳转（笔记→自动续聊、对话→引用笔记）
- 2026-06：消息编辑/重试功能上线
- 2026-06-22：`ChatController` 重构为 UI 同步层（移除流式状态机）+ `ChatTaskService` 服务层承担后台中断恢复（iOS only）——参见 [ADR-015](../../DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界) + [集成测试 spec](../../_shared/integration-testing/chat-async-recovery.md)
