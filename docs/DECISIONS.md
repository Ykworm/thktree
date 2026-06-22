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

## ADR-012: 语音播放 UI 交互——独立播放器页面 + 语速不持久化

2026-06-17 决定。语音播放的交互方式从"MessageBubble 内嵌播放/停止按钮"改为"点击播放按钮打开独立播放器页面"。理由有三：单条消息可能很长（Markdown 正文），内嵌按钮无法展示完整文本；语速调节需要滑块控件，MessageBubble 底部空间不足；独立页面让播放控制更聚焦（大按钮、清晰状态）。同时决定**语速不持久化**——每次打开播放器页面默认正常语速（0.5），用户调节仅对当前播放生效。理由：用户每次朗读的语境不同（快速浏览 vs 仔细聆听），固定默认值比记忆上次设置更合理；减少持久化状态，降低复杂度。影响范围：`lib/ui/core/shared/message_bubble.dart`（播放按钮改为打开页面）、`lib/ui/features/settings/tts_player_screen.dart`（新增）、`lib/ui/features/settings/tts_settings_screen.dart`（新增）。实施要点：播放器页面用 `CupertinoPageRoute` push 进入，导航栏返回按钮自动处理；语速滑块范围 0.0~1.0（直接映射 `AVSpeechUtterance.rate`），0.5 为正常语速。

## ADR-013: LLM 测试 Key 改用 `--dart-define-from-file` 编译期注入，放弃 assets 路径

2026-06-20 决定。集成测试需要真实 LLM API Key 才能驱动聊天链路。此前实现把 Key 物理放在 `assets/test_llm_config/test_llm_config.json`，通过 `pubspec.yaml` 的 `assets:` 声明把整个目录打进 Flutter bundle；测试代码用 `rootBundle.loadString` 读。这导致 `flutter build ipa --release` 会把真 Key 烤进 `.app`，可以 `unzip + grep` 直接还原。`.gitignore` 只解决"不提交"，不解决"不进 release 包"——这是两个独立维度，需要独立机制。详见 [docs/_tmp/2026-06-20-llm-test-config-redesign.md](../_tmp/2026-06-20-llm-test-config-redesign.md)。

改用 Flutter 3.7+ 的 `String.fromEnvironment('TEST_LLM_CONFIG_JSON')` 编译期常量读取，通过 `--dart-define-from-file=<path>` 传 Key 字符串。**Key 不进任何 bundle / `.app` / `.apk` / `.ipa`，只存在于开发者本机的 JSON 文件里**（推荐 `~/.thktree/test_llm_config.json`，工程外、不入仓）。代码入口 `LlmTestConfig.loadFromDefine()` 是同步方法（编译期常量天然同步）；旧 `loadFromAsset()` 标记 `@Deprecated` 保留一个版本作为逃生通道——如果 dart-define 遇到 Flutter 平台问题可临时回退，但生产 release 构建禁止使用。

影响范围：删除 `tool/test_llm_config.{json,example.json}` 与 `assets/test_llm_config/` 整目录（4 个文件）；修改 `pubspec.yaml` 移除 `assets: - assets/test_llm_config/` 声明、`.gitignore` 移除两条规则、`integration_test/_support/llm_test_config.dart` 重构加载器（新增 `loadFromDefine` + 抽取 `_parse` 共享解析器）、`integration_test/theme_chat_e2e_test.dart` 改用同步 `loadFromDefine()`、6 个文档（5 个集成测试 .md + 1 个 LLM 模块说明）同步加载示例与运行命令。集成测试运行命令从 `flutter test integration_test/` 变为带 `--dart-define-from-file=~/.thktree/test_llm_config.json`。

