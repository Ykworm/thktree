# 笔记列表设计

> 涵盖 `NoteBrowseScreen`（按主题分组的总览）和 `ThemeNoteListScreen`（主题内笔记列表）。
>
> 配套阅读：[`../../../_shared/design-system.md`](../../../_shared/design-system.md) · [`./README.md`](./README.md) · [`./note-detail-design.md`](./note-detail-design.md)

---

## Summary

笔记列表承担"按主题聚合 → 进入主题 → 进入单条"的二级导航：总览层只显示主题名 + 笔记数，不直接列出每条笔记；点击主题才进入该主题下的笔记明细列表。两层都使用 `noteListVersionProvider` 触发自动刷新，遵循统一的 iOS HIG。

---

## 设计决策

| 决策点 | 选择 | 说明 |
|--------|------|------|
| 总览信息密度 | 仅显示主题名 + 笔记数 | 不展示笔记摘要，保持列表干净 |
| 主题排序 | "未分类"置顶，其余字典序 | 未分类是用户从笔记 tab 直接创建的落点 |
| 主题项交互 | 点击进入主题内列表 | 无 swipe 操作，主题本身不支持删除 |
| 笔记项交互 | 点击进入详情 + 左滑删除 | 删除是高频操作，swipe 提升效率 |
| 标题栏样式 | 总览用 `ThkNavBar.inline`，列表用 `ThkLargeTitlePage` | 与主题 page 保持视觉一致 |
| 大标题字体 | Cormorant Garamond w600 | 复用 `AppTheme.largeTitle` |
| 列表项分隔 | 跟随 `ThkListSection` 默认样式 | 不画额外分割线 |
| 删除二次确认 | `CupertinoAlertDialog` + `isDestructiveAction` | 符合 iOS HIG |
| 加载/空/错误态 | 居中显示，统一在主滚动容器中 | 保证下拉手势总能触发 |
| 顶部搜索入口 | 复用搜索 tab 的 `SearchContent`（空查询显示主题分组；非空查询显示全文搜索结果） | 统一两套入口的搜索能力，详见 `docs/_tmp/note-search-unify-plan.md` |

---

## 1. NoteBrowseScreen — 笔记总览

### 1.1 屏幕形态

总览页顶部固定一行 `SearchBox`（复用搜索 tab 的 `SearchContent`），下面是主题分组列表：
- 空查询时 → 渲染主题分组（与原行为一致）
- 非空查询时 → 渲染全文搜索结果列表（SQLite FTS5），点击命中跳转 `NoteDetailScreen` / `ChatScreen` 等

```
┌─────────────────────────────────────────────────────────────┐
│  ← 笔记                                              [ + ]  │  ← ThkNavBar.inline
├─────────────────────────────────────────────────────────────┤
│  [ 🔍  搜索笔记/对话/节点                              ✕ ]  │  ← SearchBox（SearchContent）
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 未分类                                          12条 │    │  ← ThkListTile
│  ├─────────────────────────────────────────────────────┤    │
│  │ 心理学                                           5条 │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ 编程                                             23条 │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ 读书笔记                                         8条  │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 布局详解

```dart
CupertinoPageScaffold(
  navigationBar: ThkNavBar.inline(
    title: l10n.notes,
    trailing: CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _createNoteInUncategorized(context, ref),
      child: Icon(AppIcons.add),
    ),
  ),
  child: SafeArea(
    top: false,
    child: _buildBody(l10n),
  ),
)
```

| 元素 | 规范 |
|------|------|
| 标题栏 | `ThkNavBar.inline`（嵌入式，非大标题） |
| 标题文字 | `l10n.notes` |
| 右上角 | `AppIcons.add`，`CupertinoButton`（`padding: zero`） |
| 主体 | `ListView` + `ThkListSection` + `ThkListTile` |
| 主题名 | `localizedThemeTitle(l10n, tn.title)` — `未分类` 走 l10n 翻译 |
| 副标题 | `l10n.noteCount(tn.noteCount)` — "X 条笔记" |

### 1.3 主题排序规则

```dart
result.sort((a, b) {
  final aPinned = a.title == '未分类';
  final bPinned = b.title == '未分类';
  if (aPinned && !bPinned) return -1;
  if (!aPinned && bPinned) return 1;
  return a.title.compareTo(b.title);
});
```

- **未分类固定置顶**（基于稳定 marker `kUncategorizedThemeTitle = '未分类'`，不是显示名）
- 其余按 title 字典序
- 显示名走 `localizedThemeTitle()` 翻译，但**比较用稳定 marker**

### 1.4 新建笔记流程

点击 ➕ 按钮的完整链路：

```
NoteBrowseScreen (+)
    │
    ▼
