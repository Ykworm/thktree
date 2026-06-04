import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/domain/ids.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/data/models/node_meta.dart';
import 'package:thk_tree/data/services/session_markdown.dart';

class NodeStore {
  NodeStore({required this.db, required this.paths});

  final Database db;
  final AppPaths paths;

  Future<void> reindexNodesFromDisk({required String themePath}) async {
    final themeId = await _getThemeIdByPath(themePath);
    final nodesDir = Directory(p.join(themePath, 'nodes'));
    final records = <_NodeDiskRecord>[];
    if (await nodesDir.exists()) {
      await _collectNodeRecords(nodesDir, expectedThemeId: themeId, records: records);
    }

    // Pre-read session.md files outside the DB transaction to avoid
    // holding a write lock during file I/O.
    final sourceInfo = <String, (String?, String?)>{}; // nodeId -> (excerpt, type)
    for (final record in records) {
      final sessionPath = p.join(record.nodeDir.path, 'session.md');
      final sessionFile = File(sessionPath);
      if (await sessionFile.exists()) {
        try {
          final rawText = await sessionFile.readAsString();
          final doc = parseSessionMarkdown(rawText);
          for (final msg in doc.messages) {
            if (msg.role == SessionRole.user && msg.body.trim().isNotEmpty) {
              final body = msg.body.trim();
              final excerpt = body.length <= 80 ? body : '${body.substring(0, 80)}...';
              sourceInfo[record.meta.nodeId] = (excerpt, 'conversation');
              break;
            }
          }
        } catch (_) {
          // malformed session.md — skip excerpt
        }
      }
    }

    await db.transaction((txn) async {
      if (records.isEmpty) {
        await txn.delete('nodes', where: 'themeId = ?', whereArgs: [themeId]);
        return;
      }

      final liveIds = records.map((record) => record.meta.nodeId).toList(growable: false);
      final placeholders = List.filled(liveIds.length, '?').join(', ');
      await txn.delete(
        'nodes',
        where: 'themeId = ? AND nodeId NOT IN ($placeholders)',
        whereArgs: [themeId, ...liveIds],
      );

      for (final record in records) {
        final createdAtMillis = DateTime.tryParse(record.meta.createdAtUtcIso8601)?.millisecondsSinceEpoch
            ?? DateTime.now().toUtc().millisecondsSinceEpoch;
        final sessionPath = p.join(record.nodeDir.path, 'session.md');
        final info = sourceInfo[record.meta.nodeId];

        // Preserve existing sortOrder if it was manually set (e.g., by drag-to-reorder)
        int? existingSortOrder;
        final existingRows = await txn.query(
          'nodes',
          columns: ['sortOrder'],
          where: 'nodeId = ?',
          whereArgs: [record.meta.nodeId],
          limit: 1,
        );
        if (existingRows.isNotEmpty) {
          existingSortOrder = existingRows.first['sortOrder'] as int?;
        }

        await txn.insert(
          'nodes',
          {
            'nodeId': record.meta.nodeId,
            'themeId': record.meta.themeId,
            'parentId': record.meta.parentId,
            'kind': record.meta.kind.value,
            'title': record.meta.title,
            'createdAt': record.meta.createdAtUtcIso8601,
            'updatedAt': record.meta.updatedAtUtcIso8601,
            'nodePath': paths.toRootRelativePath(record.nodeDir.path),
            'sessionPath': paths.toRootRelativePath(sessionPath),
            'contextSummaryPath': null,
            'sortOrder': existingSortOrder ?? createdAtMillis,
            'sourceExcerpt': info?.$1,
            'sourceType': info?.$2,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> _collectNodeRecords(
    Directory dir, {
    required String expectedThemeId,
    required List<_NodeDiskRecord> records,
  }) async {
    final entities = await dir.list(followLinks: false).toList();
    for (final entity in entities) {
      if (entity is! Directory) continue;
      final metaPath = p.join(entity.path, 'node.meta.json');
      if (!await File(metaPath).exists()) {
        await _collectNodeRecords(entity, expectedThemeId: expectedThemeId, records: records);
        continue;
      }
      try {
        final meta = await readNodeMeta(metaPath);
        if (meta.themeId == expectedThemeId) {
          records.add(_NodeDiskRecord(nodeDir: entity, meta: meta));
        }
        await _collectNodeRecords(entity, expectedThemeId: expectedThemeId, records: records);
      } catch (_) {
        // skip malformed nodes
      }
    }
  }

  Future<List<NodeEntity>> listNodes({required String themeId}) async {
    try {
      final rows = await db.query(
        'nodes',
        where: 'themeId = ?',
        whereArgs: [themeId],
        orderBy: 'sortOrder ASC, createdAt ASC',
      );
      final nodes = rows
          .map(
            (row) => NodeEntity(
              themeId: row['themeId']! as String,
              nodeId: row['nodeId']! as String,
              parentId: row['parentId'] as String?,
              kind: switch (row['kind']! as String) {
                'chat' => NodeKind.chat,
                'summary' => NodeKind.summary,
                _ => NodeKind.chat,
              },
              title: row['title']! as String,
              createdAtUtcIso8601: row['createdAt']! as String,
              updatedAtUtcIso8601: row['updatedAt']! as String,
              sortOrder: (row['sortOrder'] as int?) ?? 0,
              sourceExcerpt: row['sourceExcerpt'] as String?,
              sourceType: row['sourceType'] as String?,
            ),
          )
          .toList(growable: false);
      dev.log('[NODE_STORE] listNodes result:');
      for (final n in nodes) {
        dev.log('  ${n.parentId ?? "(root)"} > ${n.title} sortOrder=${n.sortOrder}');
      }
      return nodes;
    } catch (e, st) {
      dev.log('[listNodes] ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<NodeEntity> createChatNode({
    required String themeId,
    required String themePath,
    required String? parentId,
    required String title,
    String? systemPrompt,
  }) async {
    dev.log('[NodeStore.createChatNode] start, themeId=$themeId, title=$title, parentId=$parentId');
    final now = DateTime.now().toUtc().toIso8601String();
    
    String? parentDirPath;
    if (parentId != null) {
      final row = await getNodeRow(nodeId: parentId);
      final resolvedParentDir = await _resolveNodeDirectory(
        themePath: themePath,
        nodeId: parentId,
        dbNodePath: row['nodePath'] as String?,
      );
      if (resolvedParentDir == null) {
        throw StateError('Parent node directory not found: $parentId');
      }
      parentDirPath = resolvedParentDir.path;
      dev.log('[NodeStore.createChatNode] parent nodePath=$parentDirPath');
    }
    
    final baseNodesDir = Directory(p.join(themePath, 'nodes'));
    final rootParentDir = parentDirPath != null ? Directory(parentDirPath) : baseNodesDir;

    String? nodeId;
    Directory? nodeDir;
    for (var attempt = 0; attempt < 10; attempt++) {
      final candidate = newNodeId();
      if (parentId != null && parentId == candidate) continue;

      final candidateDir = Directory(p.join(rootParentDir.path, candidate));
      if (await candidateDir.exists()) continue;

      final existing = await db.query(
        'nodes',
        columns: ['nodeId'],
        where: 'nodeId = ?',
        whereArgs: [candidate],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;

      nodeId = candidate;
      nodeDir = candidateDir;
      break;
    }
    if (nodeId == null || nodeDir == null) {
      throw StateError('Failed to allocate nodeId');
    }
    dev.log('[NodeStore.createChatNode] allocated nodeId=$nodeId, dir=${nodeDir.path}');
    await nodeDir.create(recursive: true);
    dev.log('[NodeStore.createChatNode] dir created');

    final meta = NodeMetaV1(
      themeId: themeId,
      nodeId: nodeId,
      parentId: parentId,
      kind: NodeKind.chat,
      title: title,
      createdAtUtcIso8601: now,
      updatedAtUtcIso8601: now,
    );
    final metaPath = p.join(nodeDir.path, 'node.meta.json');
    await _atomicWriteString(metaPath, meta.toJsonString());
    dev.log('[NodeStore.createChatNode] node.meta.json written');

    final sessionPath = p.join(nodeDir.path, 'session.md');
    await _atomicWriteString(sessionPath, _initialSessionMarkdown(meta, systemPrompt: systemPrompt));
    dev.log('[NodeStore.createChatNode] session.md written, path=$sessionPath');

    final nowMs = DateTime.parse(now).millisecondsSinceEpoch;

    await db.insert(
      'nodes',
      {
        'nodeId': nodeId,
        'themeId': themeId,
        'parentId': parentId,
        'kind': meta.kind.value,
        'title': title,
        'createdAt': now,
        'updatedAt': now,
        'nodePath': paths.toRootRelativePath(nodeDir.path),
        'sessionPath': paths.toRootRelativePath(sessionPath),
        'contextSummaryPath': null,
        'sortOrder': nowMs,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    dev.log('[NodeStore.createChatNode] DB insert done, nodeId=$nodeId');

    return meta.toEntity();
  }

  Future<int> deleteNodeSubtree({required String nodeId}) async {
    final row = await getNodeRow(nodeId: nodeId);
    final themeId = row['themeId']! as String;
    final nodePath = row['nodePath']! as String;
    final themeRow = await getThemeRow(themeId: themeId);
    final themePath = themeRow['themePath']! as String;
    final ids = await _collectSubtreeNodeIds(nodeId);
    final nodeDir = await _resolveNodeDirectory(
      themePath: themePath,
      nodeId: nodeId,
      dbNodePath: nodePath,
    );

    if (nodeDir != null && await nodeDir.exists()) {
      await nodeDir.delete(recursive: true);
    }

    await db.transaction((txn) async {
      final placeholders = List.filled(ids.length, '?').join(', ');
      await txn.delete(
        'nodes',
        where: 'nodeId IN ($placeholders)',
        whereArgs: ids,
      );
    });

    await reindexNodesFromDisk(themePath: themePath);

    return ids.length;
  }

  Future<List<String>> _collectSubtreeNodeIds(String rootNodeId) async {
    final ids = <String>[];
    final queue = <String>[rootNodeId];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      ids.add(current);

      final childRows = await db.query(
        'nodes',
        columns: ['nodeId'],
        where: 'parentId = ?',
        whereArgs: [current],
      );
      for (final row in childRows) {
        queue.add(row['nodeId']! as String);
      }
    }

    return ids;
  }

  Future<Map<String, Object?>> getThemeRow({required String themeId}) async {
    final rows = await db.query('themes', where: 'themeId = ?', whereArgs: [themeId], limit: 1);
    if (rows.isEmpty) {
      throw StateError('Theme not found: $themeId');
    }
    return _inflateThemeRow(rows.single);
  }

  Future<Map<String, Object?>> getNodeRow({required String nodeId}) async {
    final rows = await db.query('nodes', where: 'nodeId = ?', whereArgs: [nodeId], limit: 1);
    if (rows.isEmpty) {
      throw StateError('Node not found: $nodeId');
    }
    return _inflateNodeRow(rows.single);
  }

  Future<void> updateNodeSessionPath({
    required String nodeId,
    required String sessionPath,
  }) async {
    await db.update(
      'nodes',
      {
        'sessionPath': paths.toRootRelativePath(sessionPath),
        'nodePath': paths.toRootRelativePath(p.dirname(sessionPath)),
      },
      where: 'nodeId = ?',
      whereArgs: [nodeId],
    );
  }

  /// Update sortOrder for a node (used by drag-to-reorder).
  Future<void> reorderNode({
    required String nodeId,
    required int newSortOrder,
  }) async {
    dev.log('[NODE_STORE] reorderNode $nodeId -> $newSortOrder');
    await db.update(
      'nodes',
      {'sortOrder': newSortOrder},
      where: 'nodeId = ?',
      whereArgs: [nodeId],
    );
  }

  /// Update sourceExcerpt and sourceType for a node (called after branch creation).
  Future<void> updateNodeSourceInfo({
    required String nodeId,
    required String sourceExcerpt,
    required String sourceType,
  }) async {
    await db.update(
      'nodes',
      {
        'sourceExcerpt': sourceExcerpt,
        'sourceType': sourceType,
      },
      where: 'nodeId = ?',
      whereArgs: [nodeId],
    );
  }

  /// Update node title (used by rename feature).
  Future<void> updateNodeTitle({
    required String nodeId,
    required String newTitle,
  }) async {
    // 1. Update SQLite
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'nodes',
      {'title': newTitle, 'updatedAt': now},
      where: 'nodeId = ?',
      whereArgs: [nodeId],
    );

    // 2. Update meta.json
    final rows = await db.query(
      'nodes',
      columns: ['nodePath'],
      where: 'nodeId = ?',
      whereArgs: [nodeId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final nodePath = rows.single['nodePath'] as String?;
    if (nodePath == null) return;

    final metaPath = p.join(paths.toAbsolutePath(nodePath), 'node.meta.json');
    final meta = await readNodeMeta(metaPath);
    final updated = meta.copyWith(title: newTitle, updatedAtUtcIso8601: now);
    await _atomicWriteString(metaPath, updated.toJsonString());

    // 3. Update session.md frontmatter
    final sessionRows = await db.query(
      'nodes',
      columns: ['sessionPath'],
      where: 'nodeId = ?',
      whereArgs: [nodeId],
      limit: 1,
    );
    if (sessionRows.isNotEmpty) {
      final sessionPath = sessionRows.single['sessionPath'] as String?;
      if (sessionPath != null) {
        final absPath = paths.toAbsolutePath(sessionPath);
        final file = File(absPath);
        if (await file.exists()) {
          final sessionContent = await file.readAsString();
          final updatedSession = updateSessionFrontmatter(sessionContent, {'title': newTitle});
          await _atomicWriteString(absPath, updatedSession);
        }
      }
    }
  }

  Future<String> _getThemeIdByPath(String themePath) async {
    final themePathRel = paths.toRootRelativePath(themePath);
    final rows = await db.query(
      'themes',
      columns: ['themeId'],
      where: 'themePath = ?',
      whereArgs: [themePathRel],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Theme not found for path: $themePath');
    }
    return rows.single['themeId']! as String;
  }

  Future<Directory?> _resolveNodeDirectory({
    required String themePath,
    required String nodeId,
    required String? dbNodePath,
  }) async {
    if (dbNodePath != null) {
      final dbDir = Directory(paths.toAbsolutePath(dbNodePath));
      if (await _isMatchingNodeDirectory(dbDir, nodeId)) {
        return dbDir;
      }
    }

    final nodesDir = Directory(p.join(themePath, 'nodes'));
    if (!await nodesDir.exists()) {
      return null;
    }
    return _findNodeDirectory(nodesDir, nodeId);
  }

  Future<Directory?> _findNodeDirectory(Directory dir, String nodeId) async {
    final entities = await dir.list(followLinks: false).toList();
    for (final entity in entities) {
      if (entity is! Directory) continue;
      if (await _isMatchingNodeDirectory(entity, nodeId)) {
        return entity;
      }
      final found = await _findNodeDirectory(entity, nodeId);
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  Future<bool> _isMatchingNodeDirectory(Directory dir, String nodeId) async {
    if (!await dir.exists()) {
      return false;
    }
    final metaPath = p.join(dir.path, 'node.meta.json');
    if (!await File(metaPath).exists()) {
      return false;
    }
    try {
      final meta = await readNodeMeta(metaPath);
      return meta.nodeId == nodeId;
    } catch (_) {
      return false;
    }
  }

  Map<String, Object?> _inflateThemeRow(Map<String, Object?> row) {
    final themeId = row['themeId']! as String;
    return {
      ...row,
      'themePath': p.join(paths.themesDir.path, themeId),
    };
  }

  Map<String, Object?> _inflateNodeRow(Map<String, Object?> row) {
    final inflated = <String, Object?>{
      ...row,
      'nodePath': paths.toAbsolutePath(row['nodePath']! as String),
      'sessionPath': paths.toAbsolutePath(row['sessionPath']! as String),
    };
    final contextSummaryPath = row['contextSummaryPath'] as String?;
    if (contextSummaryPath != null) {
      inflated['contextSummaryPath'] = paths.toAbsolutePath(contextSummaryPath);
    }
    return inflated;
  }
}

class _NodeDiskRecord {
  _NodeDiskRecord({required this.nodeDir, required this.meta});

  final Directory nodeDir;
  final NodeMetaV1 meta;
}

String _initialSessionMarkdown(NodeMetaV1 meta, {String? systemPrompt}) {
  final parentIdText = meta.parentId == null ? 'null' : '"${meta.parentId}"';
  final sb = StringBuffer()
    ..writeln('---')
    ..writeln('schema: session/v1')
    ..writeln('themeId: "${meta.themeId}"')
    ..writeln('nodeId: "${meta.nodeId}"')
    ..writeln('kind: "${meta.kind.value}"')
    ..writeln('parentId: $parentIdText')
    ..writeln('title: "${meta.title}"')
    ..writeln('createdAt: "${meta.createdAtUtcIso8601}"')
    ..writeln('updatedAt: "${meta.updatedAtUtcIso8601}"');
  if (systemPrompt != null && systemPrompt.isNotEmpty) {
    sb.writeln('systemPrompt: |');
    for (final line in systemPrompt.split('\n')) {
      sb.writeln('  $line');
    }
  }
  sb.writeln('---');
  sb.writeln();
  return sb.toString();
}

Future<NodeMetaV1> readNodeMeta(String metaPath) async {
  final text = await File(metaPath).readAsString();
  final decoded = jsonDecode(text);
  if (decoded is! Map) {
    throw const FormatException('node.meta.json is not a map');
  }
  return NodeMetaV1.fromJson(Map<String, Object?>.from(decoded));
}

Future<void> _atomicWriteString(String filePath, String content) async {
  final tmpPath = '$filePath.tmp';
  final tmpFile = File(tmpPath);
  await tmpFile.writeAsString(content);
  await tmpFile.rename(filePath);
}
