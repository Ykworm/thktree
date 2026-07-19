import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 把已生成的 wiki 快照打包为 zip 导出。
class WikiExportService {
  const WikiExportService();

  /// 将 [wikiDir] 打包为 zip，返回 zip 文件。
  ///
  /// 输出文件名：`{themeTitle}-wiki.zip`。
  Future<File> exportWiki({
    required Directory wikiDir,
    required String themeTitle,
  }) async {
    if (!await wikiDir.exists()) {
      throw StateError('Wiki directory not found: ${wikiDir.path}');
    }

    final archive = Archive();
    await _addDirectoryToArchive(archive, wikiDir, 'wiki');

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('Failed to encode wiki zip archive');
    }

    final tempDir = await getTemporaryDirectory();
    final safeTitle = themeTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final zipFile = File(p.join(tempDir.path, '$safeTitle-wiki.zip'));

    // 原子写入
    final tmpFile = File('${zipFile.path}.tmp');
    await tmpFile.writeAsBytes(zipBytes);
    await tmpFile.rename(zipFile.path);

    return zipFile;
  }

  Future<void> _addDirectoryToArchive(
    Archive archive,
    Directory dir,
    String archivePath,
  ) async {
    final entities = await dir.list(followLinks: false).toList();
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
