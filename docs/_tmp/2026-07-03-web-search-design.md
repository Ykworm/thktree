# 联网搜索功能设计

> 日期：2026-07-03
> 状态：Phase 1-2 已实现，MiniMax 待定

---

## 1. 背景

用户希望 AI 聊天时能获取实时互联网信息（新闻、天气、最新数据等）。

经调研，KIMI、MiniMax、MIMO、DeepSeek 四家厂商的 API 均原生支持联网搜索，无需自行实现搜索/爬虫。
各厂商实现方式不同（详见表 3）。

---

## 2. APP 当前支持的提供商与联网能力

| 提供商 | APP 是否显示 | 联网搜索 | 说明 |
|--------|-------------|---------|------|
| KIMI | ✅ | ✅ | Chat Completions API 原生支持 |
| MiniMax | ✅ | ✅ | Assistants API 原生支持 |
| MIMO | ✅ | ✅ | Chat Completions API 原生支持（需后台开通插件） |
| DeepSeek | ✅ | ✅ | Anthropic 兼容 API 支持 |
| OpenAI | ❌ 不显示 | — | 未测试，暂不发布 |
| Anthropic | ❌ 不显示 | — | 未测试，暂不发布 |
| Gemini | ❌ 不显示 | — | 未测试，暂不发布 |
| 自定义 | ❌ 不显示 | — | 未测试，暂不发布 |

四个提供商全部支持联网搜索。

**额外改动**：设置页面的提供商列表需要过滤，只显示 KIMI、MiniMax、MIMO、DeepSeek 四个。

---

## 3. 各厂商联网 API 实现方式

### 3.1 KIMI

- **API**：OpenAI 兼容 Chat Completions API
- **联网方式**：tools 参数声明 `builtin_function.$web_search`
- **流程**：
  1. 请求时在 `tools` 中添加 `{"type": "builtin_function", "function": {"name": "$web_search"}}`
  2. 模型返回 `tool_calls`，包含搜索关键词
  3. 客户端再次请求，将 tool_calls 结果提交回模型
  4. 模型基于搜索结果生成最终回答
- **注意**：使用 `$web_search` 时必须关闭 thinking 模式
- **计费**：联网搜索单独计费
- **文档**：https://platform.kimi.ai/docs/guide/use-web-search

### 3.2 MiniMax

- **API**：Assistants API（非 Chat Completions API）
- **联网方式**：创建 Assistant 时在 tools 中声明 `{"type": "web_search"}`
- **流程**：
  1. 创建 Assistant（关联 `web_search` 工具）
  2. 创建 Thread + 添加用户消息
  3. 创建 Run，模型自动决定是否调用 web_search
  4. 流式返回结果
- **计费**：按 Assistants API 计费规则
- **文档**：https://platform.minimaxi.com/document/lbYEaWKRCr5f7EVikjFJjSDK
- **⚠️ 关键问题**：项目当前使用 Chat Completions API（`ConfigBasedOpenAiCompatibleClient`），MiniMax 联网需要切换到 Assistants API，架构差异较大

### 3.3 MIMO

- **API**：OpenAI 兼容 Chat Completions API
- **联网方式**：tools 参数声明 `web_search` 工具
- **模式**：
  - **强制搜索**：每次请求都搜索
  - **意图识别**：模型自主决定是否搜索
- **前置条件**：需要在 MIMO 控制台的"插件管理"页面开通 Web Search 插件
- **计费**：国内 ¥25/1000 次，海外 $5/1000 次
- **文档**：https://mimo.mi.com/#/docs/api/text-generation/openai-api
- **响应特点**：搜索结果在流式响应第一个数据包返回

### 3.4 DeepSeek

- **API**：Anthropic 兼容 Messages API（非 Chat Completions API）
- **联网方式**：tools 参数声明 `{"type": "web_search_20260209", "name": "web_search"}`
- **流程**：
  1. 请求时在 `tools` 中添加 web_search 工具
  2. 模型返回 `server_tool_use` 事件，包含搜索关键词
  3. 模型自动完成搜索，在流式响应中返回 `web_search_tool_result`
  4. 模型基于搜索结果生成最终回答
