# ThemeListScreen 改进方案 v3

> 基于 UI/UX Pro Max + Flutter Dev + Frontend Dev 审查

---

## 现状分析

**ThemeListScreen** 是主题 Tab 的根页面，显示所有主题列表。

**已有能力**：
- SQLite 存储，`themes` 表有 `themeId / title / createdAt / updatedAt / themePath`
- `listThemes()` 已按 `updatedAt DESC` 排序（最近活跃在前）
- 硬编码置顶：`_pinnedTitle = '未分类'` 始终排第一
- `renameTheme()` 方法已存在
- FTS5 `search_index` 表存储了所有消息内容（可用于预览）
- 笔记列表已有 `formatRelativeTime()` 函数（支持 l10n）

**缺失能力**：
- 无用户可控置顶
- 无删除主题功能
- subtitle 只在 debug 模式显示 themeId
- 无下拉刷新（只有 NavBar 刷新按钮）
- 无长按/滑动操作
- 页面背景色是 `pageBg`（灰白），应为 `surface`（白色）

---

## 已确认的功能需求

| 需求 | 状态 | 备注 |
|------|------|------|
| 用户可控置顶 | ✅ 要有 | 长按 → Action Sheet → 置顶/取消置顶 |
| 删除主题 | ✅ 要有 | 长按 → Action Sheet → 删除（带确认） |
| subtitle 改为预览/时间 | ✅ 要有 | 不再显示 themeId |
| 下拉刷新 | ✅ 要有 | 去掉 NavBar 刷新按钮 |
| 长按操作 | ✅ 要有 | Action Sheet（重命名/置顶/删除） |
| 页面背景色 | ✅ 改为白色 | 参照笔记列表用 `AppColors.surface` |

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

### 改动 2：ThemeEntity 加 `pinned` 和 `lastMessagePreview` 字段

**文件**：`lib/domain/theme.dart`

```dart
class ThemeEntity {
  ThemeEntity({
    required this.themeId,
    required this.title,
    required this.createdAtUtcIso8601,
    required this.updatedAtUtcIso8601,
    this.pinned = false,
    this.lastMessagePreview,
  });

  final String themeId;
  final String title;
  final String createdAtUtcIso8601;
  final String updatedAtUtcIso8601;
  final bool pinned;
  final String? lastMessagePreview;
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
          pinned: (row['pinned'] as int? ?? 0) == 1,
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

  // 2. 删除数据库记录（先删 search_index，再删 nodes，再删 theme）
  await db.delete('search_index', where: 'themeId = ?', whereArgs: [themeId]);
  await db.delete('nodes', where: 'themeId = ?', whereArgs: [themeId]);
  await db.delete('themes', where: 'themeId = ?', whereArgs: [themeId]);

  // 3. 删除文件系统目录
  final dir = Directory(absPath);
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}
```

**3.4 修改 reindexThemesFromDisk()：保留 pinned 状态**

当前 reindex 逻辑是先 DELETE 全表再 INSERT，新增 `pinned` 列后，每次 reindex 会把用户置顶状态重置为 0。
修复方式：reindex 前先保存当前置顶主题 ID，在同一个 transaction 内 DELETE + INSERT 之后再恢复。

```dart
Future<void> reindexThemesFromDisk() async {
  // 1. 保存当前置顶状态
  final pinnedRows = await db.query(
    'themes',
    columns: ['themeId'],
    where: 'pinned = 1',
  );
  final pinnedIds = pinnedRows.map((r) => r['themeId'] as String).toSet();

  // 2. 原有同步逻辑（DELETE + INSERT，不变）
  await paths.ensureCreated();
  final themeDirs = await paths.themesDir.list(followLinks: false).toList();
  // ... 构建 metas 列表

  await db.transaction((txn) async {
    await txn.delete('themes');
    for (final meta in metas) {
      await txn.insert(
        'themes',
        {
          'themeId': meta.themeId,
          'title': meta.title,
          'createdAt': meta.createdAtUtcIso8601,
          'updatedAt': meta.updatedAtUtcIso8601,
          'themePath': paths.toRootRelativePath(
            p.join(paths.themesDir.path, meta.themeId),
          ),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    // 3. 恢复置顶状态
    for (final id in pinnedIds) {
      await txn.update(
        'themes',
        {'pinned': 1},
        where: 'themeId = ?',
        whereArgs: [id],
      );
    }
  });
}
```

**3.5 移除 _pinnedTitle 常量**：
```dart
// 删除这行
static const _pinnedTitle = '未分类';
```

---

### 改动 4：ThemeListController 更新

**文件**：`lib/ui/features/themes/theme_list_controller.dart`

**完整重写**：
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/domain/theme.dart';

