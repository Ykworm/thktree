# 笔记模块设计文档

> 笔记（Notes）模块的视觉/交互/数据层设计参考。修改前先读这里。
>
> 与 [`../../../_shared/design-system.md`](../../../_shared/design-system.md) 配套阅读：色彩 token、字体、组件样式以系统文件为准，本目录只描述笔记模块**如何使用**这些 token。

---

## 模块定位

笔记模块是 ThkTree 的"思考沉淀"层：用户从对话中摘录的文本自动落库，也能从零新建。其核心约束：

- **iOS HIG 优先**：所有交互遵循 Apple 设计语言
- **Notion 风格编辑器**：标题与正文一体化编辑
- **零依赖同步**：Markdown + YAML frontmatter 落盘，无云端依赖
- **可被搜索**：保存即更新本地搜索索引
- **笔记 → 对话**：可一键把笔记内容作为 user input 派生出新对话节点

---

## 屏幕地图

```
┌─────────────────────────────────────────────────────────────┐
│  TabBar                                                    │
│  ┌─────┬─────┬─────┬─────┬─────┐                            │
│  │ 主题 │ 笔记 │ 搜索 │ 设置 │     │                            │
│  └─────┴─────┴─────┴─────┴─────┘                            │
└─────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│  NoteBrowseScreen        笔记总览（按主题分组）              │
│  ── 标题栏：ThkNavBar.inline，右上角 ➕ 新建                  │
│  ── 主体：ThkListSection + ThkListTile                      │
│  ── "未分类"主题置顶                                        │
│  ── 点击 → ThemeNoteListScreen                              │
└─────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│  ThemeNoteListScreen     主题内笔记列表                      │
│  ── 大标题：分类名 + previous「笔记」                        │
│  ── 独立 contentCard 行：色徽章 + 标题 + 预览 + 相对时间     │
│  ── SwipeableRow 左滑删除；➕ 当前分类直建                   │
│  ── 点击 → NoteDetailScreen                                 │
└─────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│  NoteDetailScreen        笔记详情/阅读页                     │
│  ── 标题栏：无标题，右侧 🌿分支 / ✏️编辑 / ...更多           │
│  ── ... → ThkGridBottomSheet（复制/重命名/删除）             │
│  ── 阅读态：GptMarkdown 渲染（填满页面）                     │
│  ── 编辑态：CupertinoTextField + MarkdownToolbar             │
│  ── GptMarkdownTheme 全局配置 h1/h2/h3 标题样式              │
└─────────────────────────────────────────────────────────────┘
            │
            ▼ (新建/编辑)
┌─────────────────────────────────────────────────────────────┐
│  NoteEditorScreen        Notion 风格编辑器                  │
│  ── 一体化：标题 28pt w600 + 正文 17pt 1.6                  │
│  ── 500ms 防抖自动保存                                      │
│  ── 顶部 ✓ 完成按钮                                         │
└─────────────────────────────────────────────────────────────┘

附：NoteSelectScreen（从聊天"添加到笔记"时弹出）— 见 [note-detail-design.md](./note-detail-design.md#5-noteselectscreen--从对话添加到笔记)
```

---

## 共享设计原则

### 2.1 iOS HIG
- 所有页面用 `CupertinoPageScaffold` + `CupertinoButton` + `CupertinoAlertDialog`
- 操作菜单用 `ThkGridBottomSheet`（网格底栏）替代 `CupertinoActionSheet`
- 所有页面包裹 `SafeArea`
- 新建按钮**统一在标题栏右上角**（参见重要决策经验）
- 危险操作用 `isDestructiveAction: true`

### 2.2 色彩与字体
笔记模块**不引入新的色彩 token**，完全复用 [`../../../_shared/design-system.md`](../../../_shared/design-system.md)：

| Token | 用途 |
|-------|------|
| `AppColors.pageBg` | 页面背景 |
| `AppColors.surface` | 卡片/导航栏/内容区背景 |
| `AppColors.textPrimary/Secondary/Tertiary` | 正文三级文字 |
| `AppColors.accent` (Indigo) | 复制按钮、tab 指示器、send 按钮等通用交互色 |
| `CupertinoColors.systemRed/destructiveRed` | 删除、危险操作 |
| `CupertinoColors.systemGreen` | 复制成功反馈 |
| `AppIcons.*` | 模块图标（add / edit / check / copy / branch / delete） |

