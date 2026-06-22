# DB 一致性保障方案重设计

## 背景

### 原始 bug

`getSessionPathForNode` 每次调用都执行全量 reindex（`reindexThemesFromDisk` + `reindexNodesFromDisk`），两者都使用 `db.transaction()`。当两个协程并发调用时（例如第一条消息流式完成后的 `_updateSearchIndex` 和第二条消息的 `sendUserMessage`），两个 `db.transaction()` 在同一个 SQLite 连接上竞争，导致嵌套事务崩溃。

**临时修复**（commit 3607c00）：移除了 `getSessionPathForNode` 里的 reindex 块。

### 设计缺陷

reindex 被当作"免费操作"无条件执行，但实际开销很大：
- 磁盘 I/O（遍历目录 + 读取 meta.json）
- DB I/O（DELETE + 循环 INSERT）
- 事务锁（`db.transaction()` 占用 SQLite 连接）
- 每次 `_read()`（流式 delta）都触发全量 reindex

## 设计决策

### D1：统一 disk-first 写入顺序

所有操作统一为"先写 disk，再写 DB"。disk 是 source of truth。

| 操作 | 当前顺序 | 需要调整 |
|------|---------|---------|
| `createChatNode` | disk → DB | 不用改 |
| `deleteNodeSubtree` | disk → DB | 不用改 |
| `renameTheme` | disk → DB | 不用改（已确认） |
| `updateNodeTitle` | **DB → disk** | **需要调换为 disk → DB** |

### D2：启动时轻量同步

替代原来散落在各处的 reindex。启动时做一次，之后直接用 DB。

同步逻辑：
1. 扫描磁盘目录，从 meta.json 读出所有 nodeId 集合
2. 查 DB 得到所有 nodeId 集合
3. disk 有、DB 没有 → 读 meta.json，INSERT INTO nodes/themes
4. DB 有、disk 没有 → DELETE FROM nodes/themes
5. 都有 → 跳过（正常情况，99% 的节点）

### D3：移除散落的 reindex

| 位置 | 操作 |
|------|------|
| `getSessionPathForNode` | ✅ 已移除（commit 3607c00） |
| `ThemeDetailController._load()` | 移除 reindexThemesFromDisk + reindexNodesFromDisk |
| `ThemeListController.build()` | 移除 reindexThemesFromDisk |

## 实现计划

### Step 1：调换 `updateNodeTitle` 写入顺序

文件：`lib/data/stores/node_store.dart`

当前顺序（DB → disk）：
```dart
// 1. Update SQLite
await db.update('nodes', {'title': newTitle, 'updatedAt': now}, ...);
// 2. Update meta.json
await _atomicWriteString(metaPath, updated.toJsonString());
// 3. Update session.md frontmatter
await _atomicWriteString(absPath, updatedSession);
```

改为 disk-first：
```dart
// 1. Update meta.json（先写 disk）
final rows = await db.query('nodes', columns: ['nodePath'], ...);
final metaPath = ...;
final meta = await readNodeMeta(metaPath);
final updated = meta.copyWith(title: newTitle, updatedAtUtcIso8601: now);
await _atomicWriteString(metaPath, updated.toJsonString());

// 2. Update session.md frontmatter（disk）
await _atomicWriteString(absPath, updatedSession);

// 3. Update SQLite（最后写 DB）
await db.update('nodes', {'title': newTitle, 'updatedAt': now}, ...);
```

注意：需要先查 DB 获取 nodePath 和 sessionPath（只读查询，不写），然后再写 disk，最后写 DB。

### Step 2：实现启动时轻量同步

文件：`lib/data/stores/theme_store.dart` 和 `lib/data/stores/node_store.dart`

新增方法 `syncFromDisk()`：

**ThemeStore.syncFromDisk()**：
```dart
Future<void> syncFromDisk() async {
  // 1. 扫描磁盘目录得到 themeId 集合
  final diskThemes = <String, ThemeMetaV1>{};
  for (final entity in await paths.themesDir.list().toList()) {
    if (entity is! Directory) continue;
    final metaPath = p.join(entity.path, 'theme.meta.json');
    if (!await File(metaPath).exists()) continue;
    final meta = await _readThemeMeta(metaPath);
    diskThemes[meta.themeId] = meta;
  }

  // 2. 查 DB 得到 themeId 集合
  final dbRows = await db.query('themes', columns: ['themeId']);
  final dbIds = dbRows.map((r) => r['themeId'] as String).toSet();

  // 3. disk 有、DB 没有 → INSERT
  for (final entry in diskThemes.entries) {
    if (!dbIds.contains(entry.key)) {
      await db.insert('themes', {...});
    }
  }

  // 4. DB 有、disk 没有 → DELETE
  for (final id in dbIds) {
    if (!diskThemes.containsKey(id)) {
      await db.delete('themes', where: 'themeId = ?', whereArgs: [id]);
    }
  }
}
```

**NodeStore.syncFromDisk()**：
```dart
Future<void> syncFromDisk({required String themePath}) async {
  // 类似逻辑：扫描 themePath 下的 nodes/ 目录
  // 比较 disk nodeId 集合 vs DB nodeId 集合
  // 补写或清理
}
```

### Step 3：在启动流程中调用同步

文件：`lib/ui/core/app_services.dart`

在 `sessionStoreProvider` 或 `appDatabaseProvider` 初始化时调用同步：
```dart
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  final db = await AppDatabase.open(path: paths.indexDbPath);
  // 启动时同步
  final themeStore = ThemeStore(paths: paths, db: db.db);
  await themeStore.syncFromDisk();
  final themes = await themeStore.listThemes();
  for (final theme in themes) {
    final nodeStore = NodeStore(db: db.db, paths: paths);
    await nodeStore.syncFromDisk(themePath: ...);
  }
  return db;
});
```

### Step 4：移除散落的 reindex

**ThemeDetailController._load()**：
```dart
// 移除前：
await themeStore.reindexThemesFromDisk();
await nodeStore.reindexNodesFromDisk(themePath: themePath);

// 移除后：直接查 DB
final themeRow = await nodeStore.getThemeRow(themeId: themeId);
final rawNodes = await nodeStore.listNodes(themeId: themeId);
```

**ThemeListController.build()**：
```dart
// 移除前：
await store.reindexThemesFromDisk();

// 移除后：
final themes = await store.listThemes();
```

**ThemeListController.reindex()**：
```dart
// 改为调用启动同步
Future<void> reindex() async {
  final themeStore = await ref.read(themeStoreProvider.future);
  await themeStore.syncFromDisk();
  state = AsyncData(await _loadPreviews(await themeStore.listThemes()));
}
```

## 验收方式

### 关键路径集成测试

1. 发送第一条消息 → 流式完成 → 发送第二条消息 → 不报嵌套事务错误
2. 新建 theme → 重启 app → theme 在列表中
3. 新建 node → 重启 app → node 在列表中
4. 删除 node → 重启 app → node 不在列表中
5. 改 node 标题 → 重启 app → 标题已更新

### 手工验证

1. 连续快速发送多条消息，观察是否还有嵌套事务错误
2. force-kill app 后重启，验证数据一致性

## 假设与默认值

- disk 是 source of truth（index 数据从 disk meta.json 恢复）
- 启动同步只处理 themes 和 nodes 表，不处理 search_index（search_index 有独立的 rebuildAll 机制）
- `_atomicWriteString` 的原子性（tmp + rename）已足够保证 disk 写入不会出现半截数据