class ThemeListController extends AsyncNotifier<List<ThemeEntity>> {
  @override
  Future<List<ThemeEntity>> build() async {
    final store = await ref.watch(themeStoreProvider.future);
    await store.reindexThemesFromDisk();
    final themes = await store.listThemes();
    return await _loadPreviews(themes);
  }

  Future<List<ThemeEntity>> _loadPreviews(List<ThemeEntity> themes) async {
    final db = await ref.read(appDatabaseProvider.future);
    final result = <ThemeEntity>[];
    
    for (final theme in themes) {
      String? preview;
      try {
        final rows = await db.db.query(
          'search_index',
          columns: ['content'],
          where: 'themeId = ? AND entityType = ?',
          whereArgs: [theme.themeId, 'message'],
          orderBy: 'updatedAt DESC',
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final content = rows.first['content'] as String;
          preview = content.length <= 40 ? content : '${content.substring(0, 40)}…';
        }
      } catch (_) {}
      
      result.add(ThemeEntity(
        themeId: theme.themeId,
        title: theme.title,
        createdAtUtcIso8601: theme.createdAtUtcIso8601,
        updatedAtUtcIso8601: theme.updatedAtUtcIso8601,
        pinned: theme.pinned,
        lastMessagePreview: preview,
      ));
    }
    return result;
  }

  Future<void> createTheme({required String title}) async {
    final store = await ref.read(themeStoreProvider.future);
    await store.createTheme(title: title);
    state = AsyncData(await _loadPreviews(await store.listThemes()));
  }

  Future<void> reindex() async {
    final store = await ref.read(themeStoreProvider.future);
    await store.reindexThemesFromDisk();
    state = AsyncData(await _loadPreviews(await store.listThemes()));
  }

  Future<void> togglePin({required String themeId, required bool pinned}) async {
    final store = await ref.read(themeStoreProvider.future);
    await store.togglePin(themeId: themeId, pinned: pinned);
    state = AsyncData(await _loadPreviews(await store.listThemes()));
  }

  Future<void> deleteTheme({required String themeId}) async {
    final store = await ref.read(themeStoreProvider.future);
    await store.deleteTheme(themeId: themeId);
    state = AsyncData(await _loadPreviews(await store.listThemes()));
  }

  Future<void> renameTheme({required String themeId, required String title}) async {
    final store = await ref.read(themeStoreProvider.future);
    await store.renameTheme(themeId: themeId, title: title);
    state = AsyncData(await _loadPreviews(await store.listThemes()));
  }
}

final themeListControllerProvider =
    AsyncNotifierProvider<ThemeListController, List<ThemeEntity>>(ThemeListController.new);
```

---

### 改动 5：ThemeListScreen UI 更新

**文件**：`lib/ui/features/themes/theme_list_screen.dart`

**5.1 重构为 CupertinoPageScaffold + CustomScrollView**（参照笔记列表）：
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  final themesAsync = ref.watch(themeListControllerProvider);
  return CupertinoPageScaffold(
    backgroundColor: AppColors.surface,  // 白色背景
    child: CustomScrollView(
      slivers: [
        ThkNavBar.large(
          title: l10n.themesTabLabel,
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

**5.2 新增 _buildThemeList 方法**：
```dart
List<Widget> _buildThemeList(List<ThemeEntity> themes, AppLocalizations l10n, WidgetRef ref) {
  if (themes.isEmpty) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.accountTree, size: 40, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(l10n.noThemesYet, style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    ];
  }

  return [
    for (int i = 0; i < themes.length; i++) ...[
      GestureDetector(
        onLongPress: () => _showThemeActions(context, ref, themes[i], l10n),
        child: ThkListTile(
          title: localizedThemeTitle(l10n, themes[i].title),
          subtitle: themes[i].lastMessagePreview ?? formatRelativeTime(l10n, themes[i].updatedAtUtcIso8601),
          trailing: themes[i].pinned
              ? Icon(AppIcons.star, color: AppColors.accent, size: 18)
              : ThkListTile.chevron,
          themeId: themes[i].themeId,
          leading: Icon(AppIcons.folder),
          onTap: () => context.push('/themes/${themes[i].themeId}/tree'),
        ),
      ),
      if (i < themes.length - 1)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 56),
          child: Container(height: 0.5, color: AppColors.border),
        ),
    ],
  ];
}
```

**5.3 复用 formatRelativeTime**（从 note_browse_screen.dart 导入）：
```dart
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart'
    show localizedThemeTitle, formatRelativeTime;
```

**5.4 新增长按 Action Sheet**：
```dart
Future<void> _showThemeActions(
  BuildContext context, WidgetRef ref, ThemeEntity theme, AppLocalizations l10n,
) async {
  final action = await showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 'rename'),
          child: Text(l10n.renameNode),
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

**5.5 新增重命名对话框**：
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

**5.6 新增删除确认对话框**：
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

## 技术细节

