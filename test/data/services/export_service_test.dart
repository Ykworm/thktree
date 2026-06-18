import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/export_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('export_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('ExportService', () {
    test('exportFull creates zip with manifest', () async {
      // 创建测试目录结构
      final rootDir = Directory('${tempDir.path}/data');
      await rootDir.create();
      await Directory('${rootDir.path}/themes/thm_001').create(recursive: true);
      await File('${rootDir.path}/themes/thm_001/theme.meta.json')
          .writeAsString('{"themeId":"thm_001","title":"Test"}');

      final exportService = ExportService(rootDir: rootDir);
      final zipFile = await exportService.exportFull(
        appVersion: '1.0.0',
      );

      expect(zipFile.existsSync(), true);
      expect(zipFile.path.endsWith('.zip'), true);
    });
  });
}
