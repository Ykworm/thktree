# 功能状态总表

> **维护者**：人类 + AI 共同维护。状态/最后更新/路径由人类手动维护；AI 改代码时若发现 `lib/ui/features/<name>/` 下新增文件/方法，应主动询问用户是否在本表新增/更新功能行。
> **职责**：全局文档导航 + 功能状态一览。一行一个功能，可跳转到对应 README/Visual/代码。

**列说明**：

| 列 | 含义 |
|----|------|
| **Feature** | 功能名（中文） |
| **模块** | 归属模块（与 `lib/ui/features/` 对齐；跨模块标 `_shared`） |
| **状态** | ✅ 完成 / 🔨 进行中 / 🔨 部分实现 / 📋 待开发 / ❌ 取消 |
| **最后更新** | YYYY-MM-DD（人类手动维护） |
| **README** | 链接到 `docs/modules/<name>/README.md`（如有 visual 子目录） |
| **Visual** | 链接到 `docs/modules/<name>/visual/<screen>-design.md`（无 visual 文档则 `—`） |
| **代码路径** | 关键文件或目录 |
| **说明** | 一句话补充 |

---

## 1. 主题模块（themes）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 多主题管理 | themes | ✅ 完成 | 2026-06-06 | [README](modules/themes/README.md) | [theme-list-design](modules/themes/visual/theme-list-design.md) | `lib/ui/features/themes/theme_list_*` | ThemeListScreen, ThemeStore, CRUD |
| 树形 Session | themes | ✅ 完成 | 2026-06-06 | [README](modules/themes/README.md) | [theme-detail-design](modules/themes/visual/theme-detail-design.md) | `lib/ui/features/themes/theme_detail_*` | 嵌套渲染, parentId, ThemeDetailScreen |
| 树形节点卡片设计 | themes | 🔨 进行中 | 2026-06-07 | [README](modules/themes/README.md) | [theme-detail-design](modules/themes/visual/theme-detail-design.md) | `lib/ui/features/themes/theme_detail_screen.dart` | 5 套配色方案，行高 56px，标题单行省略 |
| 子孙视图过滤 | themes | 🔨 进行中 | — | [README](modules/themes/README.md) | [theme-detail-design](modules/themes/visual/theme-detail-design.md) | `lib/ui/features/themes/theme_detail_*` | ThemeDetailScreen 有基础树，过滤功能未完整 |
| 汇总预览 | themes | ❌ 取消 | 2026-06-22 | [README](modules/themes/README.md) | [theme-detail-design](modules/themes/visual/theme-detail-design.md) | — | 产品决策取消 |
| 祖先上下文总结 | themes | 🔨 部分实现 | — | [README](modules/themes/README.md) | — | `lib/data/services/` | context-summary.md 写入存在，注入对话未完成 |
| 主题详情 overflow menu | themes | ✅ 完成 | 2026-07-04 | [README](modules/themes/README.md) | — | `lib/ui/features/themes/theme_detail_screen.dart` | NavBar 刷新按钮改为 `⋯` overflow menu（CupertinoActionSheet），含刷新 + 折叠/展开全部 |
| 合并 & 创建新 Chat | themes | ✅ 完成 | 2026-07-09 | [README](modules/themes/README.md) | — | `lib/ui/features/themes/merge_chat_confirm_screen.dart` 等 | 选最多 3 个 chat 合并为新 chat；挂位置选择器按入口区分跨 tree 范围（chat 页入口限当前树，tree 页入口可跨树），详见 [spec](modules/themes/specs/merge-chat.md) |
| 树页节点标题搜索 | themes | ✅ 完成 | 2026-07-17 | [README](modules/themes/README.md) | [theme-detail-design](modules/themes/visual/theme-detail-design.md) | `theme_detail_screen.dart` + `tree_title_filter.dart` | 仅当前主题树、只匹配节点 title；命中 + 祖先路径；非 FTS |

