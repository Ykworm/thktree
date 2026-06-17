# ThemeListScreen 改进方案

> 基于 UI/UX Pro Max + Flutter Dev + Frontend Dev 审查

---

## 现状分析

**ThemeListScreen** 是主题 Tab 的根页面，显示所有主题列表。

**已有能力**：
- SQLite 存储，`themes` 表有 `themeId / title / createdAt / updatedAt / themePath`
- `listThemes()` 已按 `updatedAt DESC` 排序（最近活跃在前）
- 硬编码置顶：`_pinnedTitle = '未分类'` 始终排第一
- `renameTheme()` 方法已存在

**缺失能力**：
- 无用户可控置顶
- 无删除主题功能
- subtitle 只在 debug 模式显示 themeId
- 无下拉刷新（只有 NavBar 刷新按钮）
- 无长按/滑动操作

---

## 改动清单

### 改动 1：数据库加 `pinned` 列

**文件**：`lib/data/services/app_database.dart`

**方案**：新增 v5 migration，给 themes 表加 `pinned` 列

```dart
// 在 AppDatabase.open() 中
if (oldVersion < 5) {
  await _migrateV5(db);
}

// 新增 migration
Future<void> _migrateV5(Database db) async {
  await _addColumnIfNotExists(db, 'themes', 'pinned', 'INTEGER NOT NULL DEFAULT 0');
  // 把"未分类"主题标记为 pinned（兼容旧数据）
  await db.execute("UPDATE themes SET pinned = 1 WHERE title = '未分类'");
}
```

**版本号**：`version: 4` → `version: 5`

---

### 改动 2：ThemeEntity 加 `pinned` 字段

**文件**：`lib/domain/theme.dart`

```dart
class ThemeEntity {
  ThemeEntity({
    required this.themeId,
    required this.title,
    required this.createdAtUtcIso8601,
    required this.updatedAtUtcIso8601,
    this.pinned = false,  // 新增
  });

  final String themeId;
  final String title;
  final String createdAtUtcIso8601;
  final String updatedAtUtcIso8601;
  final bool pinned;  // 新增
}
```

---

### 改动 3：ThemeStore 更新

**文件**：`lib/data/stores/theme_store.dart`

**3.1 更新 listThemes()**：
```dart
Future<List<ThemeEntity>> listThemes() async {
  final rows = await db.query('themes', orderBy: 'pinned DESC, updatedAt DESC');
  return rows
      .map(
        (row) => ThemeEntity(
          themeId: row['themeId']! as String,
          title: row['title']! as String,
          createdAtUtcIso8601: row['createdAt']! as String,
          updatedAtUtcIso8601: row['updatedAt']! as String,
          pinned: (row['pinned'] as int? ?? 0) == 1,  // 新增
        ),
      )
      .toList();
  // 移除旧的硬编码排序（_pinnedTitle 逻辑）
}
```

**3.2 新增 togglePin()**：
```dart
Future<void> togglePin({required String themeId, required bool pinned}) async {
  await db.update(
    'themes',
    {'pinned': pinned ? 1 : 0},
    where: 'themeId = ?',
    whereArgs: [themeId],
  );
}
```

**3.3 新增 deleteTheme()**：
```dart
Future<void> deleteTheme({required String themeId}) async {
  // 1. 获取 themePath
  final rows = await db.query('themes', where: 'themeId = ?', whereArgs: [themeId], limit: 1);
  if (rows.isEmpty) return;
  final themePath = rows.first['themePath'] as String;
  final absPath = paths.toAbsolutePath(themePath);

  // 2. 删除数据库记录（先删 nodes，再删 theme）
  await db.delete('nodes', where: 'themeId = ?', whereArgs: [themeId]);
  await db.delete('themes', where: 'themeId = ?', whereArgs: [themeId]);

  // 3. 删除文件系统目录
  final dir = Directory(absPath);
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}
```

**3.4 移除 _pinnedTitle 常量**：
```dart
// 删除这行
static const _pinnedTitle = '未分类';
```

---

### 改动 4：ThemeListController 更新

**文件**：`lib/ui/features/themes/theme_list_controller.dart`

**新增方法**：
```dart
Future<void> togglePin({required String themeId, required bool pinned}) async {
  final store = await ref.read(themeStoreProvider.future);
  await store.togglePin(themeId: themeId, pinned: pinned);
  state = AsyncData(await store.listThemes());
}

Future<void> deleteTheme({required String themeId}) async {
  final store = await ref.read(themeStoreProvider.future);
  await store.deleteTheme(themeId: themeId);
  state = AsyncData(await store.listThemes());
}
```

---

### 改动 5：ThemeListScreen UI 更新

**文件**：`lib/ui/features/themes/theme_list_screen.dart`

**5.1 去掉 NavBar 刷新按钮，只保留新建按钮**：
```dart
trailing: CupertinoButton(
  padding: EdgeInsets.zero,
  onPressed: () async {
    final title = await _promptTitle(context);
    if (title == null) return;
    if (!context.mounted) return;
    await ref.read(themeListControllerProvider.notifier).createTheme(title: title);
  },
  child: Icon(AppIcons.add),
),
```

