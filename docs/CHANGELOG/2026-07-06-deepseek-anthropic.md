# DeepSeek 全量切换到 Anthropic 兼容协议

> 日期：2026-07-06

## 变更内容

- DeepSeek 全量切到 Anthropic 兼容协议（不仅 web search），普通 chat / 流式 SSE / `web_search_20260209` 工具全部走 Anthropic Messages API
- `preset_deepseek` 的 `baseUrl` / `defaultBaseUrl` 从 `https://api.deepseek.com/v1` 改为 `https://api.deepseek.com/anthropic/v1`，`isOpenAiCompatible` 改为 `false`
- 新增老用户迁移 `LlmConfigStore.migrateDeepSeekToAnthropic()`：升级时自动把老 baseUrl（`/v1`）迁移到新端点（`/anthropic/v1`），API Key 不受影响
- `LlmClient.forConfig` 去掉"DeepSeek + webSearch 切 ClaudeClient"的拼接分支，DeepSeek 直接返回 `ClaudeClient.withBaseUrl(config.baseUrl)`
- `ModelFetcher.fetchModels` 把 DeepSeek 加到 Anthropic 拉取分支（复用 `_fetchAnthropicModels`）

## 技术实现

- 决策依据：DeepSeek 官方 OpenAI 兼容 Chat Completions API 与 Anthropic 兼容 Messages API 在功能上完全覆盖，统一到 Anthropic 协议可以彻底去掉"按 webSearch 切换"的分支
- 迁移兼容：升级启动时跑一次 `migrateDeepSeekToAnthropic()`，幂等（已迁移的跳过），保证老用户升级零感知
- 集成测试：`preset_deepseek` + `deepseek-chat` 模型名不变，fixture 里的 baseUrl 由迁移自动跟随，不影响现有测试

## 改动文件

- lib/data/models/preset_providers.dart
- lib/data/services/llm_client.dart
- lib/data/services/model_fetcher.dart
- lib/data/stores/llm_config_store.dart
- lib/ui/core/app_services.dart
- docs/DECISIONS.md（新增 ADR-020）
- docs/modules/llm/README.md（更新路由表 + 历史时间线）