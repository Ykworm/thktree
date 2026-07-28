# LLM 模块

> ⚠️ **AI 改模块前必读**
> 1. **API Key 必走 `flutter_secure_storage`**——任何 `LlmProviderConfig` 的 key 字段不能进 `shared_preferences` / SQLite / 配置文件 / 日志。
> 2. **Provider 软删除**——`isArchived=true` 的 Provider 不出现在 Chat 模型选择里，但不删表记录；别改成硬删。
> 3. **模型列表拉取**走 `ModelFetcher` + Provider 的 `modelsEndpoint`；别在 UI 里手写 `dio.get(...)`。
> 4. **连接测试**是在 LLM 模块内，**Chat 模块不能复用** ChatScreen 的流式逻辑走 ping；调用 `LlmProviderService.testConnection(provider)` 即可。

## 职责

LLM Provider 配置模块。负责管理所有 LLM 服务提供方（OpenAI / Anthropic / 自定义端点等）的配置：增删改、连接测试、模型列表拉取、参数预设（temperature / max_tokens 等）。默认模型入口与模型选择流程归 `settings` 模块维护。

## 功能列表

- Provider 列表：所有已配置 LLM 提供方（pane 式整页列表，subtitle 展示模型数量）
- 新增 Provider：填写 base URL、API key、支持的模型列表
- Provider 详情：编辑 Provider 配置、查看可用模型、调整默认参数
- 连接测试：发送 ping 请求验证 base URL + API key 有效性
- 模型预置：每个 Provider 可预设多个模型，每个模型有独立参数（temperature 等）
- 设为默认：标记一个 Provider 为默认（chat 模块首选）
- 删除 Provider：带二次确认，删除后该 Provider 在 chat 中不再可选

## 代码文件

| 文件 | 角色 | 行数 |
|------|------|------|
| `lib/ui/features/llm/llm_providers_screen.dart` | Provider 列表页 | 128 |
| `lib/ui/features/llm/llm_provider_detail_screen.dart` | Provider 详情/编辑页 | 493 |
| `lib/data/models/llm_error.dart` | 错误模型层：LlmErrorKind（7 种）+ LlmError + fromException 工厂 | 150 |
| `lib/ui/core/widgets/llm_error_card.dart` | 统一错误展示组件（compact 横条 + 占位卡片） | 175 |

## 子文档

- [模型白名单与清单策略](./specs/model-whitelist.md) — 哪些 Provider 用白名单、当前 modelId 列表、维护检查清单（**源码在 `model_fetcher.dart`，无 JSON 文件**）
- [集成测试：LLM 配置注入原理与实践](./specs/integration-test-llm-injection.md) — 集成测试如何注入 LLM 配置到 Riverpod（详细版，208 行）
- [集成测试总论 / fixtures / helpers](../../_shared/integration-testing/README.md) — 面向新成员的完整索引

## 关键设计原则

- **配置 = 行为分离**：UI 只读写 `LlmProviderConfig` 模型（domain 层），实际请求走统一的 `LlmClient` 抽象
- **API key 加密存储**：使用 platform secure storage（iOS Keychain / Android Keystore），绝不落 SQLite 明文
- **Provider 与模型解耦**：1 个 Provider 可有 N 个模型；chat 模块按"Provider + model"粒度选择
- **流式统一**：所有 Provider 走同一套 SSE 解析器，差异在请求协议层
- **失败可观测**：连接测试失败时把 HTTP status + body 摘要展示给用户，便于排错
- **错误统一**：所有 LLM 调用场景通过 `LlmError.fromException` 分类 + `LlmErrorCard` 展示，cancelled 不渲染不上报
- **无可信 logo 时不硬上图标**：Provider 列表宁可保持纯文字 + 模型数量，也不要使用会误导用户的占位 icon

## 联网搜索支持

> 详细设计见 [联网搜索功能设计](../../_tmp/2026-07-03-web-search-design.md)

### LlmClient 接口变更

