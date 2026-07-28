# LLM 模型白名单与清单策略

> **一句话：** 没有单独的 whitelist JSON。白名单是 `lib/data/services/model_fetcher.dart` 里的 Dart 常量；能力标签在 `lib/data/models/model_capabilities.dart`。

用户在「设置 → 大模型 → 拉取模型列表」时，`ModelFetcher.fetchModels()` 按 Provider 类型决定：**返回白名单**，还是 **调用 `/models` API 再过滤**。

---

## 1. 源码位置（维护入口）

| 文件 | 作用 |
|------|------|
| [`lib/data/services/model_fetcher.dart`](../../../../lib/data/services/model_fetcher.dart) | 各 Provider 白名单常量 + `fetchModels` 分发 |
| [`lib/data/models/model_capabilities.dart`](../../../../lib/data/models/model_capabilities.dart) | `inferCapabilities(modelId)` — vision / deepThinking / alwaysThinking |
| [`lib/data/models/llm_provider_config.dart`](../../../../lib/data/models/llm_provider_config.dart) | `webSearchSupportMap`、`visibleProviderTypes`、预设 Provider |

---

## 2. 按 Provider 的策略

| Provider | 类型 enum | 模型列表来源 | 说明 |
|----------|-----------|--------------|------|
| **豆包** | `doubao` | 白名单 `_doubaoWhitelist` | 不调 API 结果做 UI；debug 仍会 print 全量 `/models` |
| **DeepSeek** | `deepseek` | 白名单 `_deepseekWhitelist` | Anthropic 兼容 API **无** `/models` 端点（[ADR-020](../../../DECISIONS.md#adr-020-deepseek-全量切换到-anthropic-兼容协议)） |
| **KIMI** | `kimi` | 白名单 `_kimiWhitelist` | 过滤旧版 / 预览噪声 |
| **MiniMax** | `minimax` | 白名单 `_minimaxWhitelist` | 只暴露 M3 |
| **xAI Grok** | `xai` | 白名单 `_xaiWhitelist` | `/models` 含大量 alias / Imagine / Voice |
| **腾讯 TokenHub** | `tokenhub` | 白名单 `_tokenhubWhitelist` | 聚合平台，只暴露 Hy3 系列 |
| **OpenAI** | `openai` | `/models` API | 过滤 embedding / whisper / tts / dall-e |
| **Anthropic** | `anthropic` | `/models` API | 使用 `display_name` |
| **Gemini** | `gemini` | `/models` API | 仅 `generateContent` 模型 |
| **MIMO** | `mimo` | `/models` API | OpenAI 兼容 + 非聊天关键词过滤 |
| **自定义** | `custom` | `/models` API | 同上 |

---

## 3. 当前白名单（与代码同步维护）

> 改模型时：**先改 `model_fetcher.dart`，再改下表**，并检查 `model_capabilities.dart` / 联网映射。

### 豆包 `_doubaoWhitelist`

| modelId | 显示名 | context |
|---------|--------|---------|
| `doubao-seed-2-1-pro-260628` | Doubao-Seed-2.1-pro | 256K |
| `doubao-seed-2-1-turbo-260628` | Doubao-Seed-2.1-turbo | 256K |
| `doubao-seed-2-0-pro-260215` | Doubao-Seed-2.0-pro | 256K |

已移除（勿加回）：`doubao-seed-2-0-lite-250528`（用户方舟账户不可达）。

### DeepSeek `_deepseekWhitelist`

| modelId | 显示名 | context |
|---------|--------|---------|
| `deepseek-v4-pro` | DeepSeek V4 Pro | 1M |
| `deepseek-v4-flash` | DeepSeek V4 Flash | 1M |

注：V4 公开 API **不支持图片输入**；`deepseek-chat` / `deepseek-reasoner` 旧 ID 计划废弃，未入白名单。

### KIMI `_kimiWhitelist`

| modelId | 显示名 | context |
|---------|--------|---------|
| `kimi-k2.6` | KIMI K2.6 | 256K |
| `kimi-k2.5` | KIMI K2.5 | 256K |

### MiniMax `_minimaxWhitelist`

| modelId | 显示名 | context |
|---------|--------|---------|
| `minimax-m3` | MiniMax-M3 | 1M |

### xAI `_xaiWhitelist`

| modelId | 显示名 | context |
|---------|--------|---------|
| `grok-4.5` | Grok 4.5 | 500K |
| `grok-4.3` | Grok 4.3 | 1M |

### 腾讯 TokenHub `_tokenhubWhitelist`

| modelId | 显示名 | context |
|---------|--------|---------|
| `hy3` | Hy3 | 256K |
| `hy3-preview` | Hy3 Preview | 256K |

---

## 4. 新增 / 移除模型的检查清单

1. **`model_fetcher.dart`** — 在对应 `_*Whitelist` 增删条目（`id` / `name` / `contextWindow`）。
2. **`model_capabilities.dart`** — 为新的 `modelId`（或前缀关键词）配置 `ModelCapability`（vision、deepThinking、alwaysThinking）。
3. **联网（若相关）** — 更新 `webSearchSupportMap`、`isModelWebSearchUnsupported`（见 [LLM 模块 README](../README.md)）。
4. **文档** — 更新本文第 3 节表格；复杂变更写 [CHANGELOG](../../CHANGELOG/)。
5. **验证** — 设置页拉取模型列表 → 选模型聊天 → 有 vision/thinking/联网的分别点一遍。

---

## 5. OpenAI 兼容 API 的通用过滤

非白名单 Provider 走 `/models` 时，会丢弃 ID 含以下关键词的模型：

`embedding`、`whisper`、`tts`、`dall-e`

定义见 `model_fetcher.dart` 的 `_nonChatKeywords`。

---

## 6. 相关变更记录

- [2026-07-05 豆包白名单 + Seed vision](../../../CHANGELOG/2026-07-05-chat-model-search-doubao.md)
- [2026-07-06 移除 doubao lite](../../../CHANGELOG/2026-07-06-doubao-lite-removed.md)
- [2026-07-08 KIMI/MiniMax 白名单 + 能力校正](../../../CHANGELOG/2026-07-08-model-capabilities-and-thinking-fixes.md)
- [2026-07-23 MIMO Token Plan + TokenHub](../../../CHANGELOG/2026-07-23-mimo-token-plan-tokenhub.md)
