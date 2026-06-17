import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:thk_tree/domain/ids.dart';

class NoteMeta {
  NoteMeta({
    required this.themeId,
    required this.noteId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.sourceNodeId,
    this.spawnedNodeId,
    this.preview,
  });

  final String themeId;
  final String noteId;
  final String title;
  final String createdAt;
  final String updatedAt;
  final String? sourceNodeId;
  final String? spawnedNodeId;

  /// Runtime-only: first ~60 chars of body, populated by [NoteStore.listNoteMetas].
  String? preview;

  factory NoteMeta.fromJson(Map<String, dynamic> json) => NoteMeta(
        themeId: json['themeId'] as String,
        noteId: json['noteId'] as String,
        title: json['title'] as String? ?? '',
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
        sourceNodeId: json['sourceNodeId'] as String?,
        spawnedNodeId: json['spawnedNodeId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'themeId': themeId,
        'noteId': noteId,
        'title': title,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        if (sourceNodeId != null) 'sourceNodeId': sourceNodeId,
        if (spawnedNodeId != null) 'spawnedNodeId': spawnedNodeId,
      };
}

class Note {
  Note({required this.meta, required this.body});

  final NoteMeta meta;
  final String body;
}

class NoteStore {
  NoteStore({required this.notesDir});

  final Directory notesDir;

  Future<List<NoteMeta>> listNoteMetas({bool includePreview = false}) async {
    if (!await notesDir.exists()) return [];
    final entities = await notesDir.list().toList();
    final metas = <NoteMeta>[];
    for (final entity in entities) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      try {
        final raw = await entity.readAsString();
        final meta = _parseFrontmatter(raw);
        if (meta == null) continue;
        if (includePreview) {
          final idx = raw.indexOf('\n---\n');
          if (idx >= 0) {
            final body = raw.substring(idx + 5).trim();
            meta.preview = body.isEmpty
                ? null
                : (body.length <= 60 ? body : '${body.substring(0, 60)}...');
          }
        }
        metas.add(meta);
      } catch (_) {}
    }
    metas.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return metas;
  }

  Future<String> readBody(String noteId) async {
    final raw = await _file(noteId).readAsString();
    final idx = raw.indexOf('\n---\n');
    if (idx < 0) return '';
    return raw.substring(idx + 5).trim();
  }

  Future<NoteMeta> createNote({
    required String themeId,
    required String title,
  }) async {
    final noteId = newNoteId();
    final now = DateTime.now().toUtc().toIso8601String();
    final frontmatter = {
      'schema': 'note/v1',
      'themeId': themeId,
      'noteId': noteId,
      'title': title,
      'createdAt': now,
      'updatedAt': now,
    };
    final yaml = _toYaml(frontmatter);
    final content = '$yaml\n';
    await notesDir.create(recursive: true);
    await _file(noteId).writeAsString(content);
    return NoteMeta(
      themeId: themeId,
      noteId: noteId,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> writeBody(String noteId, String body) async {
    final raw = await _file(noteId).readAsString();
    final now = DateTime.now().toUtc().toIso8601String();

    final frontEnd = raw.indexOf('\n---\n');
    final frontmatter = frontEnd >= 0 ? raw.substring(0, frontEnd) : raw.trim();
    final updated = _updateYamlUpdatedAt(frontmatter, now);
    await _file(noteId).writeAsString('$updated\n---\n\n$body\n');
  }

  /// Delete a note file by noteId.
  /// Returns 1 if the file was deleted, 0 if it did not exist.
  Future<int> deleteNote({required String noteId}) async {
    final file = _file(noteId);
    if (!await file.exists()) return 0;
    await file.delete();
    return 1;
  }

  /// Rename a note by updating its title in the frontmatter.
  Future<void> renameNote({
    required String noteId,
    required String newTitle,
  }) async {
    final raw = await _file(noteId).readAsString();
    final now = DateTime.now().toUtc().toIso8601String();

    final frontEnd = raw.indexOf('\n---\n');
    if (frontEnd < 0) {
      throw StateError('Invalid note format: $noteId');
    }

    String frontmatter = raw.substring(0, frontEnd);
    String body = raw.substring(frontEnd + 5);

    // Update title in frontmatter
    final updatedFrontmatter = _updateYamlTitle(frontmatter, newTitle);
    // Update updatedAt
    final finalFrontmatter = _updateYamlUpdatedAt(updatedFrontmatter, now);

    await _file(noteId).writeAsString('$finalFrontmatter\n---\n$body');
  }

  Future<void> appendBody(String noteId, String text) async {
    final raw = await _file(noteId).readAsString();
    final now = DateTime.now().toUtc().toIso8601String();

    final frontEnd = raw.indexOf('\n---\n');
    String frontmatter;
    String body;
    if (frontEnd >= 0) {
      frontmatter = raw.substring(0, frontEnd);
      body = raw.substring(frontEnd + 5).trim();
    } else {
      frontmatter = raw.trim();
      body = '';
    }

    final updated = _updateYamlUpdatedAt(frontmatter, now);
    final newBody = body.isEmpty ? text : '$body\n\n---\n$text';
    await _file(noteId).writeAsString('$updated\n---\n\n$newBody\n');
  }

  File _file(String noteId) => File(p.join(notesDir.path, '$noteId.md'));

  NoteMeta? _parseFrontmatter(String raw) {
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
}

String _toYaml(Map<String, dynamic> map) {
  final buf = StringBuffer('---\n');
  for (final entry in map.entries) {
    final v = entry.value;
    if (v == null) {
      buf.writeln('${entry.key}: null');
    } else if (v is String) {
      buf.writeln('${entry.key}: "${_escapeYaml(v)}"');
    } else {
      buf.writeln('${entry.key}: $v');
    }
  }
  buf.writeln('---');
  return buf.toString();
}

String _updateYamlUpdatedAt(String frontmatter, String newTime) {
  final lines = frontmatter.split('\n');
  final buf = StringBuffer();
  for (final line in lines) {
    if (line.trimLeft().startsWith('updatedAt:')) {
      buf.writeln('updatedAt: "$newTime"');
    } else {
      buf.writeln(line);
    }
  }
  return buf.toString().trimRight();
}

String _updateYamlTitle(String frontmatter, String newTitle) {
  final lines = frontmatter.split('\n');
  final buf = StringBuffer();
  for (final line in lines) {
    if (line.trimLeft().startsWith('title:')) {
      buf.writeln('title: "${_escapeYaml(newTitle)}"');
    } else {
      buf.writeln(line);
    }
  }
  return buf.toString().trimRight();
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

String _escapeYaml(String s) => s.replaceAll('"', '\\"');