- `streamChatCompletion` 新增 `webSearch` 参数（`bool`，默认 `false`），调用方按需启用联网
- `LlmClient.forConfig` 新增 `webSearch` 命名参数；工厂方法内部根据 provider 类型自动路由：
  - **DeepSeek** → 走 `ClaudeClient`（Anthropic 兼容 Messages API），端点直接使用 `config.baseUrl`（preset 已是 `https://api.deepseek.com/anthropic/v1`），认证改用 `x-api-key`
  - **Anthropic** → `ClaudeClient.withBaseUrl(config.baseUrl)`
  - **Gemini** → `GeminiClient.withBaseUrl(config.baseUrl)`
  - **其他 provider**（OpenAI / KIMI / MiniMax / MIMO / 豆包 / xAI / 腾讯 TokenHub / 自定义）→ 继续走 `ConfigBasedOpenAiCompatibleClient`（OpenAI 兼容 Chat Completions API）

> DeepSeek 自 2026-07 起**全量**走 Anthropic 兼容协议（不仅 web search）。决策详见 [DECISIONS.md ADR-020](../../DECISIONS.md#adr-020-deepseek-全量切换到-anthropic-兼容协议)。

### ConfigBasedOpenAiCompatibleClient 变更

- **tool_calls 多轮交互**：支持流式收集 tool_calls 增量 → 构建 tool 消息 → 发送第二轮请求的完整流程（KIMI / MIMO 联网搜索场景）
- **工具声明自动选择**（根据 `providerName`）：
  - **KIMI** → `{"type": "builtin_function", "function": {"name": "$web_search"}}`（KIMI 专用内置函数）
  - **其他**（MIMO 等）→ `{"type": "function", "function": {"name": "web_search"}}`
- **KIMI 自动禁用 thinking**：使用 `$web_search` 时自动注入 `thinking: {"type": "disabled"}`（KIMI API 硬性要求）

### 提供商配置

```dart
enum WebSearchSupport {
  supported,    // 官方原生支持
  unsupported,  // 官方不支持
}
```

- **`visibleProviderTypes`**：设置页显示 **OpenAI**、**Anthropic（Claude）**、KIMI、MiniMax、MIMO（含 **MIMO Token Plan** 预置）、DeepSeek、豆包、**xAI Grok**、**腾讯 TokenHub**（Gemini / 自定义暂不发布）
- **`webSearchSupportMap`**：硬编码各提供商联网支持状态（新模型接入时更新此映射）。**OpenAI / MiniMax / TokenHub 为 `unsupported`**（OpenAI：当前 Chat Completions 路径无服务端 web_search 映射；MiniMax：官方联网需 Anthropic Messages 服务端工具 `web_search_20250305`；TokenHub：无独立原生联网映射）
- **`isModelWebSearchUnsupported(modelId)`**：模型级联网判断——豆包 `doubao-seed-2-0-pro` 无日期后缀返回 `true`（legacy Chat Completions 不支持联网），有后缀（如 `-260215`）返回 `false`（走 Responses API 支持联网）

| 提供商 | 联网搜索 | 实现方式 |
|--------|---------|---------|
| OpenAI | ❌ | `preset_openai`（`api.openai.com/v1`）；Chat Completions 路径暂不暴露联网 UI |
| Anthropic（Claude） | ✅ | `preset_anthropic`；`ClaudeClient` + Messages API 服务端工具 `web_search_20260209` |
| KIMI | ✅ | Chat Completions API + `builtin_function.$web_search` + tool_calls 多轮 |
| MiniMax | ❌ | UI / 发送侧均不启用；真实现需 Anthropic 兼容端点 + `web_search_20250305` 服务端工具（见 platform Server Tools 文档） |
| MIMO | ✅ | Chat Completions API + `web_search` 工具声明；预置含按量 `preset_mimo`（`api.xiaomimimo.com/v1`）与 **Token Plan** `preset_mimo_token_plan`（`token-plan-cn.xiaomimimo.com/v1`，type 均为 `mimo`） |
| DeepSeek | ✅ | Anthropic 兼容 Messages API + `web_search_20260209` 工具（**全量**走 Anthropic 协议，不仅 web search） |
| 豆包 | ✅（模型级） | Responses API 内置 `web_search`（仅 250615+ 版本模型）；`isModelWebSearchUnsupported` 屏蔽无后缀旧模型 |
| xAI Grok | ✅ | OpenAI 兼容 `https://api.x.ai/v1`；联网用 `search_parameters.mode` on/off（非 function tools）；深度思考 `reasoning_effort`；白名单 `grok-4.5` / `grok-4.3` |
| 腾讯 TokenHub | ❌ | OpenAI 兼容 `https://tokenhub.tencentmaas.com/v1`（`preset_tokenhub`）；白名单 `hy3` / `hy3-preview`；深度思考 `thinking.type` enabled；联网 UI 暂不启用 |

## 深度思考支持（per-session toggle，2026-07-06）

> 详细设计见 [DECISIONS.md ADR-022](../../DECISIONS.md#adr-022-per-session-深度思考开关--双-modelcapability-区分)

各提供商"是否支持思考 + 是否允许关闭"语义不一致，客户端按 capability 区分两种状态。OpenAI 兼容路径按 provider 走不同的 `thinking` 请求参数形态；Anthropic 兼容路径（DeepSeek）由 `ClaudeClient` 统一处理。

| 模型 / Provider | 推理类型 | 客户端处理 | 协议层参数 shape |
|---|---|---|---|
| DeepSeek V4-Pro / V4-Flash / `deepseek-reasoner` | opt-in（user 可 toggle） | ClaudeClient（Anthropic 兼容路径） | 开：`thinking: {type: 'enabled'}`；**关：显式 `thinking: {type: 'disabled'}`**（DeepSeek 服务端默认 enabled，不传字段等于开，故关闭必须显式 disabled） |
| KIMI k2.6 / k2.5 | opt-in（user 可 toggle） | `ConfigBasedOpenAiCompatibleClient` | 开：`thinking: {type: 'enabled'}`；关：`thinking: {type: 'disabled'}` |
| MiniMax-M3 | opt-in（user 可 toggle） | `ConfigBasedOpenAiCompatibleClient` | 开：`thinking: {type: 'adaptive'}`；关：`thinking: {type: 'disabled'}`（对象格式，非布尔）；**含图片时自动放弃 thinking（`!hasImage` 守卫）** |
| 腾讯 TokenHub Hy3 / Hy3 Preview | opt-in（user 可 toggle） | `ConfigBasedOpenAiCompatibleClient` | 开：`thinking: {type: 'enabled'}`；关：省略（服务端默认 off）；响应 `reasoning_content` |
| 豆包 Seed 2.1-pro / 2.1-turbo | 服务端锁定默认开 | `ConfigBasedOpenAiCompatibleClient` | 服务端默认开，**不**传参数 |
| 其他（gpt-4o / claude-3 / claude-3.5 / mimo / gemini / custom） | 不支持 | — | 不发 `thinking` 参数；chip 不显示 |

`LlmClient.streamChatCompletion` 新增 `deepThinking: bool = false` 参数（默认关）。OpenAI 兼容路径 `if (deepThinking && !hasImage)` 按 provider name 决定参数形态；关闭时（`!webSearch && !hasImage && kimi/moonshot && caps.contains(deepThinking)`）下发 `{type:'disabled'}`；ClaudeClient 路径对 DeepSeek 推理模型在关闭时显式注入 `thinking: {type: 'disabled'}`。**思考与图片互斥**：`ConfigBasedOpenAiCompatibleClient` 新增 `_messagesContainImage` 判断，含图片的请求不传 thinking/webSearch（图片优先），避免 MiniMax-M3 / KIMI 同请求开启思考+图片触发 4xx。chat_controller 上游用 `inferCapabilities(modelId)` 二次校验——能力不足的模型 deepThinking 参数**根本不会传 true**，避免发到不支持的 endpoint 触发 400。

stream 解析端 `_extractClaudeDelta`（Anthropic 协议）在 [ADR-021](../../DECISIONS.md#adr-021-claudeclient-流式响应补全-thinking_delta-解析) 后支持完整的事件分支：
- `content_block_delta.type == 'thinking_delta'` → 读 `delta.thinking` 进 `reasoning`
- `content_block_delta.type == 'text_delta'` 或 `delta.type` 缺省（兼容） → 读 `delta.text` 进 `content`
- `content_block_start.content_block.type == 'thinking'` → 读 `block.thinking` 进 `reasoning`（少数实现在 block_start 预填首段）

OpenAI 兼容协议的 `reasoning_content` 在 `_extractDeltaFromMap` 已支持（豆包 / DeepSeek 原生 Chat Completions 路径）。

## 多模态内容构建（`buildMultimodalContent`）

各 client 子类按协议格式生成图片 content 块：

| Client | 协议 | 图片类型 | image_url 格式 |
|---|---|---|---|
| `LlmClient`（基类） | OpenAI 兼容 | `image_url` | `{url: 'data:mime;base64,...'}`（对象） |
| `ClaudeClient` | Anthropic | `image` | `{source: {type:'base64', media_type, data}}` |
| `DoubaoResponsesClient` | 豆包 Responses API | `input_image` | 直接字符串 `'data:mime;base64,...'` |

**空文本兜底**：`buildMultimodalContent` 检测到 `text.isEmpty && imageData != null` 时自动填充 `'描述这张图片'`，避免豆包等模型因空 `input_text` 块返回 400。

## 视觉能力（vision）

- `ModelCapability.vision` 由 `model_capabilities.dart` 的 `inferCapabilities(modelId)` 关键词映射推断；UI（`chat_screen._isImageSupported`）与发送侧（`chat_controller._currentModelSupportsVision`）均加了 `inferCapabilities` 实时 fallback：缓存的 `provider.models` 里 `supportsVision` 为 false 时回退到关键词映射，改能力映射后**热重启即生效**，无需重新拉模型列表。
- **DeepSeek V4 公开 API 不支持视觉/图片输入**（仅文本/Thinking/工具/JSON/FIM）；网页版 D-Chat 识图是独立管线，不走公开 API。故 `deepseek-v4-pro/flash` 在 capability 映射中**无 vision**，UI 不显示图片按钮、发送在 capability 层即被拦。`forConfig` 不为 DeepSeek 图片走 OpenAI 端点（继续走 Anthropic 兼容路径，图片请求本就不该到达）。`chat_task_service._buildMessages` 将图片 content 构造委托给 `client.buildMultimodalContent`，由各 client 决定 OpenAI `image_url` / Anthropic `image` 格式。

## 维护要点

- 改 LLM 配置前必读 [DECISIONS.md ADR-006](../../DECISIONS.md#adr-006-llm-调用-sse-流式--api-key-走-flutter_secure_storage)（SSE 流式 + Key 存储）
- 新增 Provider 类型：扩 `LlmClient` 抽象 + 在 `chat_controller` 注册（无需改 llm UI）
- API key 存储路径：platform secure storage，迁移时注意 [ios-migration-plan](../../_shared/ios-migration-plan.md)
- Provider 删除是软删除（标记 isDeleted），避免历史对话失去模型引用
- 注意 Provider 配置变更后，正在进行的对话不会被中断（chat 已缓存当时的 client）
- Provider 列表页的标题、副标题和 chevron 是核心信息；厂商图标仅在拿到可信品牌资产时再加
- 联网搜索：新增提供商时同步更新 `webSearchSupportMap` + `visibleProviderTypes`；模型级联网屏蔽用 `isModelWebSearchUnsupported`（如 `doubao-seed-2-0-pro` 无后缀旧 ID）
- 模型清单过滤：见 [模型白名单 spec](./specs/model-whitelist.md)（KIMI / MiniMax / 豆包 / DeepSeek / xAI / TokenHub 等在 `model_fetcher.dart` 维护；OpenAI / Anthropic / Gemini / MIMO / 自定义走 API）

## 相关历史

- 2026-04：LLM 配置模块首次上线（OpenAI 单 provider）
- 2026-05：扩展多 Provider 架构 + 流式统一
- 2026-05：API key 改用 Keychain 加密
- 2026-06：模型预置 + 默认参数功能
- 2026-06-20：Provider 列表页改为填满 body 的 pane 式设置子页，subtitle 改为模型数量
- 2026-06-24：统一 LLM 错误处理与重试（LlmError + LlmErrorCard + 4 场景接入 + 5 个集成测试）
- 2026-07：联网搜索支持（KIMI / MIMO / DeepSeek 已实现，MiniMax 待定）
- 2026-07-23：设置页开放 **OpenAI** / **Anthropic（Claude）**（加入 `visibleProviderTypes`；Claude 联网 supported，OpenAI 暂 unsupported）
- 2026-07-23：MIMO Token Plan 预置（`preset_mimo_token_plan`，中国集群）+ **腾讯 TokenHub**（`LlmProviderType.tokenhub` / `preset_tokenhub`，Hy3 白名单，deepThinking）；见 [CHANGELOG](../CHANGELOG/2026-07-23-mimo-token-plan-tokenhub.md)
- 2026-07-17：MiniMax 联网止血——`webSearchSupportMap[minimax]` 改为 `unsupported`（UI 与发送侧不再启用假 function `web_search`）；真实现仍欠 Anthropic 服务端工具路径
- 2026-07-17：接入 **xAI Grok**（`LlmProviderType.xai` / `preset_xai`，API Key，OpenAI 兼容）；白名单 Grok 4.5/4.3；vision + deepThinking；联网 `search_parameters`
- 2026-07-05：豆包模型白名单（`_fetchDoubaoModels` + `_doubaoWhitelist`，只返回 3 个 Seed 系列模型，不再走 /models API）+ Seed 模型 vision 能力精确映射
- 2026-07-06：DeepSeek 全量切到 Anthropic 兼容协议（ADR-020），preset baseUrl 改为 `/anthropic/v1`，老用户自动迁移
- 2026-07-06：Per-session 深度思考开关上线——`LlmClient.streamChatCompletion` 新增 `deepThinking` 参数；OpenAI 兼容路径按 provider 分支（豆包 `{type: 'enabled'}` / MiniMax-M3 `true`）/ Claude 路径注入 `{type: 'enabled'}`；`ModelCapability` 加 `deepThinking` + `alwaysThinking` 双 cap 区分（详见 [ADR-021](../../DECISIONS.md#adr-021-claudeclient-流式响应补全-thinking_delta-解析) + [ADR-022](../../DECISIONS.md#adr-022-per-session-深度思考开关--双-modelcapability-区分)）。`doubao-seed-2-0-lite-250528` 从豆包 whitelist 移除（方舟端不可达，留着会引导到死路径）
- 2026-07-08：Seed-2.0-pro 模型 ID 修正——`doubao-seed-2-0-pro`（无日期后缀）在 ARK API 调用失败，白名单改为 `doubao-seed-2-0-pro-260215`；`isModelWebSearchUnsupported` 改为仅屏蔽无后缀的旧模型；`webSearchSupportMap` 豆包条目改 `supported`，联网判断收敛到模型级
- 2026-07-08：豆包 Responses API 图片格式修正——`DoubaoResponsesClient.buildMultimodalContent` 图片类型从 `image_url` 改为 `input_image`，`image_url` 从对象改为直接字符串；空文本时自动填充默认提示；`chat_controller.sendUserMessage` 同步处理
- 2026-07-08：模型能力集中校正（CHANGELOG [2026-07-08](../CHANGELOG/2026-07-08-model-capabilities-and-thinking-fixes.md)）——KIMI k2.6/k2.5 加入 `deepThinking`（OpenAI 路径 `thinking:{type:enabled}`、关闭显式 `disabled`）；DeepSeek 关闭思考显式发 `disabled`；MiniMax-M3 / KIMI **思考+图片互斥**（`!hasImage` 守卫，含图请求自动放弃 thinking/webSearch）；KIMI 白名单收窄到 k2.6/k2.5、MiniMax 到 M3；Seed-2.0-pro 联网由 `isModelWebSearchUnsupported` 模型级屏蔽；UI/发送侧 vision 判定加 `inferCapabilities` fallback；**DeepSeek V4 公开 API 不支持视觉**，回退所有 DeepSeek 视觉代码