- **端点**：`POST https://api.deepseek.com/anthropic/v1/messages`
- **认证**：`x-api-key` header（与 Chat Completions 的 `Authorization: Bearer` 不同）
- **模型**：需要 `deepseek-v4-flash` 或更新版本
- **⚠️ 关键问题**：项目当前对 DeepSeek 使用 OpenAI 兼容接口。联网需要走 Anthropic 兼容接口，需要新增客户端或扩展现有客户端。

---

## 4. 设计方案

### 4.1 联网支持状态

```dart
enum WebSearchSupport {
  supported,      // 官方原生支持
  unsupported,    // 官方不支持
}
```

硬编码支持列表（APP update 更新）：

```dart
const webSearchSupportMap = {
  LlmProviderType.kimi: WebSearchSupport.supported,
  LlmProviderType.minimax: WebSearchSupport.supported,
  LlmProviderType.mimo: WebSearchSupport.supported,
  LlmProviderType.deepseek: WebSearchSupport.supported,
};
```

四个提供商全部支持联网。新模型接入时更新此映射。

### 4.2 用户偏好持久化

用户对每个提供商的联网开关状态：

- 存储 key：`web_search_enabled_{providerType}`
- 存储位置：SharedPreferences
- 默认值：支持联网的提供商默认开启

### 4.3 UI 设计

**位置**：聊天输入框底部，发送按钮旁边

**状态**：

| 状态 | 显示 | 交互 |
|------|------|------|
| 支持 + 开启 | 蓝色地球图标 | 可点击切换为关闭 |
| 支持 + 关闭 | 灰色地球图标 | 可点击切换为开启 |
| 不支持 | 灰色地球图标 + 删除线 | 不可点击，tooltip："当前模型不支持联网搜索" |

### 4.4 数据流

```
用户输入消息
    ↓
ChatController 检查当前 provider 的 webSearchSupport
    ↓
┌─ supported + 用户开关开启
│   → 调用 LlmClient.streamChatCompletion() 时启用联网参数
│   → KIMI/MIMO：在 tools 中添加 web_search
│   → DeepSeek：通过 Anthropic 兼容 API 调用
│   → MiniMax：通过 Assistants API 调用
│
├─ supported + 用户开关关闭
│   → 正常调用，不启用联网
│
└─ unsupported
    → 正常调用，不启用联网（UI 按钮灰色）
```

---

## 5. 实现难点与风险

### 5.1 MiniMax 架构差异（高风险）

项目当前所有提供商统一使用 `LlmClient` 接口（基于 Chat Completions API）。
MiniMax 联网搜索需要走 Assistants API，流程完全不同：
- 需要创建 Assistant → Thread → Run
- 不是简单的请求/响应模式

**方案选择**：
- **方案 A**：为 MiniMax 单独实现 Assistants API 客户端
- **方案 B**：MiniMax 暂不支持联网，先做 KIMI + MIMO
- **方案 C**：调研 MiniMax Chat Completions API 是否也支持 web_search（未确认）

**建议**：先做方案 B（KIMI + MIMO），MiniMax 后续单独处理

### 5.2 KIMI 的 tool_calls 流程

KIMI 联网不是简单的加参数，需要多轮交互：
1. 发送带 `$web_search` tool 的请求
2. 收到 `tool_calls` 响应
3. 把 tool_calls 结果作为 tool message 再次发送
4. 收到最终回答

现有的 `LlmClient.streamChatCompletion()` 需要支持这种多轮 tool_calls 流程。

### 5.3 MIMO 的前置条件

MIMO 联网需要用户在 MIMO 控制台手动开通 Web Search 插件。
如果用户没开通，API 调用会失败或忽略联网参数。

需要处理这种情况：检测失败 → 提示用户去控制台开通。

### 5.4 UI 状态同步

当用户切换模型（从 KIMI 切到 DeepSeek），联网按钮状态需要实时更新。

### 5.5 DeepSeek Anthropic API（中风险）

DeepSeek 联网需要走 Anthropic 兼容接口，与项目当前使用的 OpenAI 兼容接口不同：
- 端点不同：`https://api.deepseek.com/anthropic/v1/messages`
- 认证方式不同：`x-api-key` 换 `Authorization: Bearer`
- 消息格式可能不同（需确认与项目现有 `ClaudeClient` 的兼容性）