showThemePicker(context, ref, onThemeCreated: invalidate theme list)
    │  用户选主题（或现场新建）
    ▼
await ref.read(appPathsProvider.future)
    │  解析 notesDir = themesDir/{themeId}/notes
    ▼
Navigator.push(NoteEditorScreen(
  themeId, themeTitle, themePath, notesDir,
  createMode: true,
))
    │
    ▼
编辑器里 _createNote() 立即创建空文件 → 自动保存占位
```

`_createNoteInUncategorized` 名字虽带 "Uncategorized"，但实际是"先选主题再创建"，避免所有从笔记 tab 新建的笔记都堆在"未分类"里。

### 1.5 状态管理

```dart
class _NoteBrowseScreenState extends ConsumerState<NoteBrowseScreen> {
  List<_ThemeNotes>? _themes;
  bool _loading = true;
  Object? _error;
  int? _lastSeenVersion;

  @override
  void initState() {
    super.initState();
    _lastSeenVersion = ref.read(noteListVersionProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final themes = await _loadThemeNotes(ref);
      if (!mounted) return;
      setState(() { _themes = themes; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e; _loading = false; });
    }
  }
  // ...
}
```

数据加载流程：

```dart
Future<List<_ThemeNotes>> _loadThemeNotes(WidgetRef ref) async {
  final paths = await ref.read(appPathsProvider.future);
  final themesDir = paths.themesDir;
  if (!await themesDir.exists()) return [];

  final result = <_ThemeNotes>[];
  for (final entity in await themesDir.list().toList()) {
    if (entity is! Directory) continue;
    final themeId = entity.path.split('/').last;
    if (themeId.startsWith('.')) continue;       // 跳过隐藏目录
    final notesSubDir = Directory('${entity.path}/notes');
    final store = NoteStore(notesDir: notesSubDir);
    final metas = await store.listNoteMetas();

    // 尝试读取 theme.meta.json 取显示名
    var title = themeId;
    try {
      final metaFile = File('${entity.path}/theme.meta.json');
      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        title = map['title'] as String? ?? themeId;
      }
    } catch (_) {}

    result.add(_ThemeNotes(themeId, themePath, title, metas.length));
  }
  result.sort(...);
  return result;
}
```

### 1.6 状态展示

| 状态 | 视觉 |
|------|------|
| 加载中 | `Center(child: CupertinoActivityIndicator())` |
| 错误 | `CupertinoColors.systemRed` 文字 + 16 padding |
| 空 | `l10n.noNotesYet`，`CupertinoColors.secondaryLabel` |
| 有数据 | `ListView` + `ThkListSection` |

### 1.7 跳转

```dart
onTap: () {
  Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (_) => ThemeNoteListScreen(
        themeId: tn.themeId,
        notesDir: '${tn.themePath}/notes',
      ),
    ),
  );
},
```

- 用 `CupertinoPageRoute` 而非 `go_router`，保持 iOS 原生左滑返回手势
- `notesDir` 直接传绝对路径，避免子页面再 `await appPathsProvider`

---

## 2. ThemeNoteListScreen — 主题内笔记列表

### 2.1 屏幕形态

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  笔记                                                [ + ]  │  ← ThkLargeTitlePage 大标题
│  ────────────────────                                       │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 心理学读书笔记                              ← 左滑删除 │  │
│  │ 2026-06-07-abcd · 2026-06-07 10:23                  │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ 焦虑与防御机制                                   │    │
│  │ 2026-06-05-efgh · 2026-06-05 14:11                  │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ 存在主义治疗                                     │    │
│  │ 2026-06-03-ijkl · 2026-06-03 09:45                  │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 布局详解

```dart
return ThkLargeTitlePage(
  title: l10n.notes,
  trailing: CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: () => _createNote(context, ref),
    child: Icon(AppIcons.add),
  ),
  children: _buildChildren(l10n),
);
```

| 元素 | 规范 |
|------|------|
| 大标题 | `l10n.notes`，`AppTheme.largeTitle`（衬线 Cormorant Garamond） |
| 右上角 | ➕，`CupertinoButton`（`padding: zero`） |
| 列表容器 | `ThkListSection` |
| 列表项 | `SwipeableRow` 包裹 `ThkListTile` |
| 标题 | 笔记 `meta.title` |
| 副标题 | `'{noteId} · {updatedAt}'`（中间分隔符是 `·`，U+00B7） |

### 2.3 SwipeableRow 左滑删除

```dart
SwipeableRow(
  key: ValueKey(meta.noteId),
  onSwipeLeft: () async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.deleteNote),
        content: Text(l10n.deleteNoteConfirmTitle(meta.title)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _store.deleteNote(noteId: meta.noteId);
      ref.read(noteListVersionProvider.notifier).bump();
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: '${l10n.deleteFailed}: $e',
        defaultAction: l10n.ok,
      );
    }
  },
  leftActionLabel: l10n.swipeDelete,
  leftActionIcon: AppIcons.delete,
  leftActionColor: CupertinoColors.destructiveRed,
  child: ThkListTile(...),
)
```

| SwipeableRow 属性 | 值 |
|------------------|----|
| `leftActionLabel` | `l10n.swipeDelete` |
| `leftActionIcon` | `AppIcons.delete` |
| `leftActionColor` | `CupertinoColors.destructiveRed` |
| `key` | `ValueKey(meta.noteId)` — 保证 swipe 状态在重建时正确恢复 |

**二次确认弹窗规范**：

- 标题：`l10n.deleteNote`
- 内容：`l10n.deleteNoteConfirmTitle(meta.title)` — "确定删除《xxx》？"
- 操作：取消 + 删除（`isDestructiveAction: true`）
- 失败处理：用 `ThkAlert.show` 兜底提示

### 2.4 列表项点击 → 详情

```dart
onTap: () {
  Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (_) => NoteDetailScreen(
        notesDir: widget.notesDir,
        noteId: meta.noteId,
      ),
    ),
  );
},
```

### 2.5 ➕ 按钮 → 新建

`ThemeNoteListScreen._createNote` 复用与总览相同的"先选主题再编辑"流程，但因为已经在一个主题内，预选当前 `themeId` 体验更顺（**当前实现仍走 picker，作为未来优化点**）。

### 2.6 状态展示

| 状态 | 视觉 |
|------|------|
| 加载中 | `Padding(top: 80) + Center(CupertinoActivityIndicator)` |
| 错误 | `Padding(top: 80) + systemRed 文字` |
| 空 | `Padding(top: 80) + l10n.noNotesYet + textSecondary` |
| 有数据 | `ThkListSection` 包裹的 `SwipeableRow` 列表 |

> **空态/错误态也包裹在 `ThkLargeTitlePage.children` 里**，保证下拉刷新手势始终可用（参见 [`./README.md#23`](./README.md) 提到的"曾尝试过但不可行的方案"）。