放弃"零配置即可跑测试"的便利（过去只要 clone 仓库 + 填一个 JSON 即可），换取"Key 物理不泄露"。集成测试运行门槛小幅提高（开发者需在 `~/.thktree/` 自维护一份 JSON），但消除了 release 泄露的真实安全风险。实施要点：静态隔离验收是硬性要求——必须 `flutter build ipa --release` 后 `unzip + grep` 验证 ipa 中不含 `test_llm_config` 或 `sk-` 前缀；错误路径验收是硬性要求——不传 `--dart-define-from-file` 时必须给出明确错误信息（`StateError: LLM 测试配置未注入...`），不能沉默失败；逃生通道 `loadFromAsset` 明确标注 `@Deprecated` 文字，生产构建禁用。后续：集成测试 CI 接入是独立任务不在本 ADR 范围（CI 需另设计密钥注入方案）；"Dart 测试自主调 LLM"扩展是独立任务（接口已在 `LlmTestConfig` 持有完整 `providers` / `apiKeys` 映射，可支撑）。

**补充（2026-06-20 验收暴露的两道坑 + 生成器方案）**。第一次实现后，直接用 `flutter test integration_test/theme_chat_e2e_test.dart --dart-define-from-file=~/.thktree/test_llm_config.json` 跑失败，错误是 `FormatException: Scheme not starting with alphabetic character`，指向 `-DTEST_LLM_CONFIG_JSON={`。经二分实验锁定两条根因：第一，`--dart-define-from-file` 只接受 `{"KEY":"VALUE"}` 简单映射，**不是任意 JSON**——开发者本机的 LLM 配置是多层嵌套对象，直接喂过去会让 Flutter 工具链找不到 `TEST_LLM_CONFIG_JSON` 这个 key、**静默返回空字符串**（不报错）；第二，dart-define 的 value 不能含字面换行符（`\n`），`frontend_server` 会把命令行参数当 URI 解析，`resolveInputUri` 碰到换行符直接抛 `FormatException`。第二条根因特别隐蔽，因为开发者本机配置的 JSON 通常是 pretty-print 的，内层一定含 `\n`。解决方案是引入生成器 `tools/gen_dart_define.dart`：读取开发者友好的 pretty-print JSON → `jsonDecode` 解析为对象 → `jsonEncode` 重新压缩为单行紧凑 JSON（去字面 `\n`） → 包成 `{"TEST_LLM_CONFIG_JSON": "<compact>"}` 这种 Flutter 期望的简单映射；输出落 `build/dart_define.json`（`build/` 在 `.gitignore`，不入仓）。开发者运行命令变成两步：`dart run tools/gen_dart_define.dart ~/.thktree/test_llm_config.json build/dart_define.json` 再 `flutter test integration_test/ --dart-define-from-file=build/dart_define.json`。生成器里有安全网——如果 `jsonEncode` 后还含 `\n` 直接 exit 70（EX_SOFTWARE），避免把坏文件传给前端编译器。补充结论：本 ADR 的"集成测试运行命令"已从单条 `flutter test` 命令升级为"先生成 build/dart_define.json,再 flutter test"的两步流程；任务 7 验收文档（[plan 步骤 7](../../superpowers/plans/2026-06-20-llm-test-config-redesign.md)）与 4 个集成测试 .md（chat-streaming / branch-creation / theme-chat-e2e / fixtures）已同步更新。

## ADR-014: DB 一致性保障——统一 disk-first 写入顺序 + 启动轻量同步

2026-06-22 决定。DB 一致性保障机制从"散落在各处的全量 reindex"改为"统一 disk-first 写入顺序 + 启动时轻量 syncFromDisk"。

背景：`getSessionPathForNode` 每次调用都执行全量 reindex（`reindexThemesFromDisk` + `reindexNodesFromDisk`），两者都使用 `db.transaction()`。当两个协程并发调用时（例如第一条消息流式完成后的 `_updateSearchIndex` 和第二条消息的 `sendUserMessage`），嵌套事务崩溃："cannot start a transaction within a transaction"。详见 [war-stories/ui-ux/2026-06-22-sqlite-nested-transaction-crash.md](war-stories/ui-ux/2026-06-22-sqlite-nested-transaction-crash.md)。

