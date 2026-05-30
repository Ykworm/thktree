import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/data/models/node_meta.dart';

void main() {
  group('NodeMetaV1', () {
    test('json roundtrip preserves all fields', () {
      final meta = NodeMetaV1(
        themeId: 'thm_x',
        nodeId: 'nd_x',
        parentId: null,
        kind: NodeKind.chat,
        title: 't',
        createdAtUtcIso8601: '2026-05-25T12:00:00.000Z',
        updatedAtUtcIso8601: '2026-05-25T12:00:00.000Z',
      );

      final decoded = jsonDecode(meta.toJsonString());
      final parsed = NodeMetaV1.fromJson(Map<String, Object?>.from(decoded as Map));
      expect(parsed.themeId, meta.themeId);
      expect(parsed.nodeId, meta.nodeId);
      expect(parsed.parentId, meta.parentId);
      expect(parsed.kind.value, meta.kind.value);
      expect(parsed.title, meta.title);
      expect(parsed.createdAtUtcIso8601, meta.createdAtUtcIso8601);
      expect(parsed.updatedAtUtcIso8601, meta.updatedAtUtcIso8601);
    });

    test('json roundtrip preserves parentId when set', () {
      final meta = NodeMetaV1(
        themeId: 'thm_x',
        nodeId: 'nd_child',
        parentId: 'nd_parent',
        kind: NodeKind.summary,
        title: 'branch',
        createdAtUtcIso8601: '2026-05-25T12:00:00.000Z',
        updatedAtUtcIso8601: '2026-05-25T12:00:00.000Z',
      );

      final decoded = jsonDecode(meta.toJsonString());
      final parsed = NodeMetaV1.fromJson(Map<String, Object?>.from(decoded as Map));
      expect(parsed.parentId, 'nd_parent');
      expect(parsed.kind, NodeKind.summary);
    });

    test('toJson includes schema field', () {
      final meta = NodeMetaV1(
        themeId: 'thm_x',
        nodeId: 'nd_x',
        parentId: null,
        kind: NodeKind.chat,
        title: 't',
        createdAtUtcIso8601: '2026-05-25T12:00:00.000Z',
        updatedAtUtcIso8601: '2026-05-25T12:00:00.000Z',
      );

      expect(meta.toJson()['schema'], 'node_meta/v1');
    });

    test('fromJson throws on wrong schema', () {
      expect(
        () => NodeMetaV1.fromJson({'schema': 'wrong', 'themeId': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws on missing fields', () {
      expect(
        () => NodeMetaV1.fromJson({'schema': 'node_meta/v1'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws on unknown kind', () {
      expect(
        () => NodeMetaV1.fromJson({
          'schema': 'node_meta/v1',
          'themeId': 't',
          'nodeId': 'n',
          'parentId': null,
          'kind': 'unknown_kind',
          'title': 't',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('toEntity converts correctly', () {
      final meta = NodeMetaV1(
        themeId: 'thm_1',
        nodeId: 'nd_1',
        parentId: null,
        kind: NodeKind.chat,
        title: 'My Node',
        createdAtUtcIso8601: '2026-01-01T00:00:00.000Z',
        updatedAtUtcIso8601: '2026-01-02T00:00:00.000Z',
      );

      final entity = meta.toEntity();
      expect(entity.themeId, 'thm_1');
      expect(entity.nodeId, 'nd_1');
      expect(entity.parentId, isNull);
      expect(entity.kind, NodeKind.chat);
      expect(entity.title, 'My Node');
    });
  });
}

