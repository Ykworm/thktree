import 'dart:developer' as dev;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static Future<AppDatabase> open({required String path}) async {
    final db = await openDatabase(
      path,
      version: 6,
      onCreate: (db, version) => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createSchema(db);
        if (oldVersion < 3) {
          await _migrateV3(db);
        }
        if (oldVersion < 4) {
          await _migrateV4(db);
        }
        if (oldVersion < 5) {
          await _migrateV5(db);
        }
        if (oldVersion < 6) {
          await _migrateV6(db);
        }
      },
      onOpen: (db) => _createSchema(db),
    );
    return AppDatabase._(db);
  }
}

Future<void> _createSchema(Database db) async {
  await db.execute('''
CREATE TABLE IF NOT EXISTS themes (
  themeId TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  themePath TEXT NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0
)
''');

  await db.execute('''
CREATE TABLE IF NOT EXISTS nodes (
  nodeId TEXT PRIMARY KEY,
  themeId TEXT NOT NULL,
  parentId TEXT NULL,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  nodePath TEXT NOT NULL,
  sessionPath TEXT NOT NULL,
  contextSummaryPath TEXT NULL,
  sortOrder INTEGER NOT NULL DEFAULT 0,
  sourceExcerpt TEXT NULL,
  sourceType TEXT NULL
)
''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_nodes_theme_parent ON nodes(themeId, parentId)');

  // FTS5 search index — uses content redundancy for snippet() support.
  // 在 Android 等默认未启用 FTS5 模块的系统上，降级为普通表，保证数据库
  // 仍能打开，主题列表、预览等不依赖 FTS5 的查询继续工作。
  await _createSearchIndex(db);
}

/// 创建 search_index。优先 FTS5 虚拟表；平台不支持时降级为普通表。
///
/// 部分 Android 系统 SQLite 默认未启用 FTS5 模块，若此时强制建虚拟表
/// 会导致整个数据库打开失败，进而所有依赖数据库的 provider 都卡住。
/// 降级为普通表后主题列表、预览等不依赖 FTS5 的查询仍可工作。
Future<void> _createSearchIndex(Database db) async {
  try {
    await db.execute('''
CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
  entityType,
  entityId,
  themeId,
  themeTitle UNINDEXED,
  entityTitle,
  content,
  updatedAt UNINDEXED
)
''');
  } catch (e) {
    dev.log('[app_database] FTS5 unavailable, falling back to plain search_index table: $e');
    await db.execute('''
CREATE TABLE IF NOT EXISTS search_index (
  entityType TEXT,
  entityId TEXT,
  themeId TEXT,
  themeTitle TEXT,
  entityTitle TEXT,
  content TEXT,
  updatedAt TEXT
)
''');
  }
}

/// v3: add sortOrder, sourceExcerpt, sourceType columns to nodes table
Future<void> _migrateV3(Database db) async {
  await _addColumnIfNotExists(db, 'nodes', 'sortOrder', 'INTEGER NOT NULL DEFAULT 0');
  await _addColumnIfNotExists(db, 'nodes', 'sourceExcerpt', 'TEXT DEFAULT NULL');
  await _addColumnIfNotExists(db, 'nodes', 'sourceType', 'TEXT DEFAULT NULL');
  // backfill sortOrder from createdAt
  await db.execute('''
    UPDATE nodes SET sortOrder = CAST(
      (julianday(createdAt) - julianday('1970-01-01')) * 86400000 AS INTEGER
    ) WHERE sortOrder IS NULL OR sortOrder = 0
  ''');
}

/// v4: add FTS5 search_index table (fallback to plain table on unsupported SQLite).
Future<void> _migrateV4(Database db) async {
  await _createSearchIndex(db);
}

/// v5: add pinned column to themes table
Future<void> _migrateV5(Database db) async {
  await _addColumnIfNotExists(db, 'themes', 'pinned', 'INTEGER NOT NULL DEFAULT 0');
  // Mark "未分类" theme as pinned (backward compat)
  await db.execute("UPDATE themes SET pinned = 1 WHERE title = '未分类'");
}

/// v6: rebuild search_index with CJK per-character tokenization.
///
/// The `content` column now stores CJK text with spaces between each
/// character (see `SearchService._tokenizeCjk`). Old rows use the old
/// format, so we drop and recreate the table. `searchServiceProvider`
/// detects the empty table and auto-rebuilds from disk on next launch.
///
/// 注意：在 FTS5 未启用的系统上（如默认 Android SQLite），回退为普通表，
/// 搜索功能受限，但其余查询可继续工作。
Future<void> _migrateV6(Database db) async {
  await db.execute('DROP TABLE IF EXISTS search_index');
  await _createSearchIndex(db);
}

Future<void> _addColumnIfNotExists(
  Database db,
  String table,
  String column,
  String type,
) async {
  try {
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  } catch (_) {
    // column already exists
  }
}
