import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static Future<AppDatabase> open({required String path}) async {
    final db = await openDatabase(
      path,
      version: 5,
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

  // FTS5 search index — uses content redundancy for snippet() support
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

/// v4: add FTS5 search_index virtual table
Future<void> _migrateV4(Database db) async {
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
}

/// v5: add pinned column to themes table
Future<void> _migrateV5(Database db) async {
  await _addColumnIfNotExists(db, 'themes', 'pinned', 'INTEGER NOT NULL DEFAULT 0');
  // Mark "未分类" theme as pinned (backward compat)
  await db.execute("UPDATE themes SET pinned = 1 WHERE title = '未分类'");
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
