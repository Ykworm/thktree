# Assistant 消息气泡显示 LLM 模型名

> 日期：2026-07-06

## 变更内容

- assistant 消息气泡标题从 `助手` 改为 `助手 · <模型名>`（如 `助手 · gpt-4o`），streaming 时显示 `助手 · gpt-4o · streaming`
- `SessionMessage` 新增可选 `modelId` 字段（仅 assistant 消息）
- `session.md` 消息头格式扩展：`## assistant · <timestamp> · <msgId> · <modelId>`（`modelId` 可选，向后兼容旧消息无此字段）
- `MessageBubble` 从 `llmProvidersProvider` 查模型显示名；找不到时兜底显示 modelId 原始值

## 技术实现

- `session_markdown.dart`：`SessionMessage` 新增 `modelId`；`_messageHeader` regex 扩展为 `(?: · (.+))?`；`formatMessageHeader` 新增可选 `modelId` 参数；`_parseMessages` 提取 group(4) 写入消息
- `session_store.dart`：`beginAssistantMessage` 新增 `modelId` 参数；`_rebuildSessionMarkdown` 序列化时传递 `msg.modelId`
- `chat_task_service.dart`：调用 `beginAssistantMessage` 时传入 `modelId: model`
- `message_bubble.dart`：build 方法中从 `llmProvidersProvider` 遍历 providers.models 查找 modelId 对应的显示名

## 改动文件

- lib/data/services/session_markdown.dart（SessionMessage 模型 + 解析）
- lib/data/stores/session_store.dart（beginAssistantMessage + rebuild）
- lib/data/services/chat_task_service.dart（传 model 到 beginAssistantMessage）
- lib/ui/core/shared/message_bubble.dart（UI 展示模型名）
- docs/_shared/storage-format.md（§ 4.3 消息头格式更新 + § 4.6 示例更新）
- docs/modules/chat/README.md（功能列表 + 历史时间线）