决策：三项改动。第一，统一 disk-first 写入顺序——所有操作（create/delete/modify）先写 disk 再写 DB，调换 `updateNodeTitle` 的写入顺序（原来 DB-first）；`renameTheme` 和 `createChatNode`、`deleteNodeSubtree` 已是 disk-first，无需改动。第二，启动时轻量同步——在 `appDatabaseProvider` 初始化时调用 `syncFromDisk()`，扫描磁盘目录 + 读 meta.json，与 DB 比对后只补差异（disk 有 DB 没有 → INSERT，DB 有 disk 没有 → DELETE），不做 DELETE ALL + re-INSERT。第三，移除散落的 reindex——`ThemeDetailController._load()`、`ThemeListController.build()`、`getSessionPathForNode` 中的 reindex 调用全部移除，用启动同步替代。

影响范围：`lib/data/stores/node_store.dart`（新增 `syncFromDisk` + `_collectNodeMeta`，调换 `updateNodeTitle` 写入顺序，移除 `deleteNodeSubtree` 中的 reindex）、`lib/data/stores/theme_store.dart`（新增 `syncFromDisk`）、`lib/ui/core/app_services.dart`（`appDatabaseProvider` 加启动同步）、`lib/ui/features/themes/theme_detail_controller.dart`（移除 `_load` 中的 reindex）、`lib/ui/features/themes/theme_list_controller.dart`（移除 `build` 中的 reindex，`reindex()` 改用 `syncFromDisk`）。

实施要点：`syncFromDisk` 只扫描目录名 + 读 meta.json，不读 session.md 内容，比全量 reindex 轻几个数量级。crash 恢复安全性依赖 disk-first 写入顺序——crash 后 disk 状态总是最新的，启动同步用 disk 覆盖 DB 即可。`reindexThemesFromDisk` 和 `reindexNodesFromDisk` 方法保留但不再在热路径调用，仅作为手动全量重建的逃生通道。

## ADR-015: 分支创建集成测试 4 chat 并行推进——翻转「不实现 case 1-7」旧决策

2026-06-22 决定。原 spec `docs/_shared/integration-testing/branch-creation.md` § 8 隐含一项决策：7 个 testWidgets 全部以「scaffold + 注释 TODO」状态存在，不实际跑通，理由是 SelectionArea 选区构造在 Flutter tester 中难以精确模拟、case 7 需 LLM mock 工具未建。本 ADR 翻转该决策——通过 4 chat 并行推进，case 1/2/3/4 已实跑通过，case 5/6/7 保留 scaffold 状态并明确剩余工作。

背景：4 case 实跑前的「阻塞点」实际是工具/协作问题，不是根本性技术障碍。case 1/3 用 `tester.enterText` + `find.text` 即可构造「选中文本」路径，绕过 SelectionArea 模拟；case 2 同理（selectedText 优先，不走 summarize 路径）；case 4 通过 `--dart-define-from-file` 注入真实 LLM Key（参见 ADR-013）调用 DeepSeek 完成「父对话总结 + 标题生成」双 LLM 任务；3 个 helper（`_createTestTheme` / `_createTestNode` / `_sendMessage`）虽未提取到 `_support/test_fixtures.dart`，但复制到每个 testWidgets 内部仍可工作（不优雅但能跑通）。LLM mock 工具仍是真实阻塞——case 7 没有 Dart-side HTTP mock 通道，无法模拟「LLM 失败」分支，spec § 4.3 提及但未实施。

决策：实施 4 chat 并行推进方案，不在新一轮 worktree 中启动 case 5/6/7 收尾。case 1-4 视为已实跑通过，case 5/6 视为「scaffold 待实跑」（不依赖外部工具，仅需补测试断言），case 7 保留为「scaffold + 待建 LLM mock 工具」（独立前置任务）。4 chat 的具体分工：Chat A = case 1（选中文本 + raw），Chat B = case 2（选中文本 + summarize），Chat C = case 3（无选 + raw），Chat D = case 4（无选 + summarize）。每个 chat 独立 worktree、独立 commit，共享同一 dev 分支作为合并目标。

