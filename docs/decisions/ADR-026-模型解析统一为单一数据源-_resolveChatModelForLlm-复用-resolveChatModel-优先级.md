## ADR-026: 模型解析统一为单一数据源——`_resolveChatModelForLlm` 复用 `resolveChatModel` 优先级

2026-07-08 决定。title bar 显示的模型与 LLM 实际调用的模型不一致——根因是显示侧（`resolveChatModel`，4 级优先级）和调用侧（`_triggerLlmStream` / `_triggerAssistantReply` / `_currentModelSupportsVision` 各自内嵌，仅 2 级）是两套独立逻辑。空白分支场景 100% 命中：新 session 无模型时，显示侧走 lastUsedChat → chatDefault 显示全局默认，调用侧跳过这两级直接走自己的兜底用另一个 provider。详见 [war-stories/flutter/2026-07-08-titlebar-model-mismatch-dual-fallback.md](war-stories/flutter/2026-07-08-titlebar-model-mismatch-dual-fallback.md)。

决策：在 `ChatController` 新增 `_resolveChatModelForLlm()` 作为调用侧统一入口，复用 `resolveChatModel` 的 1-3 级优先级（session → lastUsedChat → chatDefault），自行做第 4 级兜底（第一个有 apiKey + model 的 provider）。三处调用点（`_triggerAssistantReply` / `_triggerLlmStream` / `_currentModelSupportsVision`）删掉各自内嵌的 if/fallback 分支，统一调 `_resolveChatModelForLlm`。

关键设计：**不传 `providers` 给 `resolveChatModel`**（只用 1-3 级），由 `_resolveChatModelForLlm` 自行做第 4 级。`resolveChatModel` 是同步函数，第 4 级兜底无法查 apiKey（不能 await）；若传 providers，1-3 级解析出模型但验证失败时会静默降级到第 4 级（可能选了没 key 的 provider）。不传 providers 意味着 1-3 级验证失败返回 null，让调用方报错提示用户手动切换——"显示了一个模型但调用报错"比"显示 A 实际用 B"更安全，因为前者用户能看到错误并主动处理，后者用户完全无感知。

这个设计接受一个极端场景的残余不一致：当 1-3 级全部落空（无 session 模型 + 无 lastUsedChat + 无 chatDefault）时，`resolveChatModel` 的显示侧第 4 级可能选一个没 key 的 provider（不查 key），而 `_resolveChatModelForLlm` 的第 4 级会跳过它选另一个有 key 的。但这种场景在正常使用中极少出现（用户至少配过一个全局默认或用过一次聊天），且根本问题（跳过 2/3 级）已解决，残余不一致只影响"一个 provider 都没配 key"的边界态。

影响范围：`lib/ui/features/chat/chat_controller.dart`（新增 `_resolveChatModelForLlm` :355-412 + 三处调用重写，净减 ~90 行）。`lib/ui/core/shared/llm_setup_check.dart` 的 `resolveChatModel` 未改动——它保持同步签名（chat_screen build 中同步调用，5 个现有调用方不受影响），只是调用侧不再传 `providers` 参数以禁用其第 4 级。

实施要点：`resolveChatModel` 的 `providers` 参数是可选的——传 null 时第 4 级兜底不执行（返回空串），调用侧自行处理。**不要**把 `resolveChatModel` 改成 async——它在 `chat_screen.dart` build 方法中同步调用，改 async 会破坏 5 个调用方。`_resolveChatModelForLlm` 返回 null 时，调用方必须给出明确的错误提示（如"[未配置 API Key]"或"[提供商未找到]"），不能静默返回。新增 fallback 级别时，`resolveChatModel` 和 `_resolveChatModelForLlm` 必须同步更新——这是"同一概念两条数据流"的硬约束。
