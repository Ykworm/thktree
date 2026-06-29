import 'dart:developer' as dev;
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/core/app_paths.dart';

/// Result of a search query.
class SearchResult {
  SearchResult({
    required this.entityType,
    required this.entityId,
    required this.themeId,
    required this.themeTitle,
    required this.entityTitle,
    required this.snippet,
    required this.updatedAt,
  });

  final String entityType;   // 'note' | 'message'
  final String entityId;     // noteId | msgId
  final String themeId;
  final String themeTitle;
  final String entityTitle;
  final String snippet;      // snippet from FTS5 (with highlight markers)
  final String updatedAt;
}

/// Provides full-text search backed by SQLite FTS5.
///
/// Markdown files are the source of truth; search_index is a lossy
/// acceleration layer that can be rebuilt from disk at any time.
class SearchService {
  SearchService({
    required this.db,
    required this.paths,
    required this.noteStoreFactory,
  });

  final Database db;
  final AppPaths paths;
  final NoteStore Function(String themeId) noteStoreFactory;

  // ---------------------------------------------------------------------------
  // Query
  // ---------------------------------------------------------------------------

  /// Run a full-text search query.
  ///
  /// Returns up to [limit] results sorted by BM25 relevance then updatedAt
  /// descending.
  Future<List<SearchResult>> search(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];

    // Escape FTS5 special characters (preserve Chinese characters).
    final sanitized = _sanitizeQuery(query);
    if (sanitized.isEmpty) return [];