理由：4 case 实跑证明 spec § 8 的「不实现」判断是过度悲观——SSE 注入路径 + ValueKey 补全 + tester API 组合足以覆盖核心矩阵。剩余 3 case 不阻塞主流程（cancel/fallback 是边界场景），且 case 7 仍卡在工具链缺口上，单 chat 推进 ROI 低。「翻转决策 + 保留 scaffold」的做法既承认技术进展（4 case 实跑），又诚实标注剩余工作（5/6/7 仍待补），避免「全做完」的认知偏差。

影响范围：`docs/_shared/integration-testing/branch-creation.md`（状态行、§ 2 测试矩阵、§ 10 Checklist 三处更新，commit b20ad1f），`integration_test/branch_creation_test.dart`（4 chat 7 个 commit：5bdf7af / a3ee1e6 / 4e22b1e / 4282c82 / b0790e2 / 545f594 / 32c6b73），8 个 ValueKey 补全（`branch_button` / `branch_mode_summarize_option` / `branch_mode_raw_option` / `branch_mode_continue_button` / `branch_mode_cancel_button` / `title_input` / `confirm_button` / `cancel_button`），3 个 helper 暂未提取（`_support/test_fixtures.dart` 不存在，`send_button` / `stop_button` ValueKey 仍缺，`_sendMessage` 用 if 防御跳过）。

实施要点：4 chat 共享主仓库 dev 分支作为合并目标，每个 chat 在独立 worktree 中完成 case 实现后 rebase origin/dev 再 `--ff-only` 合并；commit message 遵循 `test(branch_creation): case N <场景>` 格式（5bdf7af / a3ee1e6 等），便于按 case 维度回溯。case 5/6/7 启动新一轮 worktree 的前置条件：5/6 只需补 testWidgets 内部 TODO 注释（无外部依赖，可单人 1 个 chat 完成）；7 需要先建 LLM HTTP channel mock 工具（独立任务，可单独起 worktree）。

## ADR-016: iOS LLM 流式中断恢复策略——disk-first + 自动重发 + 30s 边界

2026-06-22 决定。用户在 iOS 上聊天时将 APP 切后台、iOS 进入挂起（suspend）状态、然后切回前台，这条高频路径下 LLM 流式回复必须能"无感接续"或"优雅重发"。背景与决策细节见 [集成测试 spec](_shared/integration-testing/chat-async-recovery.md)。

背景：iOS App Store 审核对 `UIBackgroundModes` 严控；LLM provider（OpenAI / Claude / Gemini / DeepSeek）均不支持 SSE 流式 resume；`beginBackgroundTask` 提供硬上限 ~30s 的 process 续命窗口。结合三条限制得出"分层兜底"策略——**disk 是真相，桥接是薄壳，串行重发是收敛**。

决策：四项硬约束。第一，**disk-first 真相源**——`session.md` 的 `<!-- streaming -->` 标记同时承担"流式中间态语义"（见 storage-format.md § 4.4）和"后台恢复入口"两个角色；`SessionStore.findInterrupted()` 扫描磁盘找到带该标记的 node，`ChatTaskService.resumeInterrupted()` 把它们入队。第二，**自动重发（不伪装 resume）**——LLM 不支持 SSE resume，切回时若流已关闭则全量重发；已生成 assistant 内容作为 history 附在新请求中。第三，**30s 边界**——短回复（< 30s）由 iOS `beginBackgroundTask` 真在后台跑完、切回时流仍存活 → 无缝接续渲染；长回复（≥ 30s）iOS 挂起 process、流被冻 → 检测到流已关闭 → 自动重发。第四，**iOS 合规边界**——不引入 TTS/audio background mode、不使用 VoIP push 做非 VoIP 用途、不使用 silent push 保活；仅依赖 `beginBackgroundTask` 的 30s 续命窗口（Info.plist 加 `UIBackgroundModes=processing` 仅为审核友好）。

