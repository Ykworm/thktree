## ADR-023: `retryLastMessage` 重构——避免重发重复追加 user 消息

2026-07-06 决定。`ChatController.retryLastMessage()` 本意是"删除最后一条 assistant 消息并重新触发 LLM"，但实现里它直接 `await sendUserMessage(userMessage)`——而 `sendUserMessage` 是"新消息入口"，会乐观追加 user 消息到 state 并 `sessionStore.appendUserMessage(...)` 写盘。结果是：每次点重发按钮，用户同名同内容的 user 消息在 session.md 和 in-memory state 里都被复制一份。UI 上看是"同一句问题发了 N 次"，搜索关键词（关键词榜分析）和文档链接（每条 user msg 都贡献一个 msgId）都受污染。

决策：把 `sendUserMessage` 里的"判断 provider + 读 apiKey + fallback + `_startStreamingWithConfig`"逻辑抽出来成 `_triggerLlmStream({required messagesForLlm, imageData, imageMimeType})` helper。`sendUserMessage` 先 append user + 写盘再调 helper；`retryLastMessage` 先 `removeLastAssistantMessage` + reload state 再调 helper（**不再 append user**）。retry 路径不重新生成 user msg 的 `timestamp` 也不重新分配 `msgId`——这意味着 user 的 msgId 保持稳定，向后兼容：旧功能（搜索命中、引用、关键词榜 stale 判定、NoteStore 链源）都依赖 user msgId 不变的语义。

影响范围：`lib/ui/features/chat/chat_controller.dart`（refactor `sendUserMessage` + `retryLastMessage` + 新增 `_triggerLlmStream` 私有方法）。回归测：发一条 → 等回复完成 → 点重发 → 看 session.md user 消息条数应保持不变（之前每次 +1）。

放弃方案：给 `sendUserMessage` 加 `existingUserMsgId` 参数判断"已存在就不 append"——但这把"是否新消息"的认知负担推到调用方，且 retry 与新发两条路径不一致更难懂；不如用 helper 抽出"哪些步骤共享 / 哪些步骤调用方自己负责"。
