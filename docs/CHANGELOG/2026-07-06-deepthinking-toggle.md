# Per-session 深度思考开关 + DeepSeek / MiniMax 思维链输出修复 + 重发 bug 修复

> 日期：2026-07-06

## 背景

用户反馈 DeepSeek 与 MiniMax 的"思考过程"在前端看不见。本会话排障后修了两类 bug：

1. **DeepSeek 流式响应解析缺陷** —— ADR-020 把 DeepSeek 全量切到 Anthropic 协议后，`_extractClaudeDelta` 只读 `delta.text` 字段，丢掉 `thinking_delta` 与 `thinking` block 事件，UI 上 `SessionMessage.reasoning` 永远是空。
2. **MiniMax-M3 默认不开思考** —— 服务端默认不输出 `reasoning_content`，必须在 body 显式传 `thinking: true`（布尔，字符串"true"会 400）。

顺手还发现一个独立的 session.md 重发 bug：

3. **`retryLastMessage` 重复追加 user 消息** —— 重发调 `sendUserMessage`，后者无条件 append user 消息到 state + 写盘。每次重发 session.md 多一份 user 消息。

## 改动概览

### 1. 协议层（`lib/data/services/llm_client.dart`）

- `_extractClaudeDelta` 补全事件分支：`content_block_delta.type == 'thinking_delta'` 读 `delta.thinking` 进 reasoning；`text_delta` 继续读 `delta.text`；`content_block_start.type == 'thinking'` 同步支持。保留旧实现兼容形态。
- `LlmClient.streamChatCompletion` 抽象接口新增 `deepThinking: bool = false` 参数；3 个子类（`ConfigBasedOpenAiCompatibleClient` / `ClaudeClient` / `GeminiClient`）同步签名。
- `ConfigBasedOpenAiCompatibleClient` 在 body 构造时按 provider 走不同 shape：
  - `providerName.contains('minimax')` + deepThinking → `body['thinking'] = true`（MiniMax-M3 必需）
  - 豆包（always-on）**不**传参数（服务端默认开，传也是冗余）
  - 其他 provider 不强塞——上游 `chat_controller._resolveDeepThinking` 用 `inferCapabilities` 二次校验，未在白名单的模型 deepThinking 参数根本不会传 true
- `ClaudeClient` 在 body 注入 `thinking: {type: 'enabled'}`（DeepSeek 服务端忽略 `budget_tokens`，通用形态即可）
- 删除之前 MiniMax-M3 临时 substring 启发式（`minimax + m3` 旧判断）。改由 capability 白名单上游驱动。

### 2. Capability 模型（`lib/data/models/llm_model_config.dart` + `lib/data/models/model_capabilities.dart`）

- `ModelCapability` 新增两个 enum 值：
  - `deepThinking` —— **opt-in**（用户可控 toggle）：DeepSeek V4-Pro / V4-Flash / `deepseek-reasoner` / MiniMax-M3
  - `alwaysThinking` —— **service-locked-on**（服务端锁定默认开）：豆包 Seed 2.1-pro / Seed 2.1-turbo
- `model_capabilities.dart` 关键词清单：原 DeepSeek-vl 视觉项保留；DeepSeek 三个推理模型新增 deepThinking capability；MiniMax-m3 新增 deepThinking capability（同时保留 vision）；豆包 2.1-pro / 2.1-turbo 改成 alwaysThinking。

### 3. ChatComposer UI（`lib/ui/core/shared/chat_composer.dart`）

完全镜像既有的 `_WebSearchToggle` chip 模式，新增两个 widget：

- `_DeepThinkingToggle` —— 可点击的"深度思考"chip，灰色 / 紫色两态切换，sparkle icon。命中 `ModelCapability.deepThinking` 模型时显示。
- `_AlwaysThinkingIndicator` —— 只读灰色"深度思考（默认）"chip，按下无响应，sparkle icon 暗色。命中 `ModelCapability.alwaysThinking` 模型时显示。
- 渲染优先级：`alwaysThinking` > toggle chip > 不显示。已支持模型之间互斥。

`ChatComposer` 加 3 个 props（`deepThinkingEnabled` / `deepThinkingSupported` / `alwaysThinking` + `onDeepThinkingToggle`）。