正文 17pt / 行高 1.6；标题 28pt w600（仅编辑器）；大标题 `AppTheme.largeTitle`（衬线 Cormorant Garamond）。

### 2.3 状态管理：noteListVersionProvider

笔记写入有 4 个触发点（追加、编辑、新建、tab 切换），列表页常驻不销毁，采用 **全局版本号 + build 监听** 模式实现自动刷新：

```dart
final noteListVersionProvider =
    NotifierProvider<NoteListVersionNotifier, int>(NoteListVersionNotifier.new);

class NoteListVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}
```

消费侧统一写法（手动 `_load()` + `setState`，配合 `addPostFrameCallback`）：

```dart
@override
Widget build(BuildContext context) {
  final version = ref.watch(noteListVersionProvider);
  if (_lastSeenVersion != version) {
    _lastSeenVersion = version;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }
  // ...
}
```

版本号 `bump()` 触发点：

| 操作 | 位置 |
|------|------|
| 聊天页选中文本追加到笔记 | `note_select_screen.dart` |
| 笔记详情页编辑保存 | `note_detail_screen.dart#_toggleEditing` |
| 笔记编辑器自动保存 | `note_editor_screen.dart#_saveNow` |
| 笔记总览页新建笔记 | `note_browse_screen.dart#_createNoteInUncategorized` |
| 用户点击底部笔记 tab | `router.dart#_MainShell` |

### 2.4 存储格式

`{root}/themes/{themeId}/notes/{noteId}.md`：

```markdown
---
id: 2026-06-07T10-23-45-ab12cd
title: 笔记标题
themeId: 01HXXX...
createdAt: 2026-06-07T10:23:45
updatedAt: 2026-06-07T10:25:12
---

# 正文

Markdown 内容...
```

存储层：`lib/data/stores/note_store.dart` 暴露 `createNote / listNoteMetas / readBody / appendBody / writeBody / renameNote / deleteNote`。

### 2.5 与搜索联动

保存时 fire-and-forget 调 `searchServiceProvider.upsertNote`：

```dart
void _updateSearchIndex() {
  unawaited(() async {
    try {
      final searchIndex = await ref.read(searchServiceProvider.future);
      // ... 取 meta + theme title
      await searchIndex.upsertNote(
        noteId: meta.noteId,
        themeId: meta.themeId,
        themeTitle: themeTitle,
        noteTitle: meta.title,
        body: _body,
      );
    } catch (_) {
      // 静默失败，永不阻塞主流程
    }
  }());
}
```

---

## 文档索引

| 文档 | 涵盖屏幕 |
|------|----------|
| [notes-list-design.md](./notes-list-design.md) | `NoteBrowseScreen`、`ThemeNoteListScreen` |
| [note-detail-design.md](./note-detail-design.md) | `NoteDetailScreen`、`NoteEditorScreen`、`NoteSelectScreen` |

---

## 实现文件清单

| 文件 | 职责 |
|------|------|
| `lib/ui/features/notes/note_browse_screen.dart` | 笔记总览（按主题分组） |
| `lib/ui/features/notes/note_detail_screen.dart` | 笔记详情 + 主题内列表 `ThemeNoteListScreen` |
| `lib/ui/features/notes/note_detail_screen.dart` | 笔记详情/阅读/编辑切换 |
| `lib/ui/features/notes/note_editor_screen.dart` | Notion 风格独立编辑器 |
| `lib/ui/features/notes/note_select_screen.dart` | 聊天 → 笔记的弹窗选择页 |
| `lib/ui/features/notes/node_location_picker.dart` | 笔记 → 对话时选择主题/父节点的 picker |
| `lib/data/stores/note_store.dart` | 笔记 CRUD |
| `lib/ui/core/widgets/thk_grid_bottom_sheet.dart` | 网格底栏 Action Sheet |
| `lib/ui/core/widgets/markdown_toolbar.dart` | Markdown 工具栏（标题切换 + 表格插入） |
| `lib/ui/core/app_services.dart` | 定义 `noteListVersionProvider` |
