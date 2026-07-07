# 模型能力校正 + 多 provider 思考开关 + 视觉/图片处理修复

> 日期：2026-07-08

## 背景

本轮围绕「多 provider 模型能力在 APP 上的实际表现」做了一次集中排障与校正。触发问题链：

1. **DeepSeek 深度思考关不掉** —— DeepSeek 推理模型 thinking 默认 `enabled`，旧代码只在开启时下发 `enabled`，关闭时不下发任何字段，服务端沿用默认 `enabled`，UI 的 toggle 形同虚设。
2. **KIMI 网页版有思考但 APP 没有** —— KIMI（moonshot）同样默认 thinking，但 APP 既未把其列入 `deepThinking` capability 白名单，也未在 OpenAI 兼容协议里下发 thinking 参数，导致 toggle 不显示、思考不输出。
3. **模型清单噪声** —— KIMI / MiniMax 拉回来的模型过多（含旧版、预览版），用户只需要 KIMI k2.6 / k2.5、MiniMax M3，要求按豆包的过滤方式做 whitelist。
4. **Seed-2.0-pro 误显示联网 chip** —— `webSearchSupportMap` 是 provider 级（doubao 整体 true），导致不支持联网的 `doubao-seed-2-0-pro` 也被点亮。
5. **视觉/图片 fallback 失效** —— 已缓存的 `provider.models` 里 `supportsVision` 为 false 时，UI 与发送侧都不回退到 `inferCapabilities`，导致 DeepSeek 模型（早期误以为支持图片）在切换回来后图片按钮消失、发送侧也拦不住。
6. **MiniMax / KIMI「思考 + 图片」互斥报错** —— 用户实测 M3 开启思考模式时发图片会 4xx 报错：这两个 provider 在同一请求里不能同时启用 thinking 与 image。
7. **DeepSeek 公开 API 不支持视觉（关键纠正）** —— 经官方文档与 `deepseekv4.space` 实测确认：V4 公开 API 仅支持 文本/Thinking/工具/JSON/FIM，**不支持视觉/图片输入**（网页 D-Chat 的视觉是独立管线）。此前为 DeepSeek 视觉做的所有改动（capability、forConfig 图片路由、`_messagesContainImage` 辅助、thinking 分支）**全部回退**。

## 改动概览

### 1. Capability 关键词表（`lib/data/models/model_capabilities.dart`）

- **DeepSeek**：`deepseek-v4-pro` / `deepseek-v4-flash` → `{text, deepThinking}`（**移除 vision**，回退早期误加的视觉支持）；`deepseek-vl` 仍保留 vision。
- **KIMI**：`kimi-k2.6` / `kimi-k2.5` → `{text, vision, deepThinking}`（新增 deepThinking + vision）。
- **MiniMax**：`minimax-m3` → `{text, vision, deepThinking}`（保留 vision、新增 deepThinking）。
- `inferCapabilities` 基于 modelId 关键词的子串匹配逻辑不变，仍是 UI 与发送侧的 fallback 来源。

### 2. 协议层（`lib/data/services/llm_client.dart`）

- `ClaudeClient`（承载 DeepSeek Anthropic 兼容路径）：
  - 构造增加 `providerType` 字段；`withBaseUrl(this.baseUrl, [this.providerType])`。
  - thinking 注入：`deepThinking == true` 下发 `{type:'enabled'}`；`deepThinking == false` 且 `providerType == deepseek` 且 `inferCapabilities(model).contains(deepThinking)` 时**显式下发 `{type:'disabled'}`**，让关闭真正生效。
- `ConfigBasedOpenAiCompatibleClient`（KIMI / MiniMax / 通用 OpenAI 兼容）：
  - 新增静态 `_messagesContainImage(messages)`：遍历 content，命中 `image_url` 或 `image` 即认为有图。
  - thinking 逻辑加 `!hasImage` 守卫：
    - `deepThinking == true && !hasImage` → MiniMax 下发 `thinking: true`；KIMI/moonshot 下发 `{type:'enabled'}`。
    - `deepThinking == false && !webSearch && !hasImage` 且为 KIMI/moonshot 且 `caps.contains(deepThinking)` → 下发 `{type:'disabled'}`。
  - `webSearch` 分支同样加 `&& !hasImage`（避免「联网 + 图片」在某些 provider 冲突）。
  - 效果：同一请求里「thinking / webSearch」与「图片」互斥，优先保证图片能发。
- `forConfig`：DeepSeek 仍走 `ClaudeClient.withBaseUrl(config.baseUrl, config.type)`；**未**为图片引入 OpenAI 端点路由（因公开 API 不支持视觉）。
- `buildMultimodalContent` 协议委托：
  - 基类 `LlmClient.buildMultimodalContent` 返回 OpenAI `{type:'image_url', image_url:{url:'data:...;base64,...'}}`。
  - `ClaudeClient.buildMultimodalContent` 返回 Anthropic `{type:'image', source:{type:'base64', media_type, data}}`。

### 3. 模型清单过滤（`lib/data/services/model_fetcher.dart`）

