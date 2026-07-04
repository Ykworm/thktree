# Chat 模块

> ⚠️ **AI 改模块前必读**
> 1. **SSE 流式是核心体验**——事件顺序/心跳/`[DONE]` 终止/错误重连都在 `ChatController` + `LlmApiClient`；不要在 widget 里裸用 `http.Client`。
> 2. **节点作用域**——对话只挂在某个 `Node.id` 下，换节点要重建 controller；别跨节点共享消息流。
> 3. **Provider 解耦**——`ChatScreen` 只读 `chatControllerProvider(family: nodeId)`，不要传 controller 实例；交由 Riverpod 生命周期管。
> 4. **分层：UI 同步层 vs 服务层**——`ChatController` 只负责 watch Riverpod state 与绑定 Widget；**后台中断恢复 / 串行重发 / bridge.begin-end 包裹** 在 `ChatTaskService`（`lib/data/services/chat_task_service.dart`）里。续传/重发决策**不下沉到 widget**。变更前必读 [ADR-015](../../DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界)。
> 5. **标题自动建议**（`TitleSuggestionService`）的触发时机未决策，**别预设自动调用**，要加问用户。
> 6. **空白分支自动 title 持久化靠 `AutoTitleController` + `ref.keepAlive()`**（2026-06-29）—— 空白分支 chat 流式结束后，title 生成、DB 写、tree refresh 全在 Notifier 内执行，与 widget 生命周期完全解耦。**禁止把 title 生成任务重新绑回 widget**（user pop 后 task 会跟着 dispose，DB 不写 + tree 不刷；详见 [ADR-018](../../DECISIONS.md#adr-018-Notifier-后台任务保活autoDispose--build-内-refkeepalive-双标记范式) + [war-story](../../war-stories/flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md)）。改了 `autoDispose` 范式前先查下面 "关键设计原则"里的 双标记范式说明。

## 职责

对话模块。承载 LLM 多轮对话的完整交互：消息流渲染、流式响应、模型选择、消息编辑/重试、笔记→对话的自动续聊、iOS 后台中断恢复。

## 功能列表

- 流式对话（SSE）：打字机效果逐字渲染 LLM 回复
- 多消息分支：单节点内可编辑/重试生成新回复
- 模型选择：对话页内切换 LLM（panel 抽屉）
- 自动续聊：从笔记节点跳入对话时，自动用笔记内容作为上下文发起新对话
- 消息编辑：编辑用户消息后重发，仅影响当前节点
- 消息复制：长按复制单条消息
- **空白分支自动 title 持久化**（2026-06-29）：空白分支（A 模式）chat 流式结束后由 `AutoTitleController`（`lib/ui/features/chat/auto_title_controller.dart`，按 `nodeId` family）自动 LLM 生成 title 并写入 DB + refresh tree；`ref.keepAlive()` 保活，user 提前 pop 也能后台跑完（详见 [ADR-018](../../DECISIONS.md#adr-018-Notifier-后台任务保活autoDispose--build-内-refkeepalive-双标记范式)）
- iOS 后台中断恢复：App 切后台时 `beginBackgroundTask` 续命 30s；切回扫描磁盘 `<!-- streaming -->` 标记触发自动重发，串行排队（仅 iOS，详见 [ADR-015](../../DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界)）
- 联网搜索开关（`ChatComposer`）：输入框区域新增联网搜索按钮，位于模型选择器和发送按钮之间
  - 参数：`webSearchEnabled`（bool，当前开关状态）、`webSearchSupported`（bool，当前模型是否支持）、`onWebSearchToggle`（VoidCallback?，null 时不显示按钮）
  - 图标：地球图标，开启时蓝色、关闭时灰色；不支持时灰色不可点击，tooltip 提示"当前模型不支持联网搜索"
- 图片上传（`ChatComposer`，2026-07-05）：输入框底部图片按钮，支持的模型显示蓝色图标+文字，不支持变灰不可点击
  - 参数：`onImagePick`（VoidCallback?，null 时不显示）、`imageSupported`（bool，模型是否支持 vision）、`selectedImageData`/`selectedImageMimeType`（已选图片）
  - 点击弹出 CupertinoActionSheet：拍照（`ImageSource.camera`）/ 从相册选择（`ImageSource.gallery`）
  - 选中后输入框上方显示 80x80 缩略图预览条（`_ImagePreview`），支持移除
  - 发送时 `imageData`/`imageMimeType` 随消息传入 `ChatController.sendUserMessage` → `ChatTaskService.startTask` → `_buildMessages` 构建多模态 content（base64 `image_url`）
  - 模型 vision 能力自动检测：`ModelCapability.vision` + `model_capabilities.dart` 推断（gpt-4o / claude-3 / gemini / kimi-k2.5 / mimo-v2.5 等）
  - iOS 权限：`NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription`
- 消息时间戳（2026-07-04）：assistant 消息气泡上方显示人类可读时间，`formatMessageTime` 支持 4 级格式（今天 `HH:mm` / 昨天 / 月日 / 跨年全日期）
- Chat-to-Note（2026-07-04）：assistant 消息"存为笔记"按钮（`MessageBubble.onSaveToNote` 回调），自动用当前主题创建笔记并跳转 `NoteEditorScreen`

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
| `lib/ui/core/shared/chat_composer.dart` | 底部输入框（文本输入 + 发送/停止 + 模型选择 + 联网搜索开关 + 图片按钮 + 图片预览） | - |
| `lib/ui/core/shared/message_bubble.dart` | 消息气泡（user + assistant，GptMarkdown 渲染 + LaTeX 注入 + 每张表格独立工具栏：复制/全屏按钮） | 388 |
| `lib/ui/core/shared/markdown_builders.dart` | GptMarkdown 自定义构建器（含 `buildLatex`——`FittedBox(scaleDown)` 包裹 `Math.tex`） | 61 |
| `lib/ui/features/chat/auto_title_controller.dart` | 空白分支流式结束后后台补 title：3 次重试（指数退避 1s/2s/4s）+ 调 LLM + 写 DB + refresh tree；`ref.keepAlive()` 保活（2026-06-29 新增） | 新增 |
| `integration_test/chat_async_recovery_test.dart` | 后台中断恢复集成测试（4 个 testWidgets：findInterrupted / resumeInterrupted / cancelResumeQueue / bridge.begin-end 配对） | 新增 |

## 子文档

- 集成测试 — 对话流式（含流式边界用例 / 空消息 / 快速连续发送）：[docs/_shared/integration-testing/chat-streaming.md](../../_shared/integration-testing/chat-streaming.md)
- 集成测试 — 空白分支自动 title 持久化（case 9.4 DB check / 9.5 空白 E2E / 9.6 提前 pop 后台完成，归属 [branch-creation 测试矩阵](../../_shared/integration-testing/branch-creation.md) § 3.5，2026-06-29）：[docs/_shared/integration-testing/branch-creation.md](../../_shared/integration-testing/branch-creation.md)
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
- **autoDispose + keepAlive 双标记范式**（2026-06-29）：任何"与 widget 生命周期无关、需后台跑完任务"的 Notifier，用 `AsyncNotifierProvider.autoDispose.family<...>` + `build()` 内调 `ref.keepAlive()`。只走 `autoDispose` 不行——widget unmount 时 Notifier 被 dispose，正在跑的 Future 被取消。`keepAlive()` 不是替代 autoDispose，而是补充："我声明自己保持 alive"。适用对象：`AutoTitleController` 类后台任务 Notifier。**不适用对象**：UI 同步层 controller（`ChatController`）、树形数据 controller（`ThemeDetailController`）——它们应当进入时构造、离开时销毁。详见 [ADR-018](../../DECISIONS.md#adr-018-Notifier-后台任务保活autoDispose--build-内-refkeepalive-双标记范式)。
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
- 2026-06-29：`AutoTitleController` 上线（`lib/ui/features/chat/auto_title_controller.dart`，246 行）—— 空白分支流式结束后自动 LLM 补 title 并持久化，与 widget 生命周期解耦（`ref.keepAlive()`），user 提前 back 回 tree 也能后台完成。3 层守卫防 LLM 覆盖手动 title。集成测试 case 9.4 (DB check) / 9.5 (E2E) / 9.6 (提前 pop 后台完成) 加到 [branch-creation](../../_shared/integration-testing/branch-creation.md) § 3.5。详见 [ADR-018](../../DECISIONS.md#adr-018-Notifier-后台任务保活autoDispose--build-内-refkeepalive-双标记范式) + [war-story](../../war-stories/flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md) + [CHANGELOG/2026-06-29](../../CHANGELOG/2026-06-29-auto-title-persistence.md)。
