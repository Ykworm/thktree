import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/import_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('import_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 构造一个包含 manifest + 1 个 theme 的测试 zip
  Future<File> _createTestZip(Directory parent) async {
    final archive = Archive();

    // manifest
    final manifest = {
      'schema': 'thktree-manifest/v1',
      'appVersion': '1.0.0',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'scope': 'full',
      'themes': [
        {
          'themeId': 'thm_import',
          'title': 'Imported Theme',
          'nodeCount': 0,
          'noteCount': 0,
        }
      ],
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile(
      'thktree-export/thktree-manifest.json',
      manifestBytes.length,
      manifestBytes,
    ));

    // theme.meta.json
    final themeMeta = utf8.encode('{"themeId":"thm_import","title":"Imported Theme"}');
    archive.addFile(ArchiveFile(
      'thktree-export/themes/thm_import/theme.meta.json',
      themeMeta.length,
      themeMeta,
    ));

    final zipBytes = ZipEncoder().encode(archive)!;
    final zipFile = File('${parent.path}/test-export.zip');
    await zipFile.writeAsBytes(zipBytes);
    return zipFile;
  }

  group('ImportService', () {
    test('hasExistingData returns false when no themes dir', () {
      final rootDir = Directory('${tempDir.path}/data');
      rootDir.createSync();
      final service = ImportService(rootDir: rootDir);
      expect(service.hasExistingData(), false);
    });

    test('hasExistingData returns true when themes exist', () async {
      final rootDir = Directory('${tempDir.path}/data');
      await Directory('${rootDir.path}/themes/thm_001').create(recursive: true);
      final service = ImportService(rootDir: rootDir);
      expect(service.hasExistingData(), true);
    });

    test('importFull with no existing data (overwrite mode)', () async {
      final rootDir = Directory('${tempDir.path}/data');
      await rootDir.create();
      final zipFile = await _createTestZip(tempDir);

      final service = ImportService(rootDir: rootDir);
      final result = await service.importFull(
        zipFile: zipFile,
        mode: ImportMode.overwrite,
      );

      expect(result.status, ImportResultStatus.success);
      expect(result.importedThemes, greaterThan(0));

      // 验证文件已解压
      final themeDir = Directory('${rootDir.path}/themes/thm_import');
      expect(themeDir.existsSync(), true);
      expect(File('${themeDir.path}/theme.meta.json').existsSync(), true);
    });

    test('importFull with invalid zip returns error', () async {
      final rootDir = Directory('${tempDir.path}/data');
      await rootDir.create();

      // 创建一个无效的 zip（无 manifest）
      final archive = Archive();
      final dummyBytes = utf8.encode('dummy');
      archive.addFile(ArchiveFile('dummy.txt', dummyBytes.length, dummyBytes));
      final zipBytes = ZipEncoder().encode(archive)!;
      final zipFile = File('${tempDir.path}/bad-export.zip');
      await zipFile.writeAsBytes(zipBytes);

      final service = ImportService(rootDir: rootDir);
      final result = await service.importFull(
        zipFile: zipFile,
        mode: ImportMode.overwrite,
      );

      expect(result.status, ImportResultStatus.error);
      expect(result.message, contains('manifest'));
    });

    test('importFull overwrite mode clears existing data', () async {
      final rootDir = Directory('${tempDir.path}/data');
      // 预建一个旧 theme
      await Directory('${rootDir.path}/themes/old_theme')
          .create(recursive: true);
      await File('${rootDir.path}/themes/old_theme/theme.meta.json')
          .writeAsString('{}');

      final zipFile = await _createTestZip(tempDir);

      final service = ImportService(rootDir: rootDir);
      final result = await service.importFull(
        zipFile: zipFile,
        mode: ImportMode.overwrite,
      );

      expect(result.status, ImportResultStatus.success);

      // 旧 theme 应被清除
      expect(
        Directory('${rootDir.path}/themes/old_theme').existsSync(),
        false,
      );
      // 新 theme 应存在
      expect(
        Directory('${rootDir.path}/themes/thm_import').existsSync(),
        true,
      );
    });

    test('importFull merge mode keeps existing data', () async {
      final rootDir = Directory('${tempDir.path}/data');
      // 预建一个旧 theme
      await Directory('${rootDir.path}/themes/old_theme')
          .create(recursive: true);
      await File('${rootDir.path}/themes/old_theme/theme.meta.json')
          .writeAsString('{}');

      final zipFile = await _createTestZip(tempDir);

      final service = ImportService(rootDir: rootDir);
      final result = await service.importFull(
        zipFile: zipFile,
        mode: ImportMode.merge,
      );

      expect(result.status, ImportResultStatus.success);

      // 旧 theme 应保留
      expect(
        Directory('${rootDir.path}/themes/old_theme').existsSync(),
        true,
      );
      // 新 theme 应存在
      expect(
        Directory('${rootDir.path}/themes/thm_import').existsSync(),
        true,
      );
    });

    test('importFull merge mode renames conflicting file', () async {
      final rootDir = Directory('${tempDir.path}/data');
      // 预建一个同名 theme
      await Directory('${rootDir.path}/themes/thm_import')
          .create(recursive: true);
      await File('${rootDir.path}/themes/thm_import/theme.meta.json')
          .writeAsString('{"themeId":"thm_import","title":"Old"}');

      final zipFile = await _createTestZip(tempDir);

      final service = ImportService(rootDir: rootDir);
      final result = await service.importFull(
        zipFile: zipFile,
        mode: ImportMode.merge,
      );

      expect(result.status, ImportResultStatus.success);

      // 原始 theme 应保留
      expect(
        File('${rootDir.path}/themes/thm_import/theme.meta.json')
            .existsSync(),
        true,
      );
      // 应存在一个带数字后缀的文件
      final themesDir = Directory('${rootDir.path}/themes/thm_import');
      final files = themesDir.listSync().whereType<File>().toList();
      expect(files.length, greaterThan(1));
    });
  });
}