- 新增 `_kimiWhitelist`（`kimi-k2.6` + `kimi-k2.5`）与 `_minimaxWhitelist`（`MiniMax-M3`），及对应的 `_fetchKimiModels()` / `_fetchMinimaxModels()` 方法。
- `fetchModels` 的 switch 分发新增 kimi / minimax 分支，命中后只保留 whitelist 内模型，过滤掉旧版/预览版噪声（与豆包过滤方式一致）。

### 4. Provider 级联网能力修正（`lib/data/models/llm_provider_config.dart`）

- 新增 `isModelWebSearchUnsupported(modelId)` 辅助：`doubao-seed-2-0-pro` 返回 `true`，从模型维度精确屏蔽联网 chip（不再依赖 provider 级 `webSearchSupportMap` 的粗粒度 true）。

### 5. UI 与发送侧视觉 fallback（`lib/ui/features/chat/chat_screen.dart` + `chat_controller.dart`）

- `chat_screen._isImageSupported`：`model?.supportsVision == true` 直接返回；否则回退 `inferCapabilities(modelId).contains(ModelCapability.vision)`（与深度思考 chip 的实时判定一致）。
- `chat_controller._currentModelSupportsVision`：同样加 `|| inferCapabilities(...).contains(vision)` fallback，修复「缓存模型 supportsVision=false 导致图片按钮消失」的问题。
- `chat_controller._resolveWebSearch(providerType, model)`：增加 `model` 参数，调用 `isModelWebSearchUnsupported` 精确屏蔽 Seed-2.0-pro 联网 chip。
- `forConfig` 调用点保持 `LlmClient.forConfig(providerConfig, webSearch: webSearch, model: model)`（无 hasImage 残留）。

### 6. ChatTaskService 协议无关内容构造（`lib/data/services/chat_task_service.dart`）

- `_buildMessages` 增加 `LlmClient client` 参数；当前消息带图时改为 `client.buildMultimodalContent(text, imageData, imageMimeType)`，由 client 决定 OpenAI / Anthropic 图片格式，修复 DeepSeek（ClaudeClient）收到 OpenAI `image_url` 被端点拒收的 bug。
- 移除不再使用的 `dart:convert` import。

## 已知风险 / 后续

- **DeepSeek 视觉彻底关闭** —— V4 公开 API 不支持图片，图片按钮在 DeepSeek 模型下不再出现；若未来官方开放视觉 API，需在 `model_capabilities.dart` 加回 vision 并重新评估 `forConfig` 路由（届时不应再走 Anthropic 端点处理图片，或确认 Anthropic 兼容端点支持 image）。
- **Thinking + Image 互斥是 provider 限制** —— MiniMax / KIMI 同请求不能并存 thinking 与 image，当前以「图片优先、自动关 thinking/webSearch」实现。若某 provider 后续支持并存，可移除此守卫。
- **whitelist 维护** —— KIMI / MiniMax 的新模型需手动加白；`model_fetcher` 已预留 `_*Whitelist` 便于扩展。
- **Seed-2.0-pro 联网** —— 由 `isModelWebSearchUnsupported` 模型级屏蔽，与 provider 级 `webSearchSupportMap` 共存；若后续 doubao 其他模型也需逐个屏蔽，应统一收敛到模型级判定。

### 7. 豆包 Responses API 图片格式修正 + 空文本默认提示

- **问题**：豆包 Seed-2.1-turbo 只发图片不写文字时返回 400；Seed-2.1-pro 正常。
- **根因**：
  - `DoubaoResponsesClient.buildMultimodalContent` 用的是 OpenAI 的 `image_url` 格式（`{type:'image_url', image_url:{url:'...'}}`），豆包 Responses API 要求 `input_image`（`{type:'input_image', image_url:'...'})`（直接字符串，不是对象）。
  - 用户只发图片不写文字时，`text` 为空字符串，某些模型不接受空 `input_text` 块。
- **修复**：
  - `DoubaoResponsesClient.buildMultimodalContent`：`image_url` → `input_image`，`{url:'...'}` → 直接字符串。
  - 基类 `LlmClient.buildMultimodalContent` 与 `DoubaoResponsesClient` 同步：`text.isEmpty` 时自动填 `'描述这张图片'`，避免空文本导致 API 拒绝。
  - `chat_controller.sendUserMessage`：同逻辑，`effectiveText = trimmed.isEmpty && imageData != null ? '描述这张图片' : trimmed`。

## 验证

- Device smoke（用户已实测通过）：
  - DeepSeek V4 任一模型 → 深度思考 toggle 可开可关，关闭后真正不下发 thinking。
  - KIMI k2.6 / k2.5 → 深度思考 chip 出现且可切换，发送可见 thinking；图片可上传（未开思考时）。
  - MiniMax M3 → 深度思考 chip 出现；开思考时上传图片会被自动让位（不报错），关思考时可正常发图。
  - 豆包 Seed-2.0-pro → 联网 chip 不再误显示；Seed-2.1-pro / 2.1-turbo 仍正确显示 alwaysThinking。
  - 模型清单：KIMI 仅剩 k2.6 / k2.5，MiniMax 仅剩 M3。
  - DeepSeek 模型下图片按钮消失（符合「公开 API 不支持视觉」预期）。
  - **豆包 Seed-2.1-turbo / 2.1-pro** → 只发图片不写文字，自动填充"描述这张图片"，不再 400。
- 代码改动随本文档一并 commit；未执行 ctsync（用户确认不需）。