分层架构：Dart 端三层 + iOS 原生一层。`BackgroundTaskBridge`（`lib/data/services/background_task_bridge.dart`）封装 MethodChannel 调用（`beginBackgroundTask` / `endBackgroundTask`），抽象成 `Future<String> begin()` + `Future<void> end(taskId)`，**可注入**（test 时换 `_CountingBridge` 计数验证）；`BackgroundTaskHandler`（Swift，`ios/Runner/BackgroundTaskHandler.swift`）实现 MethodChannel handler + `UIApplication.beginBackgroundTask` 调用 + `expirationHandler` 释放；`ChatTaskService`（`lib/data/services/chat_task_service.dart`）是核心调度器，负责串行 queue + generation token（cancel 时 generation 自增让 loop 退出）+ bridge.begin/end 包裹 + `resumeInterrupted()` / `cancelResumeQueue()` 入口；`ChatController`（`lib/ui/features/chat/chat_controller.dart`）保持 UI 同步层职责（监听 Riverpod state、绑定 Widget），续传/重发决策**不下沉到 widget**。

并发策略：切回时扫到 N 个未完成 → **串行排队重发**（一次 1 个，跑完/失败/用户停止 才下一个），不并发——避免 LLM provider rate limit 与用户认知负担。可后续调为并发上限 = 2。

影响范围：`ios/Runner/Info.plist`（`UIBackgroundModes=processing`）、`ios/Runner/AppDelegate.swift`（注册 `BackgroundTaskHandler` MethodChannel）、`ios/Runner/BackgroundTaskHandler.swift`（新增 MethodChannel handler）、`ios/Runner.xcodeproj/project.pbxproj`（Swift 文件加到 target）、`lib/data/services/background_task_bridge.dart`（新增 MethodChannel 客户端）、`lib/data/services/chat_task_service.dart`（新增后台中断恢复服务）、`lib/data/services/session_store.dart`（新增 `findInterrupted()`）、`lib/main.dart`（`AppLifecycleObserver` 冷启动恢复 + 切回前台触发）、`lib/main_test.dart`（`extraOverrides` 暴露 ProviderContainer override 给集成测试）、`lib/ui/features/chat/chat_controller.dart`（分层重构为 UI 同步层）、`lib/ui/features/chat/chat_screen.dart`（无功能改动，仅接续 Riverpod state）、`integration_test/chat_async_recovery_test.dart`（新增，4 个 testWidgets：findInterrupted 扫描 / resumeInterrupted 串行入队 / cancelResumeQueue 清空 / startTask bridge.begin/end 计数）。

实施要点：`bridge.begin/end` 必须配对调用——bridge 实现不保证 taskId 自动释放（依赖 `expirationHandler`），ChatTaskService 要在 `onDone` / `onError` / 用户主动停止三条路径都 end。串行 queue 用 `Stream` + `await for` 实现而非 `Timer.periodic`（避免退避时序假设）。`findInterrupted` 必须只扫描 `<!-- streaming -->` 标记，不含 `<!-- error: ... -->`（错误态属于"已结束"语义，不是中断）。`generation` token 自增保证 cancel 后正在跑的任务能被 loop 退出条件识别——**不要复用 `_handle` / `_cancelToken` 这种流式接口的取消机制**，那是 UI 同步层的事。

放弃的方案：B 局部重发（保留"接续"语义需要 LLM 支持 SSE resume，目前不支持）；C 显式重发（用户每次切回都要点一次"重发"，违反最少打扰偏好）；后台保活手段 = TTS/audio/VoIP push/silent push（全部被 iOS 审核明令禁止）。放弃"零配置即可跑测试"的便利（集成测试需额外 override `backgroundTaskBridgeProvider`）换取"可验证的串行重发 + bridge.begin/end 配对"。