### 4. 接线（`lib/ui/features/chat/chat_controller.dart` + `chat_screen.dart`）

- `ChatController` 加 `_deepThinkingEnabled` per-session state + `setDeepThinking(value)` setter（in-memory，**不**持久化）。
- `_resolveDeepThinking(modelId)` 用 `inferCapabilities` 二次校验模型 capability，未在白名单的模型 deepThinking 参数置 false。
- 新增 `_triggerLlmStream({messagesForLlm, imageData, imageMimeType})` 私有 helper：抽 `sendUserMessage` 里的"判断 provider + 读 apiKey + fallback + `_startStreamingWithConfig`"步骤，作为 `sendUserMessage` 与 `retryLastMessage` 共用入口。`sendUserMessage` 先 append user + 写盘再调 helper；`retryLastMessage` 先 `removeLastAssistantMessage` + reload state 再调 helper（**不** append user）。
- `chat_screen.dart` 加本地 `_deepThinkingEnabled` state + `_isDeepThinkingSupported` / `_isAlwaysThinking` helper（基于 model id 关键词匹配）；模型切换时重置 toggle 为 false；mirror 可点击 chip 的处理为 `setState` + 同步 controller 状态。

### 5. ChatTaskService 透传（`lib/data/services/chat_task_service.dart`）

`startTask` 加 `deepThinking: bool = false` 参数，透传给 `client.streamChatCompletion`。

### 6. 豆包 Lite 模型剔除（`lib/data/services/model_fetcher.dart` + `model_capabilities.dart`）

`doubao-seed-2-0-lite-250528` 在用户方舟 ARK 账户上持续不可达（250528 版本方舟端已下架或未开通），从豆包 whitelist 剔除避免引导用户到死路径。`doubao-seed-2-1-pro-260628` / `doubao-seed-2-1-turbo-260628` 保留。

## 已知风险 / 后续

- **Anthropic 官方 Claude reasoning 模型未加白名单** —— 当前 hardcoded `max_tokens: 4096`，Anthropic API 要求 `thinking: {type: 'enabled', budget_tokens: N}` 与 `max_tokens > budget_tokens` 配合。本期未在 capability 白名单里添加 Claude reasoning 留待后续 UX 验证；DeepSeek 在 Anthropic 兼容模式下 `budget_tokens` 被服务端忽略，所以 DeepSeek 走这条路径没问题。
- **`mimo` / `kimi` / `gpt-4o` 不支持 thinking** —— 不在白名单，UI 不显示 chip。如果未来需要支持，需要双方同步：capability 白名单 + protocol 分支。
- **per-session 状态不持久化** —— 关闭 chat 页面 / 切换模型 toggle 重置为 false。如果后续 UX 反馈想要"全局默认 / session 覆盖"双层，需要扩展 `AppSettings` 加 `deepThinkingDefault` 字段。
- **`retryLastMessage` 旧的兼容行为** —— 改造前 `sendUserMessage` 重发时给新 user 消息分配新 timestamp 与新 msgId，现在保持 user 原 msgId 不变（依赖 msgId 不变的下游：搜索、引用、关键词榜 stale 判定、NoteStore 链源），需要确保这些下游对"user msgId 在 retry 后不变"的语义兼容。

## 验证

- `dart analyze lib/` → `0 errors`
- `dart analyze lib/data/services/llm_client.dart lib/data/services/chat_task_service.dart lib/data/models/llm_model_config.dart lib/data/models/model_capabilities.dart lib/ui/features/chat/chat_controller.dart lib/ui/core/shared/chat_composer.dart lib/ui/features/chat/chat_screen.dart` → `No issues found!`
- Device smoke（待用户验证）：
  - 切到 DeepSeek V4-Flash → "深度思考"chip 显示，发问题应能看到折叠的 thinking
  - 切到豆包任一模型 → 只读灰色"深度思考（默认）"，发问题能看到折叠的 thinking（自动）
  - 切到 MiniMax-M3 → toggle chip 启用后能看到 reasoning
  - 切到 gpt-4o / claude-3 / mimo / kimi → 整个 chip 行不出现
  - 任意模型发一条 → 等回复 → 点重发 → session.md user 消息条数应保持不变