### 2.7 状态管理

与 `NoteBrowseScreen` 完全一致：`noteListVersionProvider` + `addPostFrameCallback` + 手动 `_load()` + `setState`。

---

## 3. 实现文件清单

| 文件 | 内容 |
|------|------|
| `lib/ui/features/notes/note_browse_screen.dart` | `NoteBrowseScreen` + `ThemeNoteListScreen` + `_loadThemeNotes` + `_createNoteInUncategorized` + `kUncategorizedThemeTitle` / `localizedThemeTitle` |
| `lib/data/stores/note_store.dart` | `listNoteMetas / deleteNote` 等 CRUD |
| `lib/ui/core/widgets/swipeable_row.dart` | `SwipeableRow` 组件 |
| `lib/ui/core/widgets/thk_list_section.dart` | `ThkListSection` 容器 |
| `lib/ui/core/widgets/thk_list_tile.dart` | `ThkListTile` 列表项 |
| `lib/ui/core/widgets/thk_nav_bar.dart` | `ThkNavBar.inline` / `ThkLargeTitlePage` |
| `lib/ui/core/theme/app_icons.dart` | `AppIcons.add / delete` |
| `lib/ui/core/app_services.dart` | `noteListVersionProvider` 定义 |
| `lib/l10n/app_zh.arb` · `app_en.arb` | `notes / noteCount / noNotesYet / deleteNote / deleteNoteConfirmTitle / swipeDelete / uncategorized` |

