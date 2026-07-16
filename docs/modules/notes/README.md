# 笔记模块（notes）

> 笔记是 ThkTree 的**独立内容类型**——可以挂载到主题的任意节点上（作为 `isNote=true` 的 Node），也可以独立浏览/编辑。
> 维护者：人类 + AI 共同维护。

> ⚠️ **AI 改模块前必读**
> 1. **`NoteStore` 是唯一写盘入口**——任何 `Note*.txt` 的写入、读缓存、并发冲突处理都走 `lib/data/stores/note_store.dart`；不要在 widget / 其它 service 里直接走 `File`/`FileWriteQueue`。
> 2. **不许改 `WidgetsBindingObserver`**——应用生命周期与版本号管理仅在 `NoteStore`；别在别处重新订阅 `AppLifecycleState`。
> 3. **l10n 双语硬性**——任何用户可见文案加进 `app_en.arb` + `app_zh.arb` 并跑 `flutter gen-l10n`；少加一个语言 = CI 拦截。
> 4. **节点刷新**走全局版本号（见 `docs/modules/notes/CHANGELOG.md` 第 3 节），不要重新发明新机制。

## 1. 职责

| 屏幕 | 职责 |
|------|------|
| **NoteBrowseScreen** | 所有笔记的浏览入口（Large Title + slivers 滚动布局） |
| **NoteEditorScreen** | 笔记编辑器（Markdown 输入） |
| **NoteDetailScreen** | 笔记详情（只读 + 编辑入口） |
| **NoteSelectScreen** | 笔记选择器（从主题创建对话时选笔记） |
| **NodeLocationPicker** | 节点位置选择器（笔记挂载到哪个节点） |

## 2. 功能列表

> 完整状态见 [`../../FEATURES.md`](../../FEATURES.md) 第 2 节.

