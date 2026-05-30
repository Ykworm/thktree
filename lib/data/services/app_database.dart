import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static Future<AppDatabase> open({required String path}) async {
    final db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) => _createSchema(db),
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
  themePath TEXT NOT NULL
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
  contextSummaryPath TEXT NULL
)
''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_nodes_theme_parent ON nodes(themeId, parentId)');
}