**5.2 替换 ThkLargeTitlePage 为 CustomScrollView + CupertinoSliverRefreshControl**：
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  final themesAsync = ref.watch(themeListControllerProvider);
  return CupertinoPageScaffold(
    backgroundColor: AppColors.pageBg,
    child: CustomScrollView(
      slivers: [
        ThkNavBar.large(
          title: l10n.themesTabLabel,
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () async { ... },
            child: Icon(AppIcons.add),
          ),
        ),
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            await ref.read(themeListControllerProvider.notifier).reindex();
          },
        ),
        themesAsync.when(
          data: (themes) => SliverList(
            delegate: SliverChildListDelegate(_buildThemeList(themes, l10n, ref)),
          ),
          loading: () => SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (e, st) => SliverFillRemaining(
            child: Center(child: Text(e.toString())),
          ),
        ),
      ],
    ),
  );
}
```

**5.3 ThkListTile 加 subtitle（相对时间）**：
```dart
ThkListTile(
  title: localizedThemeTitle(l10n, themes[i].title),
  subtitle: _relativeTime(themes[i].updatedAtUtcIso8601),  // 新增
  trailing: themes[i].pinned
      ? Icon(AppIcons.star, color: AppColors.accent, size: 18)  // 置顶图标
      : ThkListTile.chevron,
  themeId: themes[i].themeId,
  leading: Icon(AppIcons.folder),
  onTap: () => context.push('/themes/${themes[i].themeId}/tree'),
)
```

**5.4 新增相对时间格式化**：
```dart
String _relativeTime(String iso8601) {
  final dateTime = DateTime.parse(iso8601).toLocal();
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
  if (diff.inDays < 1) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}周前';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}个月前';
  return '${(diff.inDays / 365).floor()}年前';
}
```

**5.5 新增长按 Action Sheet**：
```dart
// 在 ThkListTile 外层包 GestureDetector
GestureDetector(
  onLongPress: () => _showThemeActions(context, ref, themes[i], l10n),
  child: ThkListTile(...),
)

// 新增方法
Future<void> _showThemeActions(
  BuildContext context, WidgetRef ref, ThemeEntity theme, AppLocalizations l10n,
) async {
  final action = await showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 'rename'),
          child: Text(l10n.renameNode),  // 复用现有 key
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 'pin'),
          child: Text(theme.pinned ? l10n.unpin : l10n.pin),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, 'delete'),
          child: Text(l10n.delete),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: Text(l10n.cancel),
      ),
    ),
  );

  if (action == 'rename') {
    final newTitle = await _promptRename(context, theme.title);
    if (newTitle != null) {
      await ref.read(themeListControllerProvider.notifier).renameTheme(
        themeId: theme.themeId,
        title: newTitle,
      );
    }
  } else if (action == 'pin') {
    await ref.read(themeListControllerProvider.notifier).togglePin(
      themeId: theme.themeId,
      pinned: !theme.pinned,
    );
  } else if (action == 'delete') {
    final confirmed = await _confirmDelete(context, theme, l10n);
    if (confirmed == true) {
      await ref.read(themeListControllerProvider.notifier).deleteTheme(
        themeId: theme.themeId,
      );
    }
  }
}
```

**5.6 新增重命名对话框**：
```dart
Future<String?> _promptRename(BuildContext context, String currentTitle) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: currentTitle);
  return showCupertinoDialog<String>(
    context: context,
    builder: (context) {
      return CupertinoAlertDialog(
        title: Text(l10n.renameNode),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ThkTextField(
            controller: controller,
            placeholder: l10n.enterNewTitle,
            autofocus: true,
            maxLength: 30,
            onSubmitted: (value) {
              final composing = controller.value.composing;
              if (composing.isValid && !composing.isCollapsed) return;
              Navigator.of(context).pop(value.trim().isEmpty ? null : value.trim());
            },
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final value = controller.text.trim();
              Navigator.of(context).pop(value.isEmpty ? null : value);
            },
            child: Text(l10n.save),
          ),
        ],
      );
    },
  );
}
```

**5.7 新增删除确认对话框**：
```dart
Future<bool?> _confirmDelete(BuildContext context, ThemeEntity theme, AppLocalizations l10n) {
  return showCupertinoDialog<bool>(
    context: context,
    builder: (context) {
      return CupertinoAlertDialog(
        title: Text(l10n.deleteItem),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l10n.deleteThemeConfirm(theme.title)),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      );
    },
  );
}
```

---

### 改动 6：新增 l10n keys

**文件**：`lib/l10n/` 相关文件

需要新增的 key：
- `pin` — "置顶"
- `unpin` — "取消置顶"
- `deleteThemeConfirm(String title)` — "确认删除主题「{title}」？所有对话将被永久删除。"

---

## 实施顺序

1. **数据库 migration**（改动 1）— 5 分钟
2. **ThemeEntity 更新**（改动 2）— 2 分钟
3. **ThemeStore 更新**（改动 3）— 10 分钟
4. **ThemeListController 更新**（改动 4）— 5 分钟
5. **l10n keys**（改动 6）— 5 分钟
6. **ThemeListScreen UI**（改动 5）— 20 分钟

预计总工时：约 45 分钟

---

## 待确认

1. **置顶图标**：用 `AppIcons.star`（星标）还是其他图标？iOS 习惯用 pin 图标。
2. **删除确认文案**：当前是"确认删除主题「{title}」？所有对话将被永久删除。"需要调整吗？
3. **相对时间格式**：中文格式（"2小时前"）还是需要支持多语言？
4. **下拉刷新动画**：用 iOS 原生 CupertinoSliverRefreshControl 还是自定义？
