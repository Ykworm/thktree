# 2026-07-23 — MIMO Token Plan + 腾讯 TokenHub（Hy3）

## 摘要

大模型提供商列表新增两项预置：小米 MIMO **Token Plan**（中国集群）与腾讯 **TokenHub**（Hy3 系列）。

## 变更

### MIMO Token Plan

- 新增 `preset_mimo_token_plan`
- `baseUrl`：`https://token-plan-cn.xiaomimimo.com/v1`
- `type` 仍为 `LlmProviderType.mimo`（联网搜索 / 协议路径与按量 MIMO 相同）
- 与现有按量 `preset_mimo`（`api.xiaomimimo.com/v1`）**并存**，各自独立存 API Key
- 老用户启动时由 `migrateMissingPresets()` 自动补齐

### 腾讯 TokenHub（Hy3）

- 新增 `LlmProviderType.tokenhub`、`preset_tokenhub`
- `baseUrl`：`https://tokenhub.tencentmaas.com/v1`（OpenAI 兼容；客户端拼接 `/chat/completions`）
- 模型白名单：`hy3`、`hy3-preview`（256k context）
- 深度思考：`thinking: {type: "enabled"}`（opt-in；默认 off，关时省略参数）
- 联网搜索：`webSearchSupportMap` 标 `unsupported`（暂不暴露 UI）
- 加入 `visibleProviderTypes`

## 代码

- `lib/data/models/preset_providers.dart`
- `lib/data/models/llm_provider_config.dart`
- `lib/data/models/model_capabilities.dart`
- `lib/data/services/model_fetcher.dart`
- `lib/data/services/llm_client.dart`

## 文档

- `docs/modules/llm/README.md`
- `docs/modules/settings/README.md`
- `docs/FEATURES.md`