| Feature | 状态 | 最后更新 | 备注 |
|---------|------|----------|------|
| 笔记功能 | ✅ 完成 | 2026-06-07 | NoteBrowseScreen, NoteEditorScreen, NoteDetailScreen, NoteStore |
| 笔记搜索 | ✅ 完成 | 2026-06-24 | NoteBrowseScreen 顶部复用 `SearchContent`（FTS5 全文搜索）；空查询显示主题分组，非空查询显示搜索结果。详见 [`../../_tmp/note-search-unify-plan.md`](../../_tmp/note-search-unify-plan.md) |
| Markdown 工具栏增强 | ✅ 完成 | 2026-06-17 | 标题循环切换（h2→h3→h1→无）+ 表格插入 |
| 网格底栏 Action Sheet | ✅ 完成 | 2026-06-17 | ThkGridBottomSheet（圆形图标 + 文字标签） |
| 节点位置选择器 | ✅ 完成 | 2026-06-07 | node_location_picker |
| 笔记选择器 | ✅ 完成 | 2026-06-07 | note_select_screen（主题创建对话入口） |
| **标题必填校验** | ✅ 完成 | 2026-06-29 | NoteEditorScreen ✓ 按钮加 `trim().isEmpty` 拦截 → 弹 `titleCannotBeEmpty` ThkAlert（单"确定"按钮），不调 `_saveNow` 不 pop；详见 [CHANGELOG 第 11 节](CHANGELOG.md#11-笔记标题必填校验2026-06-29) |
| 图片插入 | 📋 待开发 | 2026-06-17 | 编辑器工具栏插入图片 |
| **Chat-to-Note** | ✅ 完成 | 2026-07-04 | assistant 消息"存为笔记"按钮（`MessageBubble.onSaveToNote`），自动用当前主题创建笔记并跳转 `NoteEditorScreen`；主题不存在时自动创建同名主题 |
| **LLM 生成标题** | ✅ 完成 | 2026-07-04 | `GenerateTitleScreen`：复用 `TitleSuggestionService` 生成备选标题列表，支持自定义输入 + 点选确认 |
| **笔记转移主题** | ✅ 完成 | 2026-07-04 | `NoteStore.moveNote` 跨目录迁移（frontmatter themeId 更新 + 文件物理移动），`NoteDetailScreen` 更多菜单新增"转移主题"入口 |

## 3. 代码文件

```
lib/ui/features/notes/
├── note_browse_screen.dart         # 笔记浏览（Large Title + slivers）
├── note_detail_screen.dart         # 笔记详情（网格底栏 Action Sheet + 生成标题 + 转移主题）
├── note_editor_screen.dart         # 笔记编辑器
├── note_select_screen.dart         # 笔记选择器
├── node_location_picker.dart       # 节点位置选择器
└── generate_title_screen.dart      # LLM 生成标题（286 行）
```

依赖：
- `lib/data/stores/note_store.dart`
- `lib/ui/core/widgets/markdown_toolbar.dart`（编辑器工具栏：标题切换 + 表格插入）
- `lib/ui/core/widgets/thk_grid_bottom_sheet.dart`（网格底栏 Action Sheet）
- `lib/l10n/`（笔记相关 l10n key）

## 4. 子文档

| 文档 | 路径 | 说明 |
|------|------|------|
| **Visual 索引** | [visual/README.md](visual/README.md) | 视觉设计入口 |
| 笔记列表设计 | [visual/notes-list-design.md](visual/notes-list-design.md) | NoteBrowseScreen 设计 |
| 笔记详情设计 | [visual/note-detail-design.md](visual/note-detail-design.md) | NoteDetailScreen 设计 |

## 5. 关键设计原则

### 5.1 Large Title 滚动布局

笔记列表采用 `ThkLargeTitlePage` + slivers 布局，**与主题列表一致**。优点：
- 滚动时大标题平滑缩小
- 列表区填满 body（不浪费屏幕空间）
- 跨模块视觉统一

### 5.2 笔记与节点的双向关系

- **笔记 → 节点**：笔记可以挂载到主题树的任意节点上（Node.isNote = true）。
- **节点 → 笔记**：从节点创建笔记时反向生成 Node 实体。
- **独立浏览**：NoteBrowseScreen 不依赖任何主题，独立展示所有笔记。

### 5.3 Markdown 编辑

- 使用 `MarkdownToolbar`（复制/粘贴/标题/列表/链接/代码等）。
- 渲染用 `gpt_markdown`（参见 [DECISIONS.md ADR-007](../../DECISIONS.md#adr-007-markdown-渲染库-gpt_markdown-替代-flutter_markdown)）。
- 自动保存：失焦或返回时写盘。

## 6. 维护要点

- **新增屏幕**：在 `lib/ui/features/notes/` 加 screen，并在本 README 第 3 节 更新文件清单。
- **改交互逻辑**：同步更新 `visual/<screen>-design.md`。
- **笔记 l10n**：新文案先在 `lib/l10n/app_zh.arb` 和 `app_en.arb` 加 key，再生成代码。
- **AI 改代码时**：AI 识别到变动后应**主动**提醒用户检核 FEATURES.md 是否需更新。

## 7. 相关历史

- **2026-07-04** — 新增 3 个功能：(1) Chat-to-Note — assistant 消息"存为笔记"，自动用当前主题创建笔记并跳转编辑器；(2) LLM 生成标题 — `GenerateTitleScreen`（286 行），复用 `TitleSuggestionService`；(3) 笔记转移主题 — `NoteStore.moveNote` 跨目录迁移
- **2026-06-29** — NoteEditorScreen ✓ 按钮加空标题校验（`titleCannotBeEmpty` alert），新增 `integration_test/note_title_required_test.dart`（5 个 case）
- **2026-06-07** — 笔记列表页改为 ThkLargeTitlePage + slivers 布局
- **2026-06-07** — 新增 node_location_picker（节点位置选择器）
- **2026-06-07** — 新增 note_select_screen（笔记选择器）
- **2026-06-07** — visual 文档从 `docs/visual/notes/` 迁至 `docs/modules/notes/visual/`
