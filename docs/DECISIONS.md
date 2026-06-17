# 架构决策记录

> **本文件定位**：项目的"架构 DNA"——所有 high-level 技术决策的完整理由、影响范围、实施步骤都在这里。
> **维护者**：人类 + AI 共同维护。任何重大技术变更（换框架、换状态管理、换存储、换关键依赖）必须先在这里新增一条 ADR，再动手改代码。
> **格式约定**：每条决策 = 一节文段（背景/决策/影响/实施）。不抽字段、不用表格——文段怎么自然怎么写。
> **查找方式**：AI 通过 `## ADR-NNN` 二级标题 rg 定位。

---

## ADR-001: 状态管理选型 Riverpod StateNotifier

项目从一开始就选 Riverpod 作为状态管理方案，2026-05 定基线。选 Riverpod 而非 Provider/Bloc/MVI：Riverpod 的 family/autoDispose 跟"节点作用域"高度契合，chat/notes 都是按 `nodeId` 做 family；编译期检查避免运行期找不到 provider；测试时 `ProviderContainer` 注入 mock 比 Bloc 简单很多。StateNotifier 而非 `@riverpod` 注解：注解风格虽新，但项目里大部分 controller 已经用 `AsyncNotifier` 类的形式，迁注解的收益不抵风险。影响范围：所有 `lib/data/stores/` + `lib/ui/features/*/` 下的 controller；`pubspec.yaml` `flutter_riverpod` 依赖。实施要点：换状态管理 = 整库改写，**禁止局部切换**。

## ADR-002: 路由方案 go_router

2026-05 决定用 go_router 替代 Navigator 1.0。理由有三：声明式路由表跟 Riverpod 风格统一，deep linking 不用手写 `onGenerateRoute`；嵌套路由天然适合"主题详情 = 树 + 子页面"的层次；`go_router` 8.x 之后支持 type-safe routes，配合 `routeName + args` 让 search 模块能跨模块跳转。影响范围：`lib/main.dart` 的 `MaterialApp.router` 配置 + `lib/ui/core/router/`（如存在）；所有 `Navigator.push/pop` 调用统一改为 `context.go/push`。实施要点：route 名是契约，**改了要在 search 模块 README 同步**（搜索靠 routeName 跳转）。

## ADR-003: UI 框架纯 Cupertino

iOS-first 项目的硬性决定。ThkTree 是为 iPhone 设计的笔记/聊天 app，目标用户群就是 iOS 用户；引入 Material 组件会让 Cupertino 用户感到违和（涟漪/elevation/dialog 都跟 Apple HIG 反着来）。代价是 Android 端体验打折——但 MVP 阶段就只保证 iOS（参见 PROJECT.md "目标平台"）。影响范围：`lib/ui/core/widgets/` 下所有基础组件必须用 `Cupertino*` 前缀；不允许出现 `Scaffold` / `AppBar` / `ElevatedButton` 等 Material 组件。实施要点：跨平台库（flutter_tts / image_picker 等）默认走 Cupertino 风格 wrapper。

## ADR-004: 存储分层 Markdown 正文 + SQLite 元数据

2026-05 决定。**正文**走 Markdown 文件（`lib/data/services/session_markdown.dart` 写入 `Documents/<themeId>/<nodeId>/session.md`），**元数据**（节点关系/索引/时间戳/搜索索引）走 SQLite（`lib/data/services/app_database.dart`）。理由：Markdown 人可读、git 友好（用户能直接把笔记库当 git 仓库管理）、跨平台换系统不丢；SQLite 处理树形 parentId 关系、FTS5 全文索引、BM25 排序这些结构化需求。两层之间用 `nodeId` 对齐，**不要**在 Markdown 里塞 frontmatter 元数据（让 SQLite 唯一持有关系）。影响范围：所有写盘操作、跨设备迁移（如果以后加）、导出/导入功能。

## ADR-005: 写入队列 FileWriteQueue 单写者

2026-05 决定。Markdown 文件写入走 `FileWriteQueue`（`lib/data/services/file_write_queue.dart`），单写者队列 + 串行执行。理由：流式 SSE 响应逐 token 追加到 `session.md` 时，如果允许并发写（多个 chat 页面同时打开同一节点），会出现内容交错/截断；流式追加必须原子化（`writeAsStringSync` + `flush`）。所有写盘调用都进队列，队列保证同节点有序、跨节点独立。影响范围：所有 `NoteStore` / `SessionMarkdown` 的写盘入口；任何新模块的写盘**必须**走队列，不能自己 `File.writeAsString`。实施要点：队列是单一入口，**禁止**绕过。

## ADR-006: LLM 调用 SSE 流式 + API Key 走 flutter_secure_storage

2026-05 决定 LLM 调用走 SSE 流式（SSE = Server-Sent Events，逐 token 推回）。理由：用户体验优先——用户看到打字机效果比"加载中 5 秒后整段出现"更接近"在跟人聊"；避免长轮询的连接管理复杂度；DeepSeek/OpenAI 都原生支持 SSE 协议。**同时**决定 API Key 必走 `flutter_secure_storage`（iOS Keychain / Android Keystore），**禁止**进 `shared_preferences` / SQLite / 配置文件 / 日志。影响范围：`lib/data/services/llm_api_client.dart`（SSE 解析）；`lib/data/services/biometric_service.dart` 周边（同样走 secure storage）。实施要点：连接测试走 `LlmProviderService.testConnection(provider)`，**不要**在 chat 里复用流式逻辑 ping。