---

## 6. 实现阶段建议

### Phase 1：基础设施 + MIMO（最简单）

- 定义 `WebSearchSupport` 枚举和支持列表
- UI：联网开关组件（支持/不支持/开启/关闭）
- 用户偏好持久化
- MIMO 联网实现（OpenAI 兼容，改动最小）
- 设置页面提供商列表过滤

### Phase 2：KIMI + DeepSeek

- KIMI：实现 tool_calls 多轮交互流程，集成 `$web_search`
- DeepSeek：实现 Anthropic 兼容接口调用，集成 `web_search` 工具

### Phase 3：MiniMax（待定）

- 评估 Assistants API 集成方案
- 或调研 Chat Completions API 是否支持 web_search

### Phase 4：优化

- 搜索结果来源展示
- 搜索状态指示（"正在搜索..."）
- 错误处理与用户提示

---

## 7. 任务清单

- [x] 设置页面：过滤提供商列表（只显示 KIMI/MiniMax/MIMO/DeepSeek）
- [x] 定义 `WebSearchSupport` 枚举
- [x] 硬编码支持列表（四个全部 supported）
- [x] UI：联网搜索开关组件
- [x] 用户偏好持久化（FlutterSecureStorage）
- [x] ChatController 集成联网开关逻辑
- [x] MIMO 联网 API 调用实现（via ConfigBasedOpenAiCompatibleClient tools）
- [x] KIMI 联网 API 调用实现（含 tool_calls 多轮交互 + 自动禁用 thinking）
- [x] DeepSeek 联网 API 调用实现（Anthropic 兼容接口，LlmClient.forConfig 自动切换）
- [ ] MiniMax 联网方案评估（Assistants API 架构差异大，待定）
- [ ] 错误处理（未开通插件等）
- [ ] 集成测试

---

## 8. 实际实现说明

### 8.1 KIMI 实现细节

`ConfigBasedOpenAiCompatibleClient` 中根据 `providerName` 判断是否为 KIMI：
- 是 KIMI → 使用 `builtin_function.$web_search` 工具声明
- 自动添加 `thinking: {"type": "disabled"}`（KIMI 要求）
- 支持 tool_calls 多轮交互：收集流式 tool_calls 增量 → 构建 tool 消息 → 发送第二轮请求

### 8.2 MIMO 实现细节

使用通用 `web_search` function 工具声明。MIMO 服务端自动处理搜索。

### 8.3 DeepSeek 实现细节

`LlmClient.forConfig` 新增 `webSearch` 参数。当 DeepSeek + webSearch 时：
- 自动切换到 `ClaudeClient.withBaseUrl('${config.baseUrl}/anthropic/v1')`
- 使用 Anthropic Messages API 格式
- 添加 `web_search_20260209` 工具声明
- 服务端自动处理搜索

### 8.4 改动文件清单

- `lib/data/models/llm_provider_config.dart` — 新增 WebSearchSupport、visibleProviderTypes、webSearchSupportMap
- `lib/data/services/settings_store.dart` — 新增 web search 偏好持久化
- `lib/ui/features/settings/settings_controller.dart` — 新增 saveWebSearchEnabled
- `lib/data/services/llm_client.dart` — LlmClient.forConfig 增加 webSearch 参数；ConfigBasedOpenAiCompatibleClient 支持 tool_calls 多轮交互；ClaudeClient 支持 web_search 工具
- `lib/data/services/chat_task_service.dart` — startTask 增加 webSearch 参数
- `lib/ui/features/chat/chat_controller.dart` — 解析联网搜索状态，传递给 LLM 客户端
- `lib/ui/features/chat/chat_screen.dart` — 传递联网搜索 UI 状态给 ChatComposer
- `lib/ui/core/shared/chat_composer.dart` — 新增联网搜索开关按钮
- `lib/ui/features/llm/llm_providers_screen.dart` — 过滤提供商列表
- `lib/ui/core/theme/app_icons.dart` — 新增 globeSlash 图标
