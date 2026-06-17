import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/domain/ids.dart';
import 'package:thk_tree/domain/theme.dart';
import 'package:thk_tree/data/models/theme_meta.dart';

class ThemeStore {
  ThemeStore({required this.paths, required this.db});

  final AppPaths paths;
  final Database db;

  /// "未分类" is always pinned to top regardless of DB pinned column.
  static const _kUncategorized = '未分类';

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
        .toList()
      ..sort((a, b) {
        // "未分类" always on top
        if (a.title == _kUncategorized && b.title != _kUncategorized) return -1;
        if (a.title != _kUncategorized && b.title == _kUncategorized) return 1;
        return 0;
      });
  }

  Future<void> togglePin({required String themeId, required bool pinned}) async {
    await db.update(
      'themes',
      {'pinned': pinned ? 1 : 0},
      where: 'themeId = ?',
      whereArgs: [themeId],
    );
  }

  Future<void> deleteTheme({required String themeId}) async {
    // 1. Get themePath
    final rows = await db.query('themes', where: 'themeId = ?', whereArgs: [themeId], limit: 1);
    if (rows.isEmpty) return;
    final themePath = rows.first['themePath'] as String;
    final absPath = paths.toAbsolutePath(themePath);

    // 2. Delete DB records (search_index, nodes, then theme)
    await db.delete('search_index', where: 'themeId = ?', whereArgs: [themeId]);
    await db.delete('nodes', where: 'themeId = ?', whereArgs: [themeId]);
    await db.delete('themes', where: 'themeId = ?', whereArgs: [themeId]);

    // 3. Delete filesystem directory
    final dir = Directory(absPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<ThemeEntity> createTheme({required String title}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    String? themeId;
    Directory? themeDir;
    for (var attempt = 0; attempt < 10; attempt++) {
      final candidate = newThemeId();
      final candidateDir = Directory(p.join(paths.themesDir.path, candidate));
      if (await candidateDir.exists()) continue;

      final existing = await db.query(
        'themes',
        columns: ['themeId'],
        where: 'themeId = ?',
        whereArgs: [candidate],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;

      themeId = candidate;
      themeDir = candidateDir;
      break;
    }
    if (themeId == null || themeDir == null) {
      throw StateError('Failed to allocate themeId');
    }
    await themeDir.create(recursive: true);

    final meta = ThemeMetaV1(
      themeId: themeId,
      title: title,
      createdAtUtcIso8601: now,
      updatedAtUtcIso8601: now,
    );
    final metaPath = p.join(themeDir.path, 'theme.meta.json');
    await _atomicWriteString(metaPath, meta.toJsonString());

    await db.insert(
      'themes',
      {
        'themeId': themeId,
        'title': title,
        'createdAt': now,
        'updatedAt': now,
        'themePath': paths.toRootRelativePath(themeDir.path),
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return meta.toEntity();
  }

  Future<void> renameTheme({required String themeId, required String title}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await db.query('themes', where: 'themeId = ?', whereArgs: [themeId], limit: 1);
    if (rows.isEmpty) {
      throw StateError('Theme not found: $themeId');
    }
    final themePath = p.join(paths.themesDir.path, themeId);
    final metaPath = p.join(themePath, 'theme.meta.json');
    final meta = await _readThemeMeta(metaPath);
    final updated = ThemeMetaV1(
      themeId: meta.themeId,
      title: title,
      createdAtUtcIso8601: meta.createdAtUtcIso8601,
      updatedAtUtcIso8601: now,
    );
    await _atomicWriteString(metaPath, updated.toJsonString());

    await db.update(
      'themes',
      {
        'title': title,
        'updatedAt': now,
      },
      where: 'themeId = ?',
      whereArgs: [themeId],
    );
  }

  Future<void> reindexThemesFromDisk() async {
    // 1. Save current pinned state
    final pinnedRows = await db.query(
      'themes',
      columns: ['themeId'],
      where: 'pinned = 1',
    );
    final pinnedIds = pinnedRows.map((r) => r['themeId'] as String).toSet();

    // 2. Sync from disk
    await paths.ensureCreated();
    final themeDirs = await paths.themesDir.list(followLinks: false).toList();
    final metas = <ThemeMetaV1>[];
    for (final entity in themeDirs) {
      if (entity is! Directory) continue;
      final metaPath = p.join(entity.path, 'theme.meta.json');
      final file = File(metaPath);
      if (!await file.exists()) continue;
      metas.add(await _readThemeMeta(metaPath));
    }

    await db.transaction((txn) async {
      await txn.delete('themes');
      for (final meta in metas) {
        final themePath = p.join(paths.themesDir.path, meta.themeId);
        await txn.insert(
          'themes',
          {
            'themeId': meta.themeId,
            'title': meta.title,
            'createdAt': meta.createdAtUtcIso8601,
            'updatedAt': meta.updatedAtUtcIso8601,
            'themePath': paths.toRootRelativePath(themePath),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      // 3. Restore pinned state
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
}

Future<ThemeMetaV1> _readThemeMeta(String metaPath) async {
  final text = await File(metaPath).readAsString();
  final decoded = jsonDecode(text);
  if (decoded is! Map) {
    throw const FormatException('theme.meta.json is not a map');
  }
  return ThemeMetaV1.fromJson(Map<String, Object?>.from(decoded));
}

Future<void> _atomicWriteString(String filePath, String content) async {
  final tmpPath = '$filePath.tmp';
  final tmpFile = File(tmpPath);
  await tmpFile.writeAsString(content);
  await tmpFile.rename(filePath);
}