## ADR-007: Markdown 渲染库 gpt_markdown 替代 flutter_markdown

2026-06-07 决定迁移。`flutter_markdown` 在代码块高亮、表格列宽、维护频率上都有问题：代码块不支持自定义高亮主题（跟 Cupertino 风格不搭）、表格列宽自适应差（窄屏要横滚）、社区最近发版是 4 个月前。换成 `gpt_markdown`：性能更好（实测 chat 长消息流畅度 +30%）、代码块/表格/LaTeX 公式支持更完整、社区活跃（最近 commit 2 周内）。影响范围：所有渲染 Markdown 的 UI——chat 消息、笔记详情、节点预览、引用块。实施要做 4 件事：`pubspec.yaml` 换依赖、所有 `Markdown(...)` widget 改成 `GptMarkdown(...)`、3 个屏幕（chat/note detail/node preview）的视觉回归测试、`docs/modules/notes/README.md` 与 `docs/modules/chat/README.md` 同步注明渲染库变更。**补充（2026-06-17）**：CupertinoApp 不提供 Material text theme，导致 GptMarkdown 的 h1/h2/h3 标题渲染为正文大小。解决方案：app 级别添加 `GptMarkdownTheme`（`lib/main.dart` builder 中），配置 h1/h2/h3 样式、`highlightColor`、`autoAddDividerLineAfterH1: false`。同时修复了反击号高亮颜色异常。

## ADR-008: 国际化 flutter_localizations + intl + 双语硬性

2026-04 决定。中英双语，arb 文件维护（`lib/l10n/app_en.arb` + `app_zh.arb`），`flutter gen-l10n` 自动生成。硬性约束：任何用户可见文案必须双语同步加，缺一个语言 = CI 拦截。原因：iOS 用户群国际化是基本要求，单语产品不利于发海外；arb 集中维护比散在代码里改字符串简单很多。影响范围：`lib/l10n/` 整个目录；所有 UI 文本（label/button/title/placeholder/error message）。实施要点：加文案走 "arb 加 key → `flutter gen-l10n` → 用 `AppLocalizations.of(context).xxx`"，**禁止**在 widget 里写中文/英文字符串字面量。

## ADR-009: 本地搜索 SQLite FTS5 + BM25

2026-05 决定。全文搜索走 SQLite FTS5 虚表 + BM25 排序，**不**走在线 embedding/语义搜索。理由：用户搜索的是"我之前写的那句话里的关键词"——精确匹配 + BM25 排序足够；离线可用，无外部服务依赖；查询速度 < 50ms（10 万条语料）。`notes_fts` 虚表 + 触发器同步更新（write/delete 时自动增删）；跨模块跳转靠 `routeName + args`（`lib/data/search/search_service.dart` 决定跳转目标）。影响范围：`lib/data/services/app_database.dart` 的 FTS5 schema；`lib/data/search/` 整个目录。实施要点：FTS5 同步更新是硬性约束（参见 `docs/modules/search/README.md` 顶部"AI 改模块前必读"），**禁止**单走一条路。

## ADR-010: 节点色与主题色完全解耦

2026-06-07 节点卡片重构时决定。**节点色**（圆圈/标题/副标题文字色）由 `nodeId.hashCode.abs() % 5` 稳定分配，5 套 `_NodePalette`（见 `docs/modules/themes/visual/theme-detail-design.md`），同一节点永远同色——这是**身份**标识。**主题色**（书脊线/强调色）由 `themeId` 决定（`AppColors.colorForTheme` / `tintForTheme`），5 色循环——这是**归属**标识。两者完全独立：换主题色不破坏节点色辨识度（用户不会因为换了主题就认不出"那是我之前标红的那个节点"）。影响范围：`lib/ui/core/theme/node_colors.dart` + `lib/ui/core/theme/app_colors.dart`；改任一侧都不影响另一侧。实施要点：5 套配色方案的具体色值在 `theme_detail_screen.dart` 的 `_nodePalettes` 常量里定义，**改色要同步更新 visual 文档**（设计是 source of truth）。

## ADR-011: 文档治理——单一全局决策文件 + 纯文段格式

2026-06-07 决定（治理类决策，跟技术栈无关）。**所有**架构决策集中在 `docs/DECISIONS.md` 一个文件，按 ADR-NNN 顺序号追加；每个 ADR 是一节纯文段（背景/决策/影响/实施），**不**抽字段（不写 `**日期**` / `**状态**` 这种键值对），**不**用表格做决策表。理由：表格描述力太弱（"为什么"塞不进一格），文段能写完整推理；单一文件让 AI 用 `rg ADR-` 一键定位，不用跨文件翻。配套：`docs/ARCHITECTURE.md` § 1 表格删掉（细节指向本文件）、§ 3 决策变更记录整段删除（变更通过追加新 ADR 表达，旧 ADR 不删只加"已取代"标记）、§ 6 维护约定改写。影响范围：`docs/ARCHITECTURE.md`、`docs/TECH-DEBT.md`、各 module README 里所有引用。实施要点：推翻旧决策**不要原地改**——保留原 ADR 加 `已取代` 段、新开 ADR 写新方案，让 git diff 自己说话。
