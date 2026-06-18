import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/models/export_manifest.dart';

void main() {
  group('ExportManifest', () {
    test('toJson/fromJson round-trip', () {
      final manifest = ExportManifest(
        schema: 'thktree-manifest/v1',
        appVersion: '1.0.0',
        exportedAt: DateTime.utc(2026, 6, 18),
        scope: ExportScope.full,
        themes: [
          ThemeExport(
            themeId: 'thm_001',
            title: 'Swift 学习',
            nodeCount: 5,
            noteCount: 3,
          ),
        ],
      );

      final json = manifest.toJson();
      final restored = ExportManifest.fromJson(json);

      expect(restored.schema, manifest.schema);
      expect(restored.themes.first.title, 'Swift 学习');
    });
  });
}
