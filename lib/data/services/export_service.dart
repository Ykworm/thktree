import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:thk_tree/data/models/export_manifest.dart';

class ExportService {
  ExportService({required this.rootDir});

  final Directory rootDir;

  /// 导出全量数据为 zip 文件
  Future<File> exportFull({required String appVersion}) async {
    final themesDir = Directory('${rootDir.path}/themes');
    if (!themesDir.existsSync()) {
      throw StateError('themes directory not found');
    }

    // 1. 收集所有 theme 信息
    final themeDirs = themesDir.listSync().whereType<Directory>().toList();
    final themeExports = <ThemeExport>[];

    for (final themeDir in themeDirs) {
      final themeId = p.basename(themeDir.path);
      final metaFile = File('${themeDir.path}/theme.meta.json');

      String title = themeId;
      if (metaFile.existsSync()) {
        // 简单解析 title，实际应使用 json_serializable
        final content = await metaFile.readAsString();
        final match = RegExp(r'"title"\s*:\s*"([^"]+)"').firstMatch(content);
        if (match != null) title = match.group(1)!;
      }

      final nodesDir = Directory('${themeDir.path}/nodes');
      final nodeDirs = nodesDir.existsSync()
          ? nodesDir.listSync().whereType<Directory>().toList()
          : <Directory>[];
      final notesDir = Directory('${themeDir.path}/notes');
      final noteFiles = notesDir.existsSync()
          ? notesDir.listSync().whereType<File>().toList()
          : <File>[];

      themeExports.add(ThemeExport(
        themeId: themeId,
        title: title,
        nodeCount: nodeDirs.length,
        noteCount: noteFiles.length,
      ));
    }

    // 2. 创建 manifest
    final manifest = ExportManifest(
      schema: 'thktree-manifest/v1',
      appVersion: appVersion,
      exportedAt: DateTime.now().toUtc(),
      scope: ExportScope.full,
      themes: themeExports,
    );

    // 3. 打包 zip
    final archive = Archive();

    // 添加 manifest
    final manifestBytes = manifest.toJsonString().codeUnits;
    archive.addFile(ArchiveFile(
      'thktree-export/thktree-manifest.json',
      manifestBytes.length,
      manifestBytes,
    ));

    // 添加所有文件
    await _addDirectoryToArchive(archive, themesDir, 'thktree-export/themes');

    // 4. 写入 zip 文件
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('Failed to encode zip archive');
    }
    final zipFile = File(
        '${rootDir.path}/thktree-export-${DateTime.now().millisecondsSinceEpoch}.zip');
    await zipFile.writeAsBytes(zipBytes);

    return zipFile;
  }

  Future<void> _addDirectoryToArchive(
    Archive archive,
    Directory dir,
    String archivePath,
  ) async {
    final entities = dir.listSync();
    for (final entity in entities) {
      final name = p.basename(entity.path);
      final archiveFilePath = '$archivePath/$name';

      if (entity is File) {
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(archiveFilePath, bytes.length, bytes));
      } else if (entity is Directory) {
        await _addDirectoryToArchive(archive, entity, archiveFilePath);
      }
    }
  }
}
