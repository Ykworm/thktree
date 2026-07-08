# DeepSeek 深度思考开关「关不掉」修复

> 日期：2026-07-08
> 任务类型：Bug 修复
> 讨论结论：方案 1（让开关真正生效，OFF → 显式发 `thinking: disabled`）

## 现象

用户在 DeepSeek 推理模型（deepseek-v4-pro / v4-flash / deepseek-reasoner）上，切换「深度思考」开关，开/关两种状态表现一致——思考过程始终显示，开关像失灵了。

## 根因

DeepSeek 推理模型的「思考开关」**默认是 `enabled`**（官方文档 Thinking Mode 章节原文：*The thinking toggle defaults to `enabled`*），控制参数在 Anthropic 格式下为 `{"thinking": {"type": "enabled/disabled"}}`。

当前 `ClaudeClient.streamChatCompletion`（`lib/data/services/llm_client.dart:629`）只做了半边：

```dart
if (deepThinking) 'thinking': {'type': 'enabled'},
// deepThinking == false 时：不发送任何 thinking 字段
```

而 `chat_controller._resolveDeepThinking` 在开关关时直接返回 `false` → 不发参数 → DeepSeek 走模型默认 `enabled` → 照样思考。

对比：真·Anthropic Claude 不发送 thinking 时默认**不开**思考，所以这套「关时发空」的逻辑对 Claude 成立；但 DeepSeek 默认相反，于是开关在 DeepSeek 上无效。

## 方案（方案 1）

让开关真正生效：深度思考**关掉**时，对 DeepSeek 推理模型显式补发 `thinking: {type: 'disabled'}`。

要点：
- 只对 **推理类 DeepSeek 模型**补 `disabled`（用 `inferCapabilities(model).contains(deepThinking)` 判定），避免给 `deepseek-chat` 等非推理模型发多余字段。
- 不给真·Anthropic 发 `disabled`（真 Anthropic 关思考靠「不发送」即可，且 `disabled` 值并非其稳定支持形态）。

## 改动文件与位置

1. **`lib/data/services/llm_client.dart`**
   - `ClaudeClient` 增加 `providerType` 字段（构造时由 `forConfig` 传入）。
   - `ClaudeClient.streamChatCompletion` 内把 thinking 注入从 map 字面量 spread 改为显式分支：
     ```dart
     if (deepThinking) {
       bodyData['thinking'] = {'type': 'enabled'};
     } else if (providerType == LlmProviderType.deepseek &&
         inferCapabilities(model).contains(ModelCapability.deepThinking)) {
       bodyData['thinking'] = {'type': 'disabled'};
     }
     ```
   - `LlmClient.forConfig` 在 `deepseek` / `anthropic` 两个分支构造 `ClaudeClient` 时传入 `config.type`。
   - 新增 `import 'package:thk_tree/data/models/model_capabilities.dart';`（无循环依赖：`model_capabilities` 只依赖 `llm_model_config`，而 `llm_client` 已依赖 `llm_provider_config`）。
   - `LlmProviderType` 已在 `llm_client.dart` 通过 `llm_provider_config.dart` 可见，无需额外 import。

2. **`lib/data/models/model_capabilities.dart`** — 不改（`deepThinking` capability 保留，语义本就是「用户可控」）。

3. **ChatComposer / chat_screen / chat_controller** — 不改（开关、可见性、per-session 状态都已就绪，问题只在协议层缺 `disabled`）。

## 不在本次范围

- 不把 DeepSeek 改分类为 `alwaysThinking`（那会是方案 2，已否决）。
- 不处理真·Anthropic 推理模型的 `budget_tokens`（已有「已知风险」记录，且不在白名单）。

## 验收

- `dart analyze lib/` → 0 errors。
- 设备 smoke：
  - 切 DeepSeek V4-Flash → 深度思考 chip 显示 → **关掉开关**发问 → 应**不再**出现折叠 thinking（请求体含 `thinking: disabled`）。
  - 同一模型 → **打开开关**发问 → 应看到折叠 thinking（请求体含 `thinking: enabled`）。
  - 切 `deepseek-chat`（非推理）→ 整个 chip 行不出现，行为不变。
  - 切真·Anthropic / 豆包 / MiniMax / gpt-4o 等 → 行为不变（豆包仍为 alwaysThinking 只读 chip）。
