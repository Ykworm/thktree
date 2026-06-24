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

## 维护要点

- 改 LLM 配置前必读 [DECISIONS.md ADR-006](../../DECISIONS.md#adr-006-llm-调用-sse-流式--api-key-走-flutter_secure_storage)（SSE 流式 + Key 存储）
- 新增 Provider 类型：扩 `LlmClient` 抽象 + 在 `chat_controller` 注册（无需改 llm UI）
- API key 存储路径：platform secure storage，迁移时注意 [ios-migration-plan](../../_shared/ios-migration-plan.md)
- Provider 删除是软删除（标记 isDeleted），避免历史对话失去模型引用
- 注意 Provider 配置变更后，正在进行的对话不会被中断（chat 已缓存当时的 client）
- Provider 列表页的标题、副标题和 chevron 是核心信息；厂商图标仅在拿到可信品牌资产时再加

## 相关历史

- 2026-04：LLM 配置模块首次上线（OpenAI 单 provider）
- 2026-05：扩展多 Provider 架构 + 流式统一
- 2026-05：API key 改用 Keychain 加密
- 2026-06：模型预置 + 默认参数功能
- 2026-06-20：Provider 列表页改为填满 body 的 pane 式设置子页，subtitle 改为模型数量
- 2026-06-24：统一 LLM 错误处理与重试（LlmError + LlmErrorCard + 4 场景接入 + 5 个集成测试）
