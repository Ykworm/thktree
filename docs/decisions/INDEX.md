# 架构决策记录（ADR 索引）

> 由 `docs/DECISIONS.md` 拆分而成。每条 ADR 独立成文件，便于按需只读、降低 AI 上下文开销。

## 前言

> **本文件定位**：项目的"架构 DNA"——所有 high-level 技术决策的完整理由、影响范围、实施步骤都在这里。
> **维护者**：人类 + AI 共同维护。任何重大技术变更（换框架、换状态管理、换存储、换关键依赖）必须先在这里新增一条 ADR，再动手改代码。
> **格式约定**：每条决策 = 一节文段（背景/决策/影响/实施）。不抽字段、不用表格——文段怎么自然怎么写。
> **查找方式**：AI 通过 `## ADR-NNN` 二级标题 rg 定位。

---


## 总览

| ADR | 标题 | 文件 |
|---|---|---|
| ADR-001 | 状态管理选型 Riverpod StateNotifier | [ADR-001-状态管理选型-Riverpod-StateNotifier.md](ADR-001-状态管理选型-Riverpod-StateNotifier.md) |
| ADR-002 | 路由方案 go_router | [ADR-002-路由方案-go_router.md](ADR-002-路由方案-go_router.md) |
| ADR-003 | UI 框架纯 Cupertino | [ADR-003-UI-框架纯-Cupertino.md](ADR-003-UI-框架纯-Cupertino.md) |
| ADR-004 | 存储分层 Markdown 正文 + SQLite 元数据 | [ADR-004-存储分层-Markdown-正文-SQLite-元数据.md](ADR-004-存储分层-Markdown-正文-SQLite-元数据.md) |
| ADR-005 | 写入队列 FileWriteQueue 单写者 | [ADR-005-写入队列-FileWriteQueue-单写者.md](ADR-005-写入队列-FileWriteQueue-单写者.md) |
| ADR-006 | LLM 调用 SSE 流式 + API Key 走 flutter_secure_storage | [ADR-006-LLM-调用-SSE-流式-API-Key-走-flutter_secure_storage.md](ADR-006-LLM-调用-SSE-流式-API-Key-走-flutter_secure_storage.md) |
| ADR-007 | Markdown 渲染库 gpt_markdown 替代 flutter_markdown | [ADR-007-Markdown-渲染库-gpt_markdown-替代-flutter_markdown.md](ADR-007-Markdown-渲染库-gpt_markdown-替代-flutter_markdown.md) |
| ADR-008 | 国际化 flutter_localizations + intl + 双语硬性 | [ADR-008-国际化-flutter_localizations-intl-双语硬性.md](ADR-008-国际化-flutter_localizations-intl-双语硬性.md) |
| ADR-009 | 本地搜索 SQLite FTS5 + BM25 | [ADR-009-本地搜索-SQLite-FTS5-BM25.md](ADR-009-本地搜索-SQLite-FTS5-BM25.md) |
| ADR-010 | 节点色与主题色完全解耦 | [ADR-010-节点色与主题色完全解耦.md](ADR-010-节点色与主题色完全解耦.md) |
| ADR-011 | 文档治理——单一全局决策文件 + 纯文段格式 | [ADR-011-文档治理-单一全局决策文件-纯文段格式.md](ADR-011-文档治理-单一全局决策文件-纯文段格式.md) |
| ADR-012 | 语音播放 UI 交互——独立播放器页面 + 语速不持久化 | [ADR-012-语音播放-UI-交互-独立播放器页面-语速不持久化.md](ADR-012-语音播放-UI-交互-独立播放器页面-语速不持久化.md) |
| ADR-013 | LLM 测试 Key 改用 `--dart-define-from-file` 编译期注入，放弃 assets 路径 | [ADR-013-LLM-测试-Key-改用-dart-define-from-file-编译期注入-放弃-assets-路径.md](ADR-013-LLM-测试-Key-改用-dart-define-from-file-编译期注入-放弃-assets-路径.md) |
| ADR-014 | DB 一致性保障——统一 disk-first 写入顺序 + 启动轻量同步 | [ADR-014-DB-一致性保障-统一-disk-first-写入顺序-启动轻量同步.md](ADR-014-DB-一致性保障-统一-disk-first-写入顺序-启动轻量同步.md) |
| ADR-015 | 分支创建集成测试 4 chat 并行推进——翻转「不实现 case 1-7」旧决策 | [ADR-015-分支创建集成测试-4-chat-并行推进-翻转-不实现-case-1-7-旧决策.md](ADR-015-分支创建集成测试-4-chat-并行推进-翻转-不实现-case-1-7-旧决策.md) |
| ADR-016 | iOS LLM 流式中断恢复策略——disk-first + 自动重发 + 30s 边界 | [ADR-016-iOS-LLM-流式中断恢复策略-disk-first-自动重发-30s-边界.md](ADR-016-iOS-LLM-流式中断恢复策略-disk-first-自动重发-30s-边界.md) |
| ADR-017 | 实验室 tab 上线 + tab bar 结构调整 + flutter_svg 引入 | [ADR-017-实验室-tab-上线-tab-bar-结构调整-flutter_svg-引入.md](ADR-017-实验室-tab-上线-tab-bar-结构调整-flutter_svg-引入.md) |
| ADR-018 | Notifier 后台任务保活——autoDispose + build() 内 ref.keepAlive() 双标记范式 | [ADR-018-Notifier-后台任务保活-autoDispose-build-内-ref-keepAlive-双标记范式.md](ADR-018-Notifier-后台任务保活-autoDispose-build-内-ref-keepAlive-双标记范式.md) |
| ADR-019 | DeepSeek 联网搜索使用 Anthropic 兼容接口 | [ADR-019-DeepSeek-联网搜索使用-Anthropic-兼容接口.md](ADR-019-DeepSeek-联网搜索使用-Anthropic-兼容接口.md) |
| ADR-020 | DeepSeek 全量切换到 Anthropic 兼容协议 | [ADR-020-DeepSeek-全量切换到-Anthropic-兼容协议.md](ADR-020-DeepSeek-全量切换到-Anthropic-兼容协议.md) |
| ADR-021 | ClaudeClient 流式响应补全 `thinking_delta` 解析 | [ADR-021-ClaudeClient-流式响应补全-thinking_delta-解析.md](ADR-021-ClaudeClient-流式响应补全-thinking_delta-解析.md) |
| ADR-022 | Per-session 深度思考开关 + 双 `ModelCapability` 区分 | [ADR-022-Per-session-深度思考开关-双-ModelCapability-区分.md](ADR-022-Per-session-深度思考开关-双-ModelCapability-区分.md) |
| ADR-023 | `retryLastMessage` 重构——避免重发重复追加 user 消息 | [ADR-023-retryLastMessage-重构-避免重发重复追加-user-消息.md](ADR-023-retryLastMessage-重构-避免重发重复追加-user-消息.md) |
| ADR-024 | 自动备份采用"前台补偿"而非 iOS BGTaskScheduler | [ADR-024-自动备份采用-前台补偿-而非-iOS-BGTaskScheduler.md](ADR-024-自动备份采用-前台补偿-而非-iOS-BGTaskScheduler.md) |
| ADR-025 | Markdown 链接打开方式——flutter_custom_tabs（SFSafariViewController）而非 url_launcher / in-app WebView | [ADR-025-Markdown-链接打开方式-flutter_custom_tabs-SFSafariViewController-而非-url_launcher-in-app-WebView.md](ADR-025-Markdown-链接打开方式-flutter_custom_tabs-SFSafariViewController-而非-url_launcher-in-app-WebView.md) |
| ADR-026 | 模型解析统一为单一数据源——`_resolveChatModelForLlm` 复用 `resolveChatModel` 优先级 | [ADR-026-模型解析统一为单一数据源-_resolveChatModelForLlm-复用-resolveChatModel-优先级.md](ADR-026-模型解析统一为单一数据源-_resolveChatModelForLlm-复用-resolveChatModel-优先级.md) |

