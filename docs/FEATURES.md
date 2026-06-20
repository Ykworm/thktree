# 功能状态总表

> **维护者**：人类 + AI 共同维护。状态/最后更新/路径由人类手动维护；AI 改代码时若发现 `lib/ui/features/<name>/` 下新增文件/方法，应主动询问用户是否在本表新增/更新功能行。
> **职责**：全局文档导航 + 功能状态一览。一行一个功能，可跳转到对应 README/Visual/代码。

**列说明**：

| 列 | 含义 |
|----|------|
| **Feature** | 功能名（中文） |
| **模块** | 归属模块（与 `lib/ui/features/` 对齐；跨模块标 `_shared`） |
| **状态** | ✅ 完成 / 🔨 进行中 / 🔨 部分实现 / 📋 待开发 |
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
| 汇总预览 | themes | 📋 待开发 | — | [README](modules/themes/README.md) | [theme-detail-design](modules/themes/visual/theme-detail-design.md) | — | 未实现 |
| 祖先上下文总结 | themes | 🔨 部分实现 | — | [README](modules/themes/README.md) | — | `lib/data/services/` | context-summary.md 写入存在，注入对话未完成 |

## 2. 笔记模块（notes）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 笔记功能 | notes | ✅ 完成 | 2026-06-07 | [README](modules/notes/README.md) | [notes-list-design](modules/notes/visual/notes-list-design.md) | `lib/ui/features/notes/note_browse_screen.dart` 等 | NoteBrowseScreen, NoteEditorScreen, NoteDetailScreen, NoteStore |
| Markdown 工具栏增强 | notes | ✅ 完成 | 2026-06-17 | [README](modules/notes/README.md) | — | `lib/ui/core/widgets/markdown_toolbar.dart` | 标题级别循环切换（h2→h3→h1→无）+ 表格插入按钮 |
| 图片插入 | notes | 📋 待开发 | 2026-06-17 | [README](modules/notes/README.md) | — | — | 编辑器工具栏插入图片，支持相册/拍照 |

## 3. 对话模块（chat）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 流式对话 | chat | ✅ 完成 | 2026-06-07 | [README](modules/chat/README.md) | — | `lib/ui/features/chat/chat_screen.dart` | LlmClient + SSE, FileWriteQueue, ChatComposer 优化 |
| 标题自动建议 | chat | ✅ 完成 | 2026-06-17 | [README](modules/chat/README.md) | — | `lib/data/services/title_suggestion_service.dart` | 分支创建时触发，支持选中文本/对话总结/笔记多种来源 |

## 4. 搜索模块（search）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 全文搜索 | search | 🔨 进行中 | 2026-06-07 | [README](modules/search/README.md) | — | `lib/ui/features/search/search_screen.dart` | SearchScreen UI + SearchService (SQLite FTS5) 已实现，索引修复流程已集成 |
| 搜索功能设计 | search | ✅ 完成 | 2026-06-05 | [README](modules/search/README.md) | — | `docs/modules/search/specs/2026-06-05-搜索功能-design.md` | 完整设计 spec |

## 5. LLM 模块（llm）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| LLM Provider 管理 | llm | ✅ 完成 | 2026-06-20 | [README](modules/llm/README.md) | [README](modules/llm/visual/README.md) | `lib/ui/features/llm/llm_providers_screen.dart` 等 | 多 Provider + API Key 配置 + 模型数量列表 + pane 式子页 |
| LLM 模型列表获取 | llm | 🔨 进行中 | — | [README](modules/llm/README.md) | — | `lib/data/services/model_fetcher.dart` | ModelFetcher 存在，模型列表刷新 UI 未完成 |

## 6. 设置模块（settings）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 设置页 | settings | ✅ 完成 | 2026-06-20 | [README](modules/settings/README.md) | [README](modules/settings/visual/README.md) | `lib/ui/features/settings/settings_screen.dart` 等 | 大模型入口 + 默认模型配置页 + 独立模型选择页 |
| 生物认证（Face ID） | settings | ✅ 完成 | 2026-06-17 | [README](modules/settings/README.md) | — | `lib/data/services/biometric_service.dart` | BiometricService + AuthGate + WidgetsBindingObserver，进前台弹验证 |
| 分享功能 | settings | 🔨 部分实现 | — | [README](modules/settings/README.md) | — | `lib/data/services/share_service.dart` | ShareService + ShareCardWidget 存在，分享流程未闭环 |
| 语音播放 | settings | ✅ 完成（iOS only） | 2026-06-17 | [README](modules/settings/README.md) | [语音播放设计](modules/settings/specs/2026-06-05-语音播放功能-design.md) | `lib/ui/features/settings/tts_player_screen.dart` 等 | v1.1 上线：iOS 原生 AVSpeechSynthesizer，5 层架构（Plugin→Service→Controller→UI），单条消息互斥，语速不持久化、声音持久化；3 层背景（base + radial ambient + per-message tint）+ 4 类动效（波形/脉冲环/glow shift/文字渐入）；scroll 浮按钮解决长文本回顶；Android 平台用 NoOpTtsService 静默桩。v2+ 路线图见设计 doc §11 |

## 7. 跨模块（_shared / 基础设施）

| Feature | 模块 | 状态 | 最后更新 | README | Visual | 代码路径 | 说明 |
|---------|------|------|----------|--------|--------|----------|------|
| 本地持久化 | _shared | ✅ 完成 | 2026-06-06 | — | — | `lib/data/services/file_write_queue.dart` + `lib/data/services/app_database.dart` | Markdown 正文 + SQLite 元数据/关系 |
| 国际化 | _shared | ✅ 完成 | 2026-06-07 | — | — | `lib/l10n/` | flutter_localizations，中英双语，持续更新中 |

---

## 最近变更

> 倒序排列，最新在上。

- **2026-06-20** — `ChatController.onDone` stop_button 卡死 bug 修复：fire-and-forget 错误日志（`_safeLogError`，`logger.await` 不再阻塞清理路径）+ 立即清 `_handle` / `_cancelToken` 让 `_read()` 自愈逻辑生效 + 兜底 `_read()` 三层防线
- **2026-06-20** — LLM 设置链路 UI 收敛：设置页改为"大模型"入口，子页采用 inline title + fill pane 布局，默认模型选择改为独立单选页
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

- `lib/ui/features/chat/` — `ChatController.onDone` stop_button 自愈 + `MessageBubble` LaTeX 在表格展开视图注入收敛
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