    try {
      final rows = await db.rawQuery('''
        SELECT
          entityType,
          entityId,
          themeId,
          themeTitle,
          entityTitle,
          snippet,
          updatedAt
        FROM (
          SELECT
            entityType,
            entityId,
            themeId,
            themeTitle,
            entityTitle,
            snippet(search_index, 1, '<b>', '</b>', '...', 40) AS snippet,
            updatedAt,
            bm25(search_index, 0.0, 1.0, 0.0, 0.0, 0.5, 5.0) AS rank
          FROM search_index
          WHERE search_index MATCH ?
        )
        GROUP BY entityType, entityId
        ORDER BY MIN(rank) ASC, MAX(updatedAt) DESC
        LIMIT ?
      ''', [sanitized, limit]);

      return rows.map((row) => SearchResult(
        entityType: row['entityType']! as String,
        entityId: row['entityId']! as String,
        themeId: row['themeId']! as String,
        themeTitle: row['themeTitle'] as String? ?? '',
        entityTitle: row['entityTitle'] as String? ?? '',
        snippet: row['snippet'] as String? ?? '',
        updatedAt: row['updatedAt'] as String? ?? '',
      )).toList();
    } on DatabaseException catch (e, st) {
      dev.log('[SearchService.search] FTS5 query failed: $e\n$st');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Incremental upsert
  // ---------------------------------------------------------------------------

  /// Upsert a note into the search index.
  ///
  /// Call after note content is saved to disk. Failures are silently logged
  /// and never block the caller.
  Future<void> upsertNote({
    required String noteId,
    required String themeId,
    required String themeTitle,
    required String noteTitle,
    required String body,
  }) async {
    try {
      await db.transaction((txn) async {
        await txn.delete(
          'search_index',
          where: 'entityType = ? AND entityId = ?',
          whereArgs: ['note', noteId],
        );
        await txn.insert('search_index', {
          'entityType': 'note',
          'entityId': noteId,
          'themeId': themeId,
          'themeTitle': themeTitle,
          'entityTitle': noteTitle,
          'content': body,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
      });
    } catch (e, st) {
      dev.log('[SearchService.upsertNote] FAILED noteId=$noteId: $e\n$st');
    }
  }

  /// Upsert a conversation message into the search index.
  ///
  /// Call after [SessionStore.finishAssistant] completes successfully.
  /// Failures are silently logged and never block the caller.
  Future<void> upsertMessage({
    required String nodeId,
    required String themeId,
    required String themeTitle,
    required String nodeTitle,
    required String body,
  }) async {
    try {
      await db.insert('search_index', {
        'entityType': 'message',
        'entityId': nodeId,
        'themeId': themeId,
        'themeTitle': themeTitle,
        'entityTitle': nodeTitle,
        'content': body,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, st) {
      dev.log('[SearchService.upsertMessage] FAILED nodeId=$nodeId: $e\n$st');
    }
  }

  /// Delete a single entity from the search index.
  ///
  /// Used when a note or node is deleted.
  Future<void> delete(String entityType, String entityId) async {
    try {
      await db.delete(
        'search_index',
        where: 'entityType = ? AND entityId = ?',
        whereArgs: [entityType, entityId],
      );
    } catch (e, st) {
      dev.log('[SearchService.delete] FAILED $entityType/$entityId: $e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // Full rebuild
  // ---------------------------------------------------------------------------

  /// Rebuild the entire search index from Markdown files on disk.
  ///
  /// Processes in batches of 50, yielding to the event loop between batches
  /// to avoid blocking UI interactions.
  ///
  /// Returns (totalCount, skippedCount).
  Future<(int, int)> rebuildAll(List<ThemeScanItem> themes) async {
    int total = 0;
    int skipped = 0;

    try {
      await db.delete('search_index'); // clear
      await db.execute('BEGIN TRANSACTION');

      int batchCount = 0;
      for (final theme in themes) {
        // --- Notes ---
        final notesDir = theme.notesDir;
        if (await notesDir.exists()) {
          final entities = await notesDir.list().toList();
          for (final entity in entities) {
            if (entity is! File || !entity.path.endsWith('.md')) continue;
            try {
              final raw = await entity.readAsString();
              final meta = _parseNoteFrontmatter(raw);
              if (meta == null) {
                skipped++;
                continue;
              }
              final body = _extractNoteBody(raw);
              await db.insert('search_index', {
                'entityType': 'note',
                'entityId': meta.noteId,
                'themeId': theme.themeId,
                'themeTitle': theme.title,
                'entityTitle': meta.title,
                'content': body,
                'updatedAt': meta.updatedAt,
              });
              total++;
            } catch (_) {
              skipped++;
            }
            batchCount++;
            if (batchCount % 50 == 0) {
              await db.execute('COMMIT');
              await Future.delayed(Duration.zero); // yield to event loop
              await db.execute('BEGIN TRANSACTION');
            }
          }
        }

        // --- Session messages ---
        final nodesDir = theme.nodesDir;
        if (await nodesDir.exists()) {
          await _scanNodesForRebuild(
            nodesDir: nodesDir,
            themeId: theme.themeId,
            themeTitle: theme.title,
            total: () => total++,       // count successful inserts
            skipped: () => skipped++,
            batchCount: () => batchCount++,
            commitBatch: () async {
              if (batchCount % 50 == 0) {
                await db.execute('COMMIT');
                await Future.delayed(Duration.zero);
                await db.execute('BEGIN TRANSACTION');
              }
            },
          );
        }
      }

      await db.execute('COMMIT');
    } catch (e, st) {
      dev.log('[SearchService.rebuildAll] FAILED: $e\n$st');
      try { await db.execute('ROLLBACK'); } catch (_) {}
      rethrow;
    }

    dev.log('[SearchService.rebuildAll] done: total=$total skipped=$skipped');
    return (total, skipped);
  }

  /// Check whether the search_index table is empty.
  Future<bool> isEmpty() async {
    try {
      final rows = await db.rawQuery(
        'SELECT 1 FROM search_index LIMIT 1',
      );
      return rows.isEmpty;
    } catch (_) {
      return true; // table doesn't exist yet → treat as empty
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Recursively scan nodes/ directories for session.md files.
  Future<void> _scanNodesForRebuild({
    required Directory nodesDir,
    required String themeId,
    required String themeTitle,
    required void Function() total,
    required void Function() skipped,
    required void Function() batchCount,
    required Future<void> Function() commitBatch,
  }) async {
    final entities = await nodesDir.list(followLinks: false).toList();
    for (final entity in entities) {
      if (entity is! Directory) continue;

      // Check for node.meta.json + session.md
      final sessionFile = File('${entity.path}/session.md');
      if (await sessionFile.exists()) {
        try {
          final raw = await sessionFile.readAsString();

          // Skip files still in streaming state
          if (raw.contains('<!-- streaming -->')) {
            skipped();
            batchCount();
            await commitBatch();
            continue;
          }

          final doc = parseSessionMarkdown(raw);
          final nodeTitle = doc.frontmatter['title'] as String? ?? '';

          // Concatenate all user messages as searchable content.
          // We index the whole conversation as one FTS5 row per node
          // (search granularity is "conversation", not per-message).
          final bodyBuf = StringBuffer();
          for (final msg in doc.messages) {
            if (msg.role == SessionRole.user && msg.body.trim().isNotEmpty) {
              bodyBuf.writeln(msg.body.trim());
              bodyBuf.writeln();
            }
          }
          // Also include assistant messages for richer search coverage
          for (final msg in doc.messages) {
            if (msg.role == SessionRole.assistant && msg.body.trim().isNotEmpty) {
              bodyBuf.writeln(msg.body.trim());
              bodyBuf.writeln();
            }
          }

          if (bodyBuf.isEmpty) {
            batchCount();
            await commitBatch();
            continue;
          }

          await db.insert('search_index', {
            'entityType': 'message',
            'entityId': doc.frontmatter['nodeId'] as String? ?? entity.uri.pathSegments.last,
            'themeId': themeId,
            'themeTitle': themeTitle,
            'entityTitle': nodeTitle,
            'content': bodyBuf.toString().trim(),
            'updatedAt': doc.frontmatter['updatedAt'] as String? ?? '',
          });
          total();
        } catch (e) {
          dev.log('[SearchService._scanNodes] skip ${entity.path}: $e');
          skipped();
        }
      }

      batchCount();
      await commitBatch();

      // Recurse into subdirectories
      await _scanNodesForRebuild(
        nodesDir: entity,
        themeId: themeId,
        themeTitle: themeTitle,
        total: total,
        skipped: skipped,
        batchCount: batchCount,
        commitBatch: commitBatch,
      );
    }
  }

  /// Strip YAML frontmatter and return just the body.
  String _extractNoteBody(String raw) {
    final idx = raw.indexOf('\n---\n');
    if (idx < 0) return raw.trim();
    return raw.substring(idx + 5).trim();
  }

  NoteMeta? _parseNoteFrontmatter(String raw) {
    final idx = raw.indexOf('\n---\n');
    if (idx < 0) return null;
    final yaml = raw.substring(0, idx);
    try {
      final map = _parseSimpleYaml(yaml);
      return NoteMeta.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _parseSimpleYaml(String yaml) {
    final map = <String, dynamic>{};
    for (final line in yaml.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final colon = trimmed.indexOf(':');
      if (colon < 0) continue;
      final key = trimmed.substring(0, colon).trim();
      var value = trimmed.substring(colon + 1).trim();
      if (value == 'null') {
        map[key] = null;
      } else if (value.startsWith('"') && value.endsWith('"')) {
        map[key] = value.substring(1, value.length - 1);
      } else {
        map[key] = value;
      }
    }
    return map;
  }

  /// Sanitize a user query for FTS5 MATCH.
  ///
  /// Strips FTS5 operators (AND, OR, NOT, quotes, etc.) to prevent syntax
  /// errors. Keeps alphanumeric and CJK characters.
  String _sanitizeQuery(String input) {
    // Remove quotes and common FTS5 operators.
    final cleaned = input
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('*', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('+', '')
        .replaceAll('-', ' ')
        .replaceAll('^', '')
        .replaceAll('NEAR/', '')
        .replaceAll(RegExp(r'\b(AND|OR|NOT)\b', caseSensitive: false), '')
        .trim();

    if (cleaned.isEmpty) return '';

    // Split into tokens, filter empty, join with space for implicit AND.
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    return tokens.join(' ');
  }
}

/// Minimal metadata extracted during rebuild scans.
class ThemeScanItem {
  ThemeScanItem({
    required this.themeId,
    required this.title,
    required this.notesDir,
    required this.nodesDir,
  });

  final String themeId;
  final String title;
  final Directory notesDir;
  final Directory nodesDir;
}
