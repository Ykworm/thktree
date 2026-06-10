# Chat 模块

> ⚠️ **AI 改模块前必读**
> 1. **SSE 流式是核心体验**——事件顺序/心跳/`[DONE]` 终止/错误重连都在 `ChatController` + `LlmApiClient`；不要在 widget 里裸用 `http.Client`。
> 2. **节点作用域**——对话只挂在某个 `Node.id` 下，换节点要重建 controller；别跨节点共享消息流。
> 3. **Provider 解耦**——`ChatScreen` 只读 `chatControllerProvider(family: nodeId)`，不要传 controller 实例；交由 Riverpod 生命周期管。
> 4. **标题自动建议**（`TitleSuggestionService`）的触发时机未决策，**别预设自动调用**，要加问用户。

## 职责

对话模块。承载 LLM 多轮对话的完整交互：消息流渲染、流式响应、模型选择、消息编辑/重试、笔记→对话的自动续聊。

## 功能列表

- 流式对话（SSE）：打字机效果逐字渲染 LLM 回复
- 多消息分支：单节点内可编辑/重试生成新回复
- 模型选择：对话页内切换 LLM（panel 抽屉）
- 自动续聊：从笔记节点跳入对话时，自动用笔记内容作为上下文发起新对话
- 消息编辑：编辑用户消息后重发，仅影响当前节点
- 消息复制：长按复制单条消息

## 代码文件

| 文件 | 角色 | 行数 |
|------|------|------|
| `lib/ui/features/chat/chat_screen.dart` | 对话页主屏幕（消息列表 + 输入框） | 419 |
| `lib/ui/features/chat/chat_controller.dart` | 状态机：消息流、发送/重试/取消、模型切换 | 555 |
| `lib/ui/features/chat/chat_screen_launch_params.dart` | 启动参数（autoTriggerReply 等） | 16 |
| `lib/ui/features/chat/widgets/model_selector_panel.dart` | 模型选择抽屉 | - |

## 子文档

本模块暂无子文档。

## 关键设计原则

- **流式优先**：所有 LLM 调用走 SSE，UI 不阻塞；失败可重试且断点续传
- **节点作用域**：消息编辑/重试只影响当前节点，不污染父节点（参考 storage-format 双向链）
- **autoTriggerReply 启动参数**：笔记详情跳对话时携带笔记内容，controller 初始化时自动发起一轮
- **Provider 解耦**：模型配置由 LLM 模块提供，chat 模块只读不写
- **聊天记录持久化**：通过 ChatRepository（domain 层）写入 SQLite，会话元数据 + 消息按节点 ID 索引

## 维护要点

- 改 chat_screen 布局前必读 [notes 模块 README](../notes/README.md)，两者 UI 风格共用 Large Title + slivers
- 新增 LLM provider 时，模型选择 panel 会自动出现（无需改 chat 代码），但要在 llm 模块注册 provider
- 流式断网/超时处理：参考 `integration_test/chat_streaming_test.dart` 的边界用例
- 注意 `autoTriggerReply` 启动参数与 notes 模块的"从笔记续聊"按钮联动

## 相关历史

- 2026-05：聊天流式响应首次落地（SSE + Riverpod AsyncNotifier）
- 2026-05：模型选择 panel 加入，支持运行期切换
- 2026-05：与笔记模块打通双向跳转（笔记→自动续聊、对话→引用笔记）
- 2026-06：消息编辑/重试功能上线
