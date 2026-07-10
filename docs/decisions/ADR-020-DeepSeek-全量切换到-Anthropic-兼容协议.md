## ADR-020: DeepSeek 全量切换到 Anthropic 兼容协议

2026-07-06 决定。承接 ADR-019（仅 web search 切到 Anthropic 兼容），本决策把 DeepSeek 整个 chat 路径（不限于 web search）全部切到 Anthropic 兼容协议。理由：DeepSeek 官方 Chat Completions API（`/v1/chat/completions`）需要 OpenAI 兼容客户端，而 Anthropic 兼容接口（`/anthropic/v1/messages`）在功能上完全覆盖——普通 chat、流式 SSE、`tools`、`system` 字段、`tool_use` / `tool_result` 块结构全部支持，且 `web_search_20260209` 工具也走同一个端点。统一到 Anthropic 协议可以彻底去掉 `LlmClient.forConfig` 里的"OpenAI / Anthropic 协议按 webSearch 切换"分支，简化调用栈；客户端实现侧无需新增类，直接复用 `ClaudeClient`；`ModelFetcher` 也只需要一份 Anthropic 拉取逻辑。代价：preset 的 `baseUrl` 从 `https://api.deepseek.com/v1` 改成 `https://api.deepseek.com/anthropic/v1`，老用户已存配置需要一次迁移。

决策：

1. `preset_providers.dart`：`preset_deepseek` 的 `baseUrl` / `defaultBaseUrl` 直接设为 `https://api.deepseek.com/anthropic/v1`，`isOpenAiCompatible: false`。
2. `llm_client.dart` `LlmClient.forConfig`：去掉 `type == deepseek && webSearch` 的拼接分支，直接对 DeepSeek 返回 `ClaudeClient.withBaseUrl(config.baseUrl)`，不再做任何路径拼接（baseUrl 已经是 Anthropic 端点）。
3. `model_fetcher.dart` `fetchModels`：`switch` 加 `case LlmProviderType.deepseek`，复用 `_fetchAnthropicModels(baseUrl, apiKey)`，baseUrl 透传（已经是 Anthropic 端点）。
4. `llm_config_store.dart` 新增 `migrateDeepSeekToAnthropic()`：扫描所有 `type == deepseek` 且 `baseUrl` 不含 `/anthropic/` 的 provider，把 baseUrl 改成 `${base}/anthropic/v1`（去掉可能的 `/v1` 后缀再拼接），`defaultBaseUrl` 同步更新，`isOpenAiCompatible` 改成 `false`。API Key 不动。
5. `app_services.dart` 的 `llmProvidersProvider` 在 `migrateMissingPresets()` 之后调用 `migrateDeepSeekToAnthropic()`，保证老用户升级后立即生效。

影响范围：`lib/data/models/preset_providers.dart`、`lib/data/services/llm_client.dart`、`lib/data/services/model_fetcher.dart`、`lib/data/stores/llm_config_store.dart`、`lib/ui/core/app_services.dart`。集成测试里 DeepSeek 相关 fixture 的 `baseUrl` 不依赖具体协议端点（用的是 `preset_deepseek` 的字段，迁移后自动跟随），不受影响。模型 ID（`deepseek-chat` 等）保持不变。

ADR-019 是本决策的前置与子集：本决策把"仅 web search 切"扩展到"全量切"，原 ADR-019 的拼接逻辑被本决策吸收并废弃，`LlmClient.forConfig` 不再需要 `webSearch` 参数驱动的路径分支。联网搜索工具类型（`web_search_20260209`）由 `ClaudeClient` 在 `webSearch: true` 时透传，与之前保持一致。