### 为什么用 search_index 而不是读磁盘？

**传统方案**：读 session.md 文件 → 解析 → 提取最后消息
- 需要 O(n) 次文件 IO（n = 节点数）
- 每次进入 ThemeListScreen 都要读

**search_index 方案**：直接查询 FTS5 表
- 一次 SQL 查询，性能好
- search_index 在 reindex 时已经维护好了
- 数据可能有轻微延迟（取决于上次 reindex 时间）

**权衡**：
- 延迟可接受：用户进入 ThemeListScreen 时会触发 reindex
- 性能提升：避免大量文件 IO

### 为什么复用 formatRelativeTime？

- 已在 `note_browse_screen.dart` 中实现
- 支持 l10n（中英文）
- 格式：刚刚 / X分钟前 / X小时前 / X天前 / 月日
- 避免重复造轮子

---

## 实施顺序

1. **数据库 migration**（改动 1）— 5 分钟
2. **ThemeEntity 更新**（改动 2）— 2 分钟
3. **ThemeStore 更新**（改动 3）— 10 分钟
4. **ThemeListController 更新**（改动 4）— 10 分钟
5. **l10n keys**（改动 6）— 5 分钟
6. **ThemeListScreen UI**（改动 5）— 20 分钟

预计总工时：约 55 分钟

---

## 实施清单（给执行 Agent）

### 前置条件
- 配色系统已更新（AppColors + _NodePalette）
- ThkListTile 已修复（图标跟随主题色）
- 设计文档已更新

### 需要实施的功能改动

#### 1. 数据库 Migration（5 分钟）
- [ ] 打开 `lib/data/services/app_database.dart`
- [ ] 修改 `version: 4` → `version: 5`
- [ ] 添加 `_migrateV5` 函数：给 themes 表加 `pinned INTEGER NOT NULL DEFAULT 0` 列
- [ ] 迁移"未分类"主题的 pinned 状态

#### 2. ThemeEntity 更新（2 分钟）
- [ ] 打开 `lib/domain/theme.dart`
- [ ] 添加 `pinned` 字段（bool，默认 false）
- [ ] 添加 `lastMessagePreview` 字段（String?）

#### 3. ThemeStore 更新（15 分钟）
- [ ] 打开 `lib/data/stores/theme_store.dart`
- [ ] 修改 `listThemes()`：排序改为 `pinned DESC, updatedAt DESC`
- [ ] 添加 `togglePin()` 方法
- [ ] 添加 `deleteTheme()` 方法（删除数据库记录 + 文件系统目录）
- [ ] 修改 `reindexThemesFromDisk()`：reindex 前保存 pinned 列表，transaction 内恢复
- [ ] 删除 `_pinnedTitle` 常量和相关硬编码逻辑

#### 4. ThemeListController 更新（10 分钟）
- [ ] 打开 `lib/ui/features/themes/theme_list_controller.dart`
- [ ] 添加 `_loadPreviews()` 方法：从 `search_index` 查询最新消息
- [ ] 修改 `build()`：调用 `_loadPreviews()`
- [ ] 添加 `togglePin()` 方法
- [ ] 添加 `deleteTheme()` 方法
- [ ] 添加 `renameTheme()` 方法

#### 5. l10n Keys（5 分钟）
- [ ] 打开 `lib/l10n/app_en.arb` 和 `lib/l10n/app_zh.arb`
- [ ] 添加 `pin` / `unpin` key
- [ ] 添加 `deleteThemeConfirm` key（带参数）
- [ ] 运行 `flutter gen-l10n` 生成代码

#### 6. ThemeListScreen UI 更新（20 分钟）
- [ ] 打开 `lib/ui/features/themes/theme_list_screen.dart`
- [ ] 重构为 `CupertinoPageScaffold` + `CustomScrollView`
- [ ] 设置 `backgroundColor: AppColors.surface`
- [ ] 添加 `CupertinoSliverRefreshControl`
- [ ] 去掉 NavBar 刷新按钮
- [ ] 修改 subtitle：显示 `lastMessagePreview` 或 `formatRelativeTime()`
- [ ] 添加长按 `GestureDetector` + `_showThemeActions()` 方法
- [ ] 实现 `_showThemeActions()`：Action Sheet（重命名/置顶/删除）
- [ ] 实现 `_promptRename()`：重命名对话框
- [ ] 实现 `_confirmDelete()`：删除确认对话框
- [ ] 导入 `formatRelativeTime` 从 `note_browse_screen.dart`

### 验证
- [ ] 运行 `flutter analyze` 检查语法错误
- [ ] 运行 `flutter test` 检查测试通过
- [ ] 手动测试：新建主题、重命名、置顶、删除、下拉刷新
- [ ] 检查配色：主题列表图标颜色是否正确显示

### 预计总工时
约 55 分钟