## 2. 笔记模块（notes）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 笔记功能 | notes | ✅ 完成 | 2026-06-07 | [README](modules/notes/README.md) | [notes-list-design](modules/notes/visual/notes-list-design.md) | `lib/ui/features/notes/note_browse_screen.dart` 等 | NoteBrowseScreen, NoteEditorScreen, NoteDetailScreen, NoteStore |
| 笔记搜索 | notes | ✅ 完成 | 2026-06-24 | [README](modules/notes/README.md) | [notes-list-design](modules/notes/visual/notes-list-design.md) | `lib/ui/features/search/search_content.dart` + `lib/ui/features/notes/note_browse_screen.dart` | 笔记 tab 顶部复用 `SearchContent`（FTS5 全文搜索），空查询显示主题分组，非空查询显示搜索结果；详见 [notes/CHANGELOG 第 10 节](modules/notes/CHANGELOG.md#10-笔记-tab-顶部搜索统一为全文搜索2026-06-24) |
| Markdown 工具栏增强 | notes | ✅ 完成 | 2026-06-17 | [README](modules/notes/README.md) | — | `lib/ui/core/widgets/markdown_toolbar.dart` | 标题级别循环切换（h2→h3→h1→无）+ 表格插入按钮 |
| 标题必填校验 | notes | ✅ 完成 | 2026-06-29 | [README](modules/notes/README.md) | — | `lib/ui/features/notes/note_editor_screen.dart` | NoteEditorScreen ✓ 按钮加 `trim().isEmpty` 拦截 → 弹 `titleCannotBeEmpty` ThkAlert（单"确定"按钮），不调 `_saveNow` 不 pop；l10n 新增 `titleCannotBeEmpty`（zh + en）；详见 [notes/CHANGELOG 第 11 节](modules/notes/CHANGELOG.md#11-笔记标题必填校验2026-06-29) + [CHANGELOG](CHANGELOG/2026-06-29-note-title-required.md) |
| 图片插入 | notes | 📋 待开发 | 2026-06-17 | [README](modules/notes/README.md) | — | — | 编辑器工具栏插入图片，支持相册/拍照 |
| Chat-to-Note | notes | ✅ 完成 | 2026-07-04 | [README](modules/notes/README.md) | — | `lib/ui/features/chat/chat_screen.dart` + `lib/ui/core/shared/message_bubble.dart` | assistant 消息"存为笔记"按钮，自动用当前主题创建笔记并跳转编辑器 |
| LLM 生成标题 | notes | ✅ 完成 | 2026-07-04 | [README](modules/notes/README.md) | — | `lib/ui/features/notes/generate_title_screen.dart` | 笔记详情更多菜单→生成标题，LLM 生成备选列表 + 自定义输入 |
| 笔记转移主题 | notes | ✅ 完成 | 2026-07-04 | [README](modules/notes/README.md) | — | `lib/ui/features/notes/note_detail_screen.dart` + `lib/data/stores/note_store.dart` | 笔记详情更多菜单→转移主题，NoteStore.moveNote 跨目录迁移 |

## 3. 对话模块（chat）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 流式对话 | chat | ✅ 完成 | 2026-06-07 | [README](modules/chat/README.md) | — | `lib/ui/features/chat/chat_screen.dart` | LlmClient + SSE, FileWriteQueue, ChatComposer 优化 |
| 标题自动建议 | chat | ✅ 完成 | 2026-06-29 | [README](modules/chat/README.md) | — | `lib/data/services/title_suggestion_service.dart` + `lib/ui/core/shared/title_suggestion_screen.dart` + `lib/ui/features/chat/auto_title_controller.dart`（2026-06-29 新增） | 分支创建时触发，支持选中文本/对话总结/笔记多种来源；**2026-06-29 新增** 空白分支 chat 流式结束后由 `AutoTitleController` 自动 LLM 补 title 并写入 DB（3 层守卫 + `ref.keepAlive()`保活，详见 [ADR-018](DECISIONS.md#adr-018-Notifier-后台任务保活autoDispose--build-内-refkeepalive-双标记范式)；三层防御拦截 LLM 未配置死路（`lib/ui/core/shared/llm_setup_check.dart`）：L1-A（`showBranchFlow` 入口）→ L1-B（`TitleSuggestionScreen.initState`）→ L2（sheet filter 空时弹窗引导） + `pleaseConfigureTitleModel` / `pleaseConfigureSummaryModel` 跳转默认模型配置页 |
| 空白分支自动 title 持久化 | chat | ✅ 完成 | 2026-06-29 | [README](modules/chat/README.md) | — | `lib/ui/features/chat/auto_title_controller.dart` | 空白分支（A 模式）chat 流式结束后自动调 LLM 生成 title 并写入 DB + refresh tree；与 widget 生命周期解耦（`ref.keepAlive()`），提前 back 回 tree 也能后台完成；详见 [ADR-018](DECISIONS.md#adr-018-Notifier-后台任务保活autoDispose--build-内-refkeepalive-双标记范式) + [war-story](war-stories/flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md) + [CHANGELOG](CHANGELOG/2026-06-29-auto-title-persistence.md) |
| iOS 后台中断恢复 | chat | ✅ 完成（iOS only） | 2026-06-22 | [README](modules/chat/README.md) | — | `lib/data/services/chat_task_service.dart` 等 | App 切后台时 `beginBackgroundTask` 续命 30s；切回扫描磁盘 `<!-- streaming -->` 标记触发自动重发，串行排队；详见 [ADR-015](DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界) |
| 联网搜索 | chat | ✅ 完成 | 2026-07-17 | [README](modules/chat/README.md) | — | `lib/ui/features/chat/chat_composer.dart` 等 | 聊天输入框底部联网搜索开关（地球图标），KIMI/MIMO/DeepSeek/豆包（模型级）支持；**MiniMax UI 已标不支持**（2026-07-17 止血），详见下方说明 |
| 图片上传 | chat | ✅ 完成 | 2026-07-05 | [README](modules/chat/README.md) | — | `lib/ui/core/shared/chat_composer.dart` + `lib/ui/features/chat/chat_screen.dart` + `lib/ui/features/chat/chat_controller.dart` | 聊天输入框底部图片按钮，支持拍照/相册选择，image_picker 集成；vision 模型自动检测；只发图片不写文字时自动填充默认提示；豆包 Responses API 使用 `input_image` 格式（区别于 OpenAI `image_url`） |
| 消息时间戳 | chat | ✅ 完成 | 2026-07-04 | [README](modules/chat/README.md) | — | `lib/ui/core/shared/message_bubble.dart` | assistant 消息气泡上方显示人类可读时间（今天 HH:mm / 昨天 / 月日 / 跨年） |
| 查看原始 Markdown | chat | ✅ 完成 | 2026-07-05 | [README](modules/chat/README.md) | — | `lib/ui/features/chat/widgets/chat_markdown_sheet.dart` + `lib/data/stores/session_store.dart` | 更多菜单入口，底部 sheet 展示 session.md 原始内容 + 复制 |
| Per-session 深度思考开关 | chat / llm | ✅ 完成 | 2026-07-06 | [README](modules/chat/README.md) | — | `lib/ui/core/shared/chat_composer.dart` + `lib/data/services/llm_client.dart` + `lib/data/models/model_capabilities.dart` | 聊天输入框下方新增"深度思考"chip，与联网搜索 chip 镜像同模式；`ModelCapability.deepThinking`（user-toggleable：DeepSeek V4-Pro / V4-Flash / `deepseek-reasoner` / MiniMax-M3）+ `ModelCapability.alwaysThinking`（service-locked：豆包 Seed 2.1-pro / turbo）双 cap 区分，详见 [ADR-022](DECISIONS.md#adr-022-per-session-深度思考开关--双-modelcapability-区分)；ClaudeClient `_extractClaudeDelta` 补全 `thinking_delta` 解析见 [ADR-021](DECISIONS.md#adr-021-claudeclient-流式响应补全-thinking_delta-解析)；重发修复见 [ADR-023](DECISIONS.md#adr-023-retrylastmessage-重构避免重发重复追加-user-消息) |
| 滚动到顶/底 | chat | ✅ 完成 | 2026-07-06 | [README](modules/chat/README.md) | — | `lib/ui/core/shared/chat_list_view.dart` + `lib/ui/features/chat/chat_screen.dart` | 浮动箭头按钮（离开底部时出现，点击回到底部）+ 双击 nav bar 标题区跳到顶部（iOS 原生行为） |
| 对话目录 | chat | ✅ 完成 | 2026-07-08 | [README](modules/chat/README.md) | — | `lib/ui/features/chat/widgets/chat_outline_sheet.dart` | 更多菜单入口，底部 sheet 列出所有 user 消息，点击跳转到对话中对应位置 |
| 聊天内搜索 | chat | ✅ 完成 | 2026-07-08 | [README](modules/chat/README.md) | — | `lib/ui/features/chat/widgets/chat_search_sheet.dart` | 更多菜单入口，在当前对话的所有消息中搜索文本，高亮显示结果 |
| 本次发言 | chat | ✅ 完成 | 2026-07-08 | [README](modules/chat/README.md) | — | `lib/ui/features/chat/user_questions.dart` | 更多菜单入口，展示当前会话所有用户消息列表，支持点击查看对应回复 |
| Context Usage Bar | chat | ✅ 完成 | 2026-07-08 | [README](modules/chat/README.md) | — | `lib/ui/features/chat/chat_screen.dart`（`_ContextUsageBar`） | 对话页底部 1px 高 token 使用率进度条，>85% 变红警示 |
| 聊天页祖先链面包屑 | chat | ✅ 完成 | 2026-07-09 | [README](modules/chat/README.md) | — | `lib/ui/features/chat/chat_screen.dart`（`_buildCrumbs`）+ `lib/ui/core/widgets/thk_breadcrumb_nav.dart` | 消息列表顶部 `主题 / 主题名 / 祖先 / 当前` 面包屑，沿 parentId 回溯，点祖先段 `GoRouter.go(path)` 跳回；修 4 个运行时崩溃（initState/dispose 改 provider、go_router 栈摘空、暴露内部 ID），详见 [spec](modules/chat/specs/chat-breadcrumb-nav.md) + [war-story](war-stories/flutter/2026-07-09-chat-breadcrumb-nav-crashes.md) |
| 选区工具栏分支 + 复制即清选区 | chat | ✅ 完成 | 2026-07-09 | [README](modules/chat/README.md) | — | `lib/ui/core/shared/clips_context_menu.dart` + `lib/ui/core/shared/selection_state.dart` + `lib/ui/features/chat/chat_screen.dart` | 选区菜单（复制 / 全选 / 分支 / 放入抽屉）新增「分支」按钮，从活跃选区即时分支（读 `branchFromSelectionProvider`）；复制 / 放入抽屉 / 分支消费选区后即清除全局选区状态，避免分支预览残留已取消的选区；「更多 → 分支」改传 `selectedText: null`；详见 [war-story](war-stories/flutter/2026-07-09-chat-selection-residual-branch-preview.md) |

### 联网搜索

KIMI、MIMO、DeepSeek、豆包（模型级）支持原生联网搜索。**MiniMax 在 `webSearchSupportMap` 中为 `unsupported`**（2026-07-17 止血：官方需 Anthropic Messages 服务端工具 `web_search_20250305`，当前客户端未接，避免 UI 假支持）。聊天输入框底部联网搜索开关（地球图标）：支持的提供商默认开启、可手动关闭；不支持的提供商按钮变灰不可点击。

各提供商实现方式：
- KIMI：`builtin_function.$web_search` 工具（自动禁用 thinking）
- MIMO：`web_search` function 工具
- DeepSeek：Anthropic 兼容接口 `web_search_20260209` 工具（**全量走 Anthropic 协议**，不仅 web search）
- 豆包：Responses API 内置 `web_search`（旧无日期后缀 Seed-2.0-pro 由 `isModelWebSearchUnsupported` 屏蔽）
- MiniMax：UI / 发送侧不启用；真实现见 TECH-DEBT「MiniMax 真实联网」

用户偏好持久化在 FlutterSecureStorage（key: `web_search_enabled_{providerType}`）。

## 4. 搜索模块（search）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 全文搜索 | search | ✅ 完成 | 2026-06-22 | [README](modules/search/README.md) | — | `lib/ui/features/search/search_screen.dart` | SearchScreen UI + SearchService (SQLite FTS5) 已实现，索引修复流程已集成；搜索 tab 走显式搜索按钮（非 live），笔记 tab 仍 live |
| 搜索功能设计 | search | ✅ 完成 | 2026-06-05 | [README](modules/search/README.md) | — | `docs/modules/search/specs/2026-06-05-搜索功能-design.md` | 完整设计 spec |

## 5. LLM 模块（llm）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| LLM Provider 管理 | llm | ✅ 完成 | 2026-06-20 | [README](modules/llm/README.md) | [README](modules/llm/visual/README.md) | `lib/ui/features/llm/llm_providers_screen.dart` 等 | 多 Provider + API Key 配置 + 模型数量列表 + pane 式子页 |
| LLM 模型列表获取 | llm | ✅ 完成 | 2026-07-05 | [README](modules/llm/README.md) | — | `lib/data/services/model_fetcher.dart` | ModelFetcher 对 doubao 返回白名单 Seed 系列模型（3 个），不再从 /models API 全量拉取 |
| 统一 LLM 错误处理与重试 | llm / chat / _shared | ✅ 完成 | 2026-06-24 | [README](modules/llm/README.md) | — | `lib/data/models/llm_error.dart` + `lib/ui/core/widgets/llm_error_card.dart` | LlmError 模型（7 种分类 + fromException 工厂 + 异步上报）+ LlmErrorCard 组件（compact / 占位卡片）+ 4 场景接入（流式聊天 / summarize / 标题生成 / 模型列表）；5 个集成测试 case 全绿 |

## 6. 设置模块（settings）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 设置页 | settings | ✅ 完成 | 2026-06-28 | [README](modules/settings/README.md) | [README](modules/settings/visual/README.md) | `lib/ui/features/settings/settings_screen.dart` 等 | 大模型入口 + 默认模型配置页 + 独立模型选择页；**2026-06-28 起入口从底部 tab 移至搜索页顶栏右上角齿轮按钮**（详见 [CHANGELOG](CHANGELOG/2026-06-28-settings-out-of-tabbar.md)） |
| 生物认证（Face ID） | settings | ✅ 完成 | 2026-06-17 | [README](modules/settings/README.md) | — | `lib/data/services/biometric_service.dart` | BiometricService + AuthGate + WidgetsBindingObserver，进前台弹验证 |
| 分享功能 | settings | ✅ 完成 | 2026-07-08 | [README](modules/settings/README.md) | — | `lib/data/services/share_service.dart` | ShareService.shareAsImage 将问答对渲染为 PNG 图片并调起系统分享面板（offscreen 渲染 → `Share.shareXFiles()`） |
| 备份与恢复 | settings | ✅ 完成 | 2026-07-08 | [README](modules/settings/README.md) | — | `lib/ui/features/backup_restore/backup_restore_screen.dart` + `lib/data/services/auto_backup_service.dart` + `lib/data/services/export_service.dart` + `lib/data/services/import_service.dart` | 自动备份（24h 前台补偿，本地保留 7 份）；手动备份并分享；导入支持覆盖/合并；分享提醒独立周期（3/5/7/14 天可调），仅“分享出去”刷新提醒日期 |
| 语音播放 | settings | ✅ 完成（iOS only） | 2026-06-17 | [README](modules/settings/README.md) | [语音播放设计](modules/settings/specs/2026-06-05-语音播放功能-design.md) | `lib/ui/features/settings/tts_player_screen.dart` 等 | v1.1 上线：iOS 原生 AVSpeechSynthesizer，5 层架构（Plugin→Service→Controller→UI），单条消息互斥，语速不持久化、声音持久化；3 层背景（base + radial ambient + per-message tint）+ 4 类动效（波形/脉冲环/glow shift/文字渐入）；scroll 浮按钮解决长文本回顶；Android 平台用 NoOpTtsService 静默桩。v2+ 路线图见设计 doc 第 11 节 |

## 7. 跨模块（_shared / 基础设施）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 本地持久化 | _shared | ✅ 完成 | 2026-06-06 | — | — | `lib/data/services/file_write_queue.dart` + `lib/data/services/app_database.dart` | Markdown 正文 + SQLite 元数据/关系 |
| 国际化 | _shared | ✅ 完成 | 2026-06-07 | — | — | `lib/l10n/` | flutter_localizations，中英双语，持续更新中 |

## 8. Lab 模块（lab）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| Lab tab 入口 | lab | ✅ 完成 | 2026-07-04 | [README](modules/lab/README.md) | — | `lib/ui/features/lab/lab_placeholder_screen.dart` + `lib/ui/core/router.dart` | tab bar 4→5（搜索/主题/笔记/**Lab**/设置）+ `LabPlaceholderScreen` 功能块卡片布局（`_FeatureCard` 组件）+ `lab_bg_with_title.png` 覆盖灵动岛 + 状态栏深色背景（`#0F1035`）+ 支持滚动 + `AppIcons.lab`（sf_flask）+ 中英 l10n（统一 "Lab"）；子功能候选详见 commit `31b201d` |
| 关键词排行榜 | lab | ✅ 完成 | 2026-07-02 | [README](modules/lab/README.md) | — | `lib/ui/features/lab/keyword_ranking/` + `lib/data/services/keyword_*.dart` | LLM 提取关键词 → 自动/手动分类 → 聚合评分 → 排行榜展示；leaf 状态机（pending/fresh/stale），fresh 禁用选择不浪费 API；provider fallback 遍历所有已配置 key 的提供商；详见 [CHANGELOG](CHANGELOG/2026-07-02-keyword-ranking-fixes.md) |
| 用户输入总结 | lab | ✅ 完成 | 2026-07-08 | [README](modules/lab/README.md) | — | `lib/ui/features/lab/user_input_summary/` + `lib/data/services/user_input_summary_service.dart` | 扫描用户历史输入（支持 7/14/30/90 天范围），LLM 生成 Markdown 分析报告，支持缓存持久化 |
| 思维碰撞 | lab | ✅ 完成 | 2026-07-08 | [README](modules/lab/README.md) | — | `lib/ui/features/lab/thinking_collision/` | 从关键词排行榜随机配对（优先跨主题配对），LLM 异步生成一句话摘要，点击碰撞对创建新对话节点并跳转 |

## 9. 文档拆分模块（doc_split）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 文档拆分（Doc Split） | doc_split | ✅ 完成 | 2026-07-08 | — | — | `lib/ui/features/doc_split/doc_split_input_screen.dart` + `lib/data/services/doc_split_service.dart` | 将 Markdown 文档通过 LLM 拆分为树形对话节点；从主题详情页导航栏入口触发 |

> **架构说明**：Doc Split 是一个跨模块功能，UI 入口在 `doc_split_input_screen.dart`（输入层），实际 AI 处理和节点物化由 `DocSplitService.materializeTree()` 完成（在 `chat_screen.dart` 的 `_onSubmitDocSplit` 中调用）。流程：主题详情页点击拆分按钮 → 输入文本 → 跳转 chat 页让 LLM 生成树结构 → 用户确认提交 → `DocSplitService` 解析 Markdown 树、创建节点链、删除临时 chat 节点。

## 10. 关于模块（about）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 关于页面 | about | ✅ 完成 | 2026-07-08 | — | — | `lib/ui/features/about/about_screen.dart` | App 名称/版本/开发者联系方式展示，从搜索页左侧菜单进入 |

---

## 最近变更

> 倒序排列，最新在上。

- **2026-07-17** — MiniMax 联网止血：`webSearchSupportMap[minimax]` → `unsupported`；UI 与发送侧不再启用假 function `web_search`。真实现仍欠 Anthropic 服务端工具 `web_search_20250305`（见 [TECH-DEBT](TECH-DEBT.md) / [llm README](modules/llm/README.md)）。
- **2026-07-17** — 树页节点标题搜索：`ThemeDetailScreen` 顶部 `CupertinoSearchTextField`，按 `NodeEntity.title` 本地 substring 过滤（`visibleNodeIdsForTitleQuery`）；命中保留祖先；搜索态强制展开、禁用拖拽；l10n `treeTitleSearchHint` / `treeTitleSearchNoResults`；`test/tree_title_filter_test.dart`。与全局 Search tab（FTS）无关。
- **2026-07-08** — FEATURES.md 对齐扫描：补充 10 个代码已实现但文档未记录的功能（Doc Split 模块、用户输入总结、思维碰撞、对话目录、聊天内搜索、用户问题列表、Context Usage Bar、备份与恢复、关于页面）；修正分享功能状态（"部分实现"→"完成"）；新增 doc_split、about 两个模块节。
- **2026-07-08** — Seed-2.0-pro 模型 ID 修正：白名单 `doubao-seed-2-0-pro` → `doubao-seed-2-0-pro-260215`（ARK API 要求带日期后缀）；`isModelWebSearchUnsupported` 改为仅屏蔽无后缀旧模型；`webSearchSupportMap` 豆包改 `supported`。详见 [CHANGELOG](CHANGELOG/2026-07-08-model-capabilities-and-thinking-fixes.md)
- **2026-07-02** — Keyword Ranking 修复汇总 + Chat 表格工具栏：(1) `KeywordGlobalFile.fromJson` 兼容 keywords 为 Map 或 List；(2) keyword analysis provider fallback 遍历所有已配置 key 的提供商；(3) keyword detail 路由修复（补 `/tree` + URL 编码 + 跳转 chat 而非 theme detail）；(4) fresh leaf 禁用选择（UI 灰掉 + 全选/分析跳过）；(5) Chat 表格工具栏：每张 table 顶部独立复制/全屏按钮（`_TableWithActions`，通过 `tableBuilder` 回调包裹）。详见 [CHANGELOG](CHANGELOG/2026-07-02-keyword-ranking-fixes.md)
- **2026-07-06** — DeepSeek / MiniMax 思考过程输出 + Per-session 深度思考开关 + 重发 bug 修复：(1) ClaudeClient 流式响应补全 `thinking_delta` 解析（修复 DeepSeek-reasoner / Claude reasoning 思维链看不见的 bug，详见 [ADR-021](DECISIONS.md#adr-021-claudeclient-流式响应补全-thinking_delta-解析)）；(2) 新增 `ModelCapability.deepThinking`（用户可控 toggle：DeepSeek V4-Pro / V4-Flash / `deepseek-reasoner` / MiniMax-M3）+ `ModelCapability.alwaysThinking`（服务端锁定默认开：豆包 Seed 2.1-pro / turbo）双 capability 区分；(3) ChatComposer 镜像 web search chip 模式新增"深度思考"chip + "深度思考（默认）"只读 chip；(4) `retryLastMessage` 抽 `_triggerLlmStream` helper，避免重发重复追加 user 消息；(5) 移除 `doubao-seed-2-0-lite-250528`（方舟 ARK 端 250528 版本 Lite 模型在用户账户不可达，留着会引导用户到死路径）。详见 [ADR-022](DECISIONS.md#adr-022-per-session-深度思考开关--双-modelcapability-区分) + [ADR-023](DECISIONS.md#adr-023-retrylastmessage-重构避免重发重复追加-user-消息) + [CHANGELOG](CHANGELOG/2026-07-06-deepthinking-toggle.md)
- **2026-07-05** — 豆包模型白名单过滤 + 模型搜索焦点修复：(1) `ModelFetcher` 为 doubao 新增 `_fetchDoubaoModels()` + `_doubaoWhitelist`，只返回 3 个 Seed 系列模型（pro/turbo/lite），不再走 /models API 全量拉取；(2) `ModelSelectorPanel` 搜索无结果时搜索栏不再被卸载，焦点不再跳到 message input box（空状态改为仅替换列表区域）；(3) `model_capabilities.dart` 新增 Seed 系列精确 vision 映射。详见 [CHANGELOG](CHANGELOG/2026-07-05-chat-model-search-doubao.md)
- **2026-07-05** — Chat 图片上传功能：(1) `ChatComposer` 底部新增图片按钮（`_ImageButton`），支持的模型显示蓝色、不支持变灰；(2) 点击弹出 ActionSheet 选择"拍照"或"从相册选择"，`image_picker` 集成（iOS `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` 权限）；(3) `ChatController.sendUserMessage` 转发 `imageData`/`imageMimeType` 到 `ChatTaskService.startTask`；(4) `_read()` 新增 `_mergeImageData()` 合并 in-memory 图片数据，防止轮询刷新丢失；(5) `MessageBubble` 渲染用户消息图片（缩略图 + 点击全屏预览）。详见 [CHANGELOG](CHANGELOG/2026-07-05-chat-image-upload.md)
- **2026-07-04** — 笔记模块新增 3 个功能：(1) Chat-to-Note — assistant 消息"存为笔记"按钮（`onSaveToNote`），自动用当前主题创建笔记并跳转 `NoteEditorScreen`，主题不存在时自动创建同名主题；(2) LLM 生成标题 — `GenerateTitleScreen`（286 行），复用 `TitleSuggestionService` 生成备选标题列表，支持自定义输入 + 点选确认；(3) 笔记转移主题 — `NoteStore.moveNote` 跨目录迁移（frontmatter themeId 更新 + 文件物理移动），`NoteDetailScreen` 更多菜单新增"转移主题"入口。对话模块同步新增：消息时间戳（`formatMessageTime`，assistant 消息气泡上方显示人类可读时间）、`MessageBubble.onSaveToNote` 回调。主题模块：`ThemeDetailScreen` NavBar 刷新按钮改为 overflow menu（`⋯` + CupertinoActionSheet，含刷新 + 折叠/展开全部）。
- **2026-06-29** — 笔记编辑器标题必填校验：`NoteEditorScreen` ✓ 按钮加 `trim().isEmpty` 拦截（`_titleController.text.trim().isEmpty`）→ 弹 `titleCannotBeEmpty` ThkAlert（单"确定"按钮）→ `return;`（不调 `_saveNow` 不 `pop`）。l10n 新增 `titleCannotBeEmpty`（zh: 标题不能为空，请输入后再保存 / en: Title cannot be empty, please enter a title before saving）。覆盖笔记 Tab `+` 新建和详情页编辑入口（单点修复）；已有空标题笔记的历史数据不动。新增 `integration_test/note_title_required_test.dart`（5 个 case）。详见 [CHANGELOG](CHANGELOG/2026-06-29-note-title-required.md) + [notes/CHANGELOG 第 11 节](modules/notes/CHANGELOG.md#11-笔记标题必填校验2026-06-29)
- **2026-06-29** — 空白分支 chat 流式结束后自动生成 title 并持久化：`AutoTitleController`（`lib/ui/features/chat/auto_title_controller.dart`，按 `nodeId` family）从 widget 抽离生成任务，3 层守卫（state 去重 / currentTitle 改过跳过 / DB title 兜底）+ `ref.keepAlive()` 保活（提前 pop 回 tree 也能后台完成）+ 写 DB + refresh `themeDetailControllerProvider(themeId)` 树。`chat_screen` 增加 `ref.listen<AsyncValue<AutoTitleState>>` 同步 `_displayedTitle`，监听 `failed + error=='noModel'` 弹 `showLlmSetupAlert`。集成测试 `integration_test/branch_creation_test.dart` 加 case 9.5（空白分支 E2E 自动 title）+ 激活 case 9.4（DB check 守卫），新增 case 9.6（提前 pop 后台完成）。详见 [ADR-018](DECISIONS.md#adr-018-Notifier-后台任务保活autoDispose--build-内-refkeepalive-双标记范式) + [CHANGELOG](CHANGELOG/2026-06-29-auto-title-persistence.md) + [war-story](war-stories/flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md)
- **2026-06-29** — Lab tab 视觉规范化：tab label 中英文统一为 "Lab"（`app_zh.arb::labTabLabel` "实验室" → "Lab"），`LabPlaceholderScreen` 改为白底（`AppColors.surface`）兜底 + 顶部 hint 文字 + 下方 `assets/background/lab_bg_32pt.png` 装饰图（`BoxFit.contain` 保持比例，不撑满）。集成测试 `integration_test/lab_tab_test.dart` 断言同步。详见 [CHANGELOG](CHANGELOG/2026-06-29-lab-tab-white-bg.md)
- **2026-06-28** — Lab tab 上线 + tab bar 改红：`lib/ui/features/lab/lab_placeholder_screen.dart`（占位页）+ `AppIcons.lab`（sf_flask）+ `assets/icons/lab_selected.png` / `lab_unselect.png` + tab bar 4→5（搜索/主题/笔记/**实验室**/设置）+ 主题 tab 未选图标换 svg（`assets/icons/theme_unselect.svg`）+ 顶栏背景色临时用 `AppColors.destructive`（#DC2626）。新增 `integration_test/lab_tab_test.dart` + `theme_tab_icon_test.dart`；新增依赖 `flutter_svg: ^2.0.10`。详见 [CHANGELOG](CHANGELOG/2026-06-28-lab-tab-and-bar-red.md) + [ADR-017](DECISIONS.md#adr-017-实验室-tab-上线--tab-bar-结构调整--flutter_svg-引入)
- **2026-06-28** — 设置入口从底部 tab 移出：底部 tab 由 4 个（搜索 / 主题 / 笔记 / 设置）变为 3 个（搜索 / 主题 / 笔记）；设置入口迁至搜索页顶栏右上角齿轮按钮（`SFIcons.sf_gearshape` = `AppIcons.settings`），点击 `context.push('/settings')` 进入设置页。`/settings` 由 StatefulShellBranch 提升为外层 `GoRoute`（`parentNavigatorKey: _rootNavigatorKey`），与 `/llm-providers` 同层（共享返回栈语义）。复用 `l10n.settingsTabLabel`（虽然其字面含义是「设置 tab」但作为「设置入口」文案继续可用，不新增 key）。新增 `integration_test/search_settings_button_test.dart`（1 个 case）。详见 [CHANGELOG](CHANGELOG/2026-06-28-settings-out-of-tabbar.md)

- **2026-06-26** — 对话页模型选择面板交互简化：移除面板内的关闭按钮（X 按钮及按钮所在行），改为点击 panel 外部（消息列表 / context bar / 输入框 / 标题栏空白）关闭 panel。`Stack + Listener + Positioned.fill` 透明遮罩方案；`ChatComposer` 用 `Listener(onPointerDown)` 避免与 `TextField` 的 `TapGestureRecognizer` 在 arena 中冲突。详见 [CHANGELOG](CHANGELOG/2026-06-26-chat-model-panel-dismiss.md)

- **2026-06-24** — 统一 LLM 错误处理与重试：新增 `LlmError` 模型（7 种错误分类 + `fromException` 工厂 + 异步上报 AppLogger）+ `LlmErrorCard` 组件（compact 横条 + 占位卡片）+ 4 场景统一接入（流式聊天 `ChatTaskService` / 标题生成 `TitleSuggestionScreen` / summarize 模式 / 模型列表 `LlmProviderDetailScreen`）；新增 `integration_test/llm_error_retry_test.dart`（5 个 case 全绿）。详见 [CHANGELOG](CHANGELOG/2026-06-24-llm-error-retry.md)

- **2026-06-24** — 笔记 tab 顶部搜索统一为全文搜索：`SearchContent` 组件抽离（`lib/ui/features/search/search_content.dart`），`SearchScreen` + `NoteBrowseScreen` 共用同一搜索能力（FTS5 + BM25 + 防抖 300ms + 跨模块跳转）；空查询显示主题分组，非空查询显示全文搜索结果。明确放弃主题名搜索能力（接受 FTS5 schema `themeTitle UNINDEXED` 事实）。新增 `integration_test/note_search_test.dart`（4 个 case），详见 [CHANGELOG](modules/notes/CHANGELOG.md#10-笔记-tab-顶部搜索统一为全文搜索2026-06-24)

- **2026-06-24** — 分支创建 sheet filter 漏洞修复 + LLM 未配置死路防护：`_ModelSelectorSheet.build` 移除内嵌 `apiKey` 校验（与 SettingsStore 不一致会漏掉未配置 provider） + 三层防御拦截 LLM 未配置（`llm_setup_check.dart`）：L1-A（`showBranchFlow` 入口拦死路 A：summarize 解析失败）→ L1-B（`TitleSuggestionScreen.initState` 拦死路 B：sheet filter 空早期）→ L2（`_showModelSelectorAndGenerate` 调用方 filter 空时弹框引导） + line 891 升级为兜底中的兜底。跳转目标精细化：`noProviderConfigured` → `LlmProvidersScreen`；`noTitleModelConfigured` / `noSummaryModelConfigured` → `DefaultModelPickerScreen`。详见 [CHANGELOG](CHANGELOG/2026-06-24-branch-model-selector-filter.md)
- **2026-06-22** — iOS LLM 流式中断恢复落地：`ChatTaskService`（服务层）+ `ChatController`（UI 同步层）分层重构 + iOS `BackgroundTaskHandler`（Swift MethodChannel + `beginBackgroundTask` 30s 续命）+ `BackgroundTaskBridge`（Dart 端桥接）+ `SessionStore.findInterrupted`（扫磁盘 `<!-- streaming -->` 标记）+ AppLifecycleObserver 冷启动恢复 + `chat_async_recovery_test.dart` 集成测试（4 个 testWidgets 全绿）。详见 [ADR-015](DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界) + [集成测试 spec](_shared/integration-testing/chat-async-recovery.md)
- **2026-06-20** — `ChatController.onDone` stop_button 卡死 bug 修复：fire-and-forget 错误日志（`_safeLogError`，`logger.await` 不再阻塞清理路径）+ 立即清 `_handle` / `_cancelToken` 让 `_read()` 自愈逻辑生效 + 兜底 `_read()` 三层防线
- **2026-06-20** — LLM 测试 Key 注入方案:从 assets 迁移到 dart-define(Key 不进 release 包,新增 `tools/gen_dart_define.dart` 生成器压缩 JSON,集成测试命令加 `--dart-define-from-file=build/dart_define.json`,见 [CHANGELOG](CHANGELOG/2026-06-20-llm-test-config-redesign.md))
- **2026-06-20** — LLM 设置链路 UI 收敛:设置页改为"大模型"入口,子页采用 inline title + fill pane 布局,默认模型选择改为独立单选页
- **2026-06-20** — `MessageBubble._TableExpandedView` LaTeX 渲染补全：与主消息体一致注入 `latexBuilder: buildLatex` + `useDollarSignsForLatex: true`，修复"主消息体可看、点开表格后 LaTeX 不渲染"的体验不一致
- **2026-06-20** — 单测文件全量清理：`pubspec.yaml` 移除 `flutter_test` 直接依赖，`test/` 目录 13 个单测文件全部删除（约 1100 行），与项目"集成测试优先 + 禁止凑覆盖率"约定一致
- **2026-06-17** — 笔记详情页 UI 重构：GptMarkdown 标题样式修复、导航栏去掉标题、操作按钮收纳到网格底栏（ThkGridBottomSheet）、内容区填满页面
- **2026-06-17** — Markdown 工具栏增强：标题级别循环切换逻辑 + 表格插入按钮
- **2026-06-07** — 树节点圆圈改为所有节点均显示空心圆（叶子节点不可点击），圆圈与标题间距缩至 0px
- **2026-06-07** — 对话树节点卡片重构：5 套配色方案（nodeId hash 分配），圆圈 toggle 替换 chevron，行高固定 56px，标题 maxLines=1
- **2026-06-07** — 笔记列表页改为 ThkLargeTitlePage + slivers 布局（与主题列表一致）
- **2026-06-07** — 全文搜索功能基本完成（SearchScreen + SearchService + SQLite FTS5 + 索引修复）
- **2026-06-07** — 多处 UI 组件更新：ThkNavBar, ThkListSection, SwipeableRow, MarkdownToolbar, ModelSelectorPanel
- **2026-06-07** — 笔记模块新增 node_location_picker（节点位置选择器）、note_select_screen
- **2026-06-07** — 国际化文件更新（app_en.arb, app_zh.arb + 生成文件）

## 活跃开发区域

- `lib/ui/features/chat/` — `ChatController.onDone` stop_button 自愈 + `MessageBubble` LaTeX 在表格展开视图注入收敛 + `AutoTitleController` 空白分支自动 title 持久化（2026-06-29）
- `lib/data/stores/llm_config_store.dart` — `tmp+rename` 原子写（POSIX `rename` 原子性）+ 防共享引用（`List.from` 复制）
- `lib/ui/features/notes/` — 笔记列表布局优化（Large Title 滚动）
- `lib/ui/features/search/` — 全文搜索功能
- `lib/ui/core/widgets/` — 基础组件持续迭代

---

## 维护约定

- **新增功能**：在对应模块的表格新增一行；填全 8 列。
- **状态变更**：✅ / 🔨 / 📋 之间切换，更新"最后更新"列。
- **跨模块功能**（如持久化、i18n）：归到 `_shared` 模块。
- **AI 维护时机**：AI 改代码时若识别到 `lib/ui/features/<name>/` 下新增文件/方法，**应主动询问**用户是否在本表新增/更新功能行。
- **人类维护**：本表的"状态/最后更新/路径"由人类维护；"说明"列可手动补充。
