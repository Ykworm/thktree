import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/models/theme_meta.dart';

void main() {
  group('ThemeMetaV1', () {
    test('json roundtrip preserves all fields', () {
      final meta = ThemeMetaV1(
        themeId: 'thm_01J8Z8T3C3P7W6XK9YB2V2J0QK',
        title: 't',
        createdAtUtcIso8601: '2026-05-25T12:00:00.000Z',
        updatedAtUtcIso8601: '2026-05-25T12:00:00.000Z',
      );

      final decoded = jsonDecode(meta.toJsonString());
      final parsed = ThemeMetaV1.fromJson(Map<String, Object?>.from(decoded as Map));
      expect(parsed.themeId, meta.themeId);
      expect(parsed.title, meta.title);
      expect(parsed.createdAtUtcIso8601, meta.createdAtUtcIso8601);
      expect(parsed.updatedAtUtcIso8601, meta.updatedAtUtcIso8601);
    });

    test('toJson includes schema field', () {
      final meta = ThemeMetaV1(
        themeId: 'thm_1',
        title: 'My Theme',
        createdAtUtcIso8601: '2026-01-01T00:00:00.000Z',
        updatedAtUtcIso8601: '2026-01-01T00:00:00.000Z',
      );

      expect(meta.toJson()['schema'], 'theme_meta/v1');
    });

    test('fromJson throws on wrong schema', () {
      expect(
        () => ThemeMetaV1.fromJson({'schema': 'wrong', 'themeId': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws on missing fields', () {
      expect(
        () => ThemeMetaV1.fromJson({'schema': 'theme_meta/v1'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws on wrong field types', () {
      expect(
        () => ThemeMetaV1.fromJson({
          'schema': 'theme_meta/v1',
          'themeId': 123,
          'title': 't',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('toEntity converts correctly', () {
      final meta = ThemeMetaV1(
        themeId: 'thm_1',
        title: 'My Theme',
        createdAtUtcIso8601: '2026-01-01T00:00:00.000Z',
        updatedAtUtcIso8601: '2026-01-02T00:00:00.000Z',
      );

      final entity = meta.toEntity();
      expect(entity.themeId, 'thm_1');
      expect(entity.title, 'My Theme');
      expect(entity.createdAtUtcIso8601, '2026-01-01T00:00:00.000Z');
      expect(entity.updatedAtUtcIso8601, '2026-01-02T00:00:00.000Z');
    });
  });
}