---

## 4. Test Plan

### 4.1 NoteBrowseScreen
1. **空目录**：themes 目录不存在或为空时显示 `l10n.noNotesYet`
2. **多主题加载**：3 个主题的目录 + 各自有 notes，显示 3 行 `ThkListTile`
3. **未分类置顶**：包含"未分类"主题时永远在第一位
4. **笔记数统计**：每个主题的 `noteCount` 等于 `metas.length`
5. **隐藏目录过滤**：`themeId.startsWith('.')` 的目录被跳过
6. **title fallback**：`theme.meta.json` 缺失时显示 `themeId` 本身
7. **title 解析失败**：JSON 解析异常时不崩溃，回退到 `themeId`
8. **新建跳转**：点击 ➕ → 弹出 `showThemePicker` → 选主题后 push `NoteEditorScreen`
9. **版本号触发**：写操作后 `bump()` → 列表自动 `_load()`

### 4.2 ThemeNoteListScreen
1. **空态**：主题内无笔记时显示 `l10n.noNotesYet`
2. **加载态**：显示 `CupertinoActivityIndicator`
3. **左滑删除**：swipe 后弹 `CupertinoAlertDialog` → 确认后 `deleteNote` + `bump`
4. **左滑取消**：取消时不删除，按钮回弹
5. **左滑失败**：删除异常时 `ThkAlert` 提示，列表不更新
6. **点击进入**：点击 `ThkListTile` → push `NoteDetailScreen`，左滑返回手势可用
7. **ValueKey 稳定**：swipe 状态在版本号 bump 重载时正确恢复（`ValueKey(meta.noteId)`）
8. **大标题字体**：标题是 Cormorant Garamond w600
9. **副标题格式**：`'{noteId} · {updatedAt}'`（中点 U+00B7）

### 4.3 共享
1. **noteListVersionProvider 唯一性**：所有 `bump()` 路径都通过 `noteListVersionProvider.notifier`
2. **`_lastSeenVersion` 初始化**：在 `initState` 中 `ref.read(noteListVersionProvider)` 初始化
3. **`addPostFrameCallback` 守卫**：内部检查 `mounted` 后再 `_load()`
4. **无障碍**：所有 `CupertinoButton` 都有语义标签
5. **大字体**：iOS Dynamic Type 放大时布局不溢出

---

## 5. Assumptions

- 主题数量不会很多（< 50），`ThkListSection` 性能足够
- 笔记数量单主题内 < 500 时不需要虚拟列表
- 隐藏目录以 `.` 开头为约定
- `noteListVersionProvider` 不会持久化，应用重启后从 0 开始
- "未分类"是稳定 marker，多语言环境下显示名走 l10n 但比较用 marker
- 顶部搜索入口不复用主题名过滤能力（接受 FTS5 schema `themeTitle UNINDEXED` 事实），全文搜索范围覆盖笔记标题/正文/对话消息/节点标题

---

## 6. 未来优化方向

| 优先级 | 事项 | 说明 |
|--------|------|------|
| 🟡 | 主题内笔记搜索 | 在 `ThemeNoteListScreen` 顶部加搜索框，按 title 模糊匹配 |
| 🟢 | `ThemeNoteListScreen` ➕ 按钮预选当前主题 | 跳过 picker 步骤 |
| 🟢 | 主题分组折叠/展开 | 主题数 > 10 时可折叠 |
| 🟢 | 主题按最近编辑时间排序 | 替代字典序 |
