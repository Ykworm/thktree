## ADR-022: Per-session 深度思考开关 + 双 `ModelCapability` 区分

2026-07-06 决定。用户对 LLM 思考过程默认不可见的体验提出诉求——希望能在 UI 上控制"这轮要不要思考"，同时希望"模型如果不支持思考，能看出来"。各服务商的「是否支持思考 + 是否允许关闭」语义不一致：DeepSeek V4 / `deepseek-reasoner` / MiniMax-M3 是 **opt-in**（默认关，user 显式开启）；豆包 Seed 2.x 服务端**默认开**且 user 关不掉；其他（gpt-4o、claude-3 / claude-3.5、kimi、mimo、gemini、custom 等）目前不支持，无法 toggle。

决策：双 capability 区分两种语义。

- `ModelCapability.deepThinking` —— **用户可控 toggle**。命中后聊天页底部输入区显示"深度思考"chip（与既有的"联网搜索"chip 镜像同一组件模式），灰色可点击、点开变紫。
- `ModelCapability.alwaysThinking` —— **服务端锁定默认开**。命中后 chip 改为只读灰色"深度思考（默认）"，按下无响应（明示"你关不掉"），UI 上不向用户暴露"我能不能关"的歧义。

ChatComposer 渲染优先级：`alwaysThinking` > toggle chip > 不显示。LlmClient 上游由 `chat_controller._resolveDeepThinking` 用 `inferCapabilities(modelId)` 二次校验——能力不足的模型 deepThinking 参数**根本不会传 true**，避免发到不支持的 endpoint 触发 400。OpenAI 兼容路径的 `thinking` 参数 shape 按 provider 走不同形态：豆包是 `{type: 'enabled'}` 对象、火山方舟 ARK 要求；MiniMax-M3 是 `true` 布尔（字符串 `"true"` 会 400）；Claude / Anthropic 路径走 `ClaudeClient`，body 注入 `thinking: {type: 'enabled'}`（DeepSeek 服务端忽略 `budget_tokens`，通用形态即可）。状态 per-session in-memory、**不持久化**——关闭聊天页或切换模型时重置。

影响范围：`lib/data/models/llm_model_config.dart`（新增两个 enum 值）、`lib/data/models/model_capabilities.dart`（白名单 + 删兜底 `m3` 关键字匹配）、`lib/data/services/llm_client.dart`（OpenAI 兼容路径按 provider 分支 + Claude 路径加 thinking 参数）、`lib/data/services/chat_task_service.dart`（透传 deepThinking）、`lib/ui/features/chat/chat_controller.dart`（per-session state + `_resolveDeepThinking` 校验 + `_triggerLlmStream` helper 同时修复重发复制 bug，见 ADR-023）、`lib/ui/core/shared/chat_composer.dart`（`_AlwaysThinkingIndicator` + `_DeepThinkingToggle` 两个 widget，镜像 `_WebSearchToggle`）、`lib/ui/features/chat/chat_screen.dart`（chip 接线 + 模型切换时重置 toggle）。

实施要点：每加一个 opt-in 模型必须在三层都更新——capability 白名单 + protocol 分支（按 provider 走不同 shape）+ UI 端 chip 显示逻辑。provider 名关键字（`minimax` / `doubao`）与 capability 白名单独立——前者决定参数 shape，后者决定 toggle 是否显示。添加 Anthropic 官方 Claude reasoning 模型时需注意：Anthropic API 要求 `budget_tokens` 与 `max_tokens` 协调，当前客户端 `max_tokens` 硬编码 `4096`，所以传递 `thinking: {type: 'enabled', budget_tokens: 1024}` 是安全的；当前未在白名单里加 Claude reasoning 留待后续 UX 验证。
