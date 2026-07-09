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
  /// descending. Falls back to LIKE query for CJK substring matching when
  /// FTS5 returns no results.
  Future<List<SearchResult>> search(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];

    // Escape FTS5 special characters (preserve Chinese characters).
    final sanitized = _sanitizeQuery(query);
    if (sanitized.isEmpty) return [];

    try {
      // Ensure search_index table exists before querying.
      await _ensureSearchIndexTable();

      // Flat query — FTS5 helper functions (snippet/bm25) cannot be invoked
      // inside a subquery that is wrapped by GROUP BY at the outer level;
      // the engine rejects them with "unable to use function X in the
      // requested context". Keep snippet/bm25 directly on the base SELECT.
      //
      // Column number 5 = `content` (entityType=0, entityId=1, themeId=2,
      // themeTitle=3 UNINDEXED, entityTitle=4, content=5, updatedAt=6).
      //
      // Upsert path (upsertNote / upsertMessage) uses transactional
      // DELETE + INSERT to prevent duplicate rows caused by FTS5's lack of
      // PRIMARY KEY semantics; see war-story packages/2026-06-29.
      final rows = await db.rawQuery('''
        SELECT
          entityType,
          entityId,
          themeId,
          themeTitle,
          entityTitle,
          snippet(search_index, 5, '<b>', '</b>', '...', 40) AS snippet,
          updatedAt,
          bm25(search_index, 0.0, 1.0, 0.0, 0.0, 0.5, 5.0) AS rank
        FROM search_index
        WHERE search_index MATCH ?
        ORDER BY rank ASC, updatedAt DESC
        LIMIT ?
      ''', [sanitized, limit]);

      final results = rows.map((row) => SearchResult(
        entityType: row['entityType']! as String,
        entityId: row['entityId']! as String,
        themeId: row['themeId']! as String,
        themeTitle: row['themeTitle'] as String? ?? '',
        entityTitle: row['entityTitle'] as String? ?? '',
        snippet: _cleanSnippet(row['snippet'] as String? ?? ''),
        updatedAt: row['updatedAt'] as String? ?? '',
      )).toList();

      // If FTS5 returned results, return them.
      if (results.isNotEmpty) return results;

      // Fallback: LIKE query for substring matching.
      // FTS5 unicode61 tokenizer has token-boundary limitations for both CJK
      // (consecutive characters treated as one token) and ASCII (CamelCase /
      // snake_case treated as single tokens). LIKE provides universal
      // substring matching as a fallback. SQLite LIKE is case-insensitive for
      // ASCII by default, so "Flutter" matches "flutter" and vice versa.
      return await _searchWithLike(query, limit);
    } on DatabaseException catch (e, st) {
      dev.log('[SearchService.search] FTS5 query failed: $e\n$st');
      // Return empty results instead of crashing the UI when index is missing/corrupt.
      return [];
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
          'content': _tokenizeCjk(body),
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
  ///
  /// Uses transactional DELETE + INSERT because FTS5 virtual tables have no
  /// PRIMARY KEY / UNIQUE constraint, so `ConflictAlgorithm.replace` is a
  /// silent no-op there (extra row inserted, no error). See war-story
  /// packages/2026-06-29-fts5-conflict-replace-silent.md.
  Future<void> upsertMessage({
    required String nodeId,
    required String themeId,
    required String themeTitle,
    required String nodeTitle,
    required String body,
  }) async {
    try {
      await db.transaction((txn) async {
        await txn.delete(
          'search_index',
          where: 'entityType = ? AND entityId = ?',
          whereArgs: ['message', nodeId],
        );
        await txn.insert('search_index', {
          'entityType': 'message',
          'entityId': nodeId,
          'themeId': themeId,
          'themeTitle': themeTitle,
          'entityTitle': nodeTitle,
          'content': _tokenizeCjk(body),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
      });
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
                'content': _tokenizeCjk(body),
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

  /// Ensure the FTS5 search_index virtual table exists.
  /// Creates it if missing (e.g., after a corrupted migration or fresh install).
  Future<void> _ensureSearchIndexTable() async {
    try {
      await db.rawQuery('SELECT 1 FROM search_index LIMIT 1');
    } catch (_) {
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
  }

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
            'content': _tokenizeCjk(bodyBuf.toString().trim()),
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

  /// Tokenize CJK characters for FTS5 indexing.
  ///
  /// The default `unicode61` tokenizer treats consecutive CJK characters
  /// (and ASCII+CJK runs) as a **single** token, making substring searches
  /// like "决策树" impossible against indexed text "决策树算法指南".
  ///
  /// This function inserts a space between every CJK character so that
  /// unicode61 treats each character as its own token. Both the indexed
  /// content and the user query must pass through this function.
  ///
  /// Non-CJK characters (ASCII, punctuation, whitespace) are preserved
  /// as-is — unicode61 already handles those correctly.
  String _tokenizeCjk(String text) {
    final buffer = StringBuffer();
    String? prevChar;
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (_isCjk(ch)) {
        // Insert a separator before the CJK char if the previous char
        // is not already whitespace.
        if (prevChar != null &&
            prevChar != ' ' &&
            prevChar != '\n' &&
            prevChar != '\t' &&
            prevChar != '\r') {
          buffer.write(' ');
        }
        buffer.write(ch);
        buffer.write(' '); // separator after each CJK char
        prevChar = ' ';
      } else {
        buffer.write(ch);
        prevChar = ch;
      }
    }
    return buffer.toString().trim();
  }

  /// Whether [char] is a CJK ideograph that needs per-character tokenization.
  bool _isCjk(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF) || // CJK Unified Ideographs
        (code >= 0x3400 && code <= 0x4DBF); // CJK Extension A
  }

  /// Remove spaces inserted by [_tokenizeCjk] from a snippet string.
  ///
  /// FTS5 `snippet()` extracts fragments from the indexed `content` column,
  /// which stores the tokenized (space-separated) form. This function
  /// collapses the inter-CJK spaces — including those between `</b>`/`<b>`
  /// highlight markers — so the displayed snippet looks natural.
  String _cleanSnippet(String snippet) {
    var result = snippet;
    var prev = '';
    while (result != prev) {
      prev = result;
      // CJK <space> CJK → CJKCJK
      result = result.replaceAllMapped(
        RegExp(r'([\u4e00-\u9fff\u3400-\u4dbf])\s+([\u4e00-\u9fff\u3400-\u4dbf])'),
        (m) => '${m.group(1)}${m.group(2)}',
      );
      // </b> <space> <b> → </b><b>
      result = result.replaceAll('</b> <b>', '</b><b>');
      // CJK <space> </b> → CJK</b>
      result = result.replaceAllMapped(
        RegExp(r'([\u4e00-\u9fff\u3400-\u4dbf])\s+(</b>)'),
        (m) => '${m.group(1)}${m.group(2)}',
      );
      // <b> <space> CJK → <b>CJK
      result = result.replaceAllMapped(
        RegExp(r'(<b>)\s+([\u4e00-\u9fff\u3400-\u4dbf])'),
        (m) => '${m.group(1)}${m.group(2)}',
      );
      // </b> <space> CJK → </b>CJK
      result = result.replaceAllMapped(
        RegExp(r'(</b>)\s+([\u4e00-\u9fff\u3400-\u4dbf])'),
        (m) => '${m.group(1)}${m.group(2)}',
      );
    }
    return result;
  }

  /// Sanitize a user query for FTS5 MATCH.
  ///
  /// Strips FTS5 operators (AND, OR, NOT, quotes, etc.) to prevent syntax
  /// errors. Keeps alphanumeric and CJK characters. CJK characters are
  /// per-character tokenized via [_tokenizeCjk] so that substring searches
  /// like "决策树" match indexed content "决 策 树 算 法 指 南".
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

    // Tokenize CJK characters (insert spaces between each CJK char) so
    // that FTS5 unicode61 treats them as individual tokens.
    final tokenized = _tokenizeCjk(cleaned);

    // Split into tokens, filter empty, join with space for implicit AND.
    final tokens = tokenized
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    return tokens.join(' ');
  }

  /// Fallback LIKE query for substring matching.
  ///
  /// When FTS5 returns no results, use LIKE for universal substring matching.
  /// This handles FTS5 unicode61 tokenizer limitations for both CJK (consecutive
  /// characters treated as one token) and ASCII (CamelCase / snake_case as
  /// single tokens). SQLite LIKE is case-insensitive for ASCII by default.
  Future<List<SearchResult>> _searchWithLike(String query, int limit) async {
    try {
      // Content is stored in tokenized form (CJK chars space-separated).
      // Tokenize the query the same way so LIKE can match.
      final tokenizedQuery = _tokenizeCjk(query);

      final rows = await db.rawQuery('''
        SELECT
          entityType,
          entityId,
          themeId,
          themeTitle,
          entityTitle,
          content,
          updatedAt
        FROM search_index
        WHERE content LIKE ?
        ORDER BY updatedAt DESC
        LIMIT ?
      ''', ['%$tokenizedQuery%', limit]);

      return rows.map((row) {
        final content = row['content'] as String? ?? '';
        final snippet = _cleanSnippet(_extractSnippet(content, tokenizedQuery));
        return SearchResult(
          entityType: row['entityType']! as String,
          entityId: row['entityId']! as String,
          themeId: row['themeId']! as String,
          themeTitle: row['themeTitle'] as String? ?? '',
          entityTitle: row['entityTitle'] as String? ?? '',
          snippet: snippet,
          updatedAt: row['updatedAt'] as String? ?? '',
        );
      }).toList();
    } catch (e, st) {
      dev.log('[SearchService._searchWithLike] FAILED: $e\n$st');
      return [];
    }
  }

  /// Extract snippet around the matched query in content.
  String _extractSnippet(String content, String query, {int contextLength = 40}) {
    if (content.isEmpty) return '';

    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerContent.indexOf(lowerQuery);

    if (index == -1) {
      // Query not found (shouldn't happen if LIKE matched)
      return content.length > contextLength * 2
          ? '${content.substring(0, contextLength * 2)}...'
          : content;
    }

    // Extract context around match
    final start = index > contextLength ? index - contextLength : 0;
    final end = index + query.length + contextLength;
    final snippet = content.substring(start, end.clamp(0, content.length));

    // Add ellipsis
    final prefix = start > 0 ? '...' : '';
    final suffix = end < content.length ? '...' : '';

    // Highlight the match (case-insensitive)
    final highlighted = snippet.replaceAllMapped(
      RegExp(RegExp.escape(query), caseSensitive: false),
      (match) => '<b>${match.group(0)}</b>',
    );

    return '$prefix$highlighted$suffix';
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
