## ADR-019: DeepSeek 联网搜索使用 Anthropic 兼容接口

2026-07-04 决定。DeepSeek 官方 Chat Completions API（`/v1/chat/completions`）不支持联网搜索——发送 `tools` 参数中的 `web_search` 相关定义会被服务端忽略或返回错误，无法获取带引用的搜索结果。经调研发现 DeepSeek 提供 Anthropic 兼容接口（`/anthropic/v1/messages`），该接口原生支持 `web_search_20260209` 工具类型，返回结果包含网页引用和摘要，行为与 Claude 的 web_search tool 一致。

决策：在 `LlmClient.forConfig` 工厂方法中，当 provider 为 DeepSeek 且 `webSearch` 参数为 `true` 时，自动切换到 `ClaudeClient.withBaseUrl('${config.baseUrl}/anthropic/v1')`，复用现有 `ClaudeClient` 的请求构建、SSE 流式解析和 tool_calls 处理逻辑，不新建独立的 DeepSeek WebSearch 客户端类。对调用方完全透明——`LlmClient.forConfig` 的返回类型仍是 `LlmClient`，调用方无需感知底层协议切换。

理由有三。第一，避免代码重复——`ClaudeClient` 已实现完整的 Anthropic Messages API 协议（包括 `system` 字段、`content` 数组、`tool_use` / `tool_result` 块结构），新建一个 `DeepSeekWebSearchClient` 只是复制粘贴加改 base URL。第二，DeepSeek 的 Anthropic 兼容接口与 Claude API 格式完全一致（请求体结构、SSE 事件格式、tool 定义方式），`ClaudeClient` 无需任何适配修改即可直连。第三，自动切换对调用方透明——`LlmClient.forConfig` 内部判断 + 路由，上层 `ChatTaskService` / `ChatController` 不需要加 `if (provider == deepSeek && webSearch)` 的分支逻辑。

影响范围：`lib/data/services/llm_api_client.dart`（`LlmClient.forConfig` 增加 DeepSeek + webSearch 分支）、`lib/data/services/claude_client.dart`（`withBaseUrl` 构造函数，如尚未暴露则新增）。不涉及 `ClaudeClient` 内部逻辑改动，不涉及新文件。测试覆盖：集成测试中 DeepSeek 联网搜索场景走 `ClaudeClient` 路径验证。

实施要点：`config.baseUrl` 的拼接规则——DeepSeek 的 Anthropic 端点是 `${config.baseUrl}/anthropic/v1`（例如 `https://api.deepseek.com/anthropic/v1`），不是替换 path 而是追加子路径；`ClaudeClient.withBaseUrl` 接收的 base URL 不含 `/messages` 后缀（由 client 内部拼接）。如果 DeepSeek 的 Anthropic 端点未来变更路径，只需改 `LlmClient.forConfig` 中的一行拼接逻辑。DeepSeek 非联网场景仍走原生 Chat Completions API（`/v1/chat/completions`），仅 `webSearch: true` 时切换。
