import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

enum ImportMode { overwrite, merge }

enum ImportResultStatus { success, conflict, error }

class ImportResult {
  ImportResult({
    required this.status,
    this.message,
    this.importedThemes = 0,
  });

  final ImportResultStatus status;
  final String? message;
  final int importedThemes;
}

class ImportService {
  ImportService({required this.rootDir});

  final Directory rootDir;

  /// 检查是否存在本地数据
  bool hasExistingData() {
    final themesDir = Directory('${rootDir.path}/themes');
    return themesDir.existsSync() && themesDir.listSync().isNotEmpty;
  }

  /// 从 zip 文件导入数据
  Future<ImportResult> importFull({
    required File zipFile,
    required ImportMode mode,
  }) async {
    try {
      // 1. 解压 zip
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 2. 读取 manifest，确认是合法的导出文件
      final manifestFile =
          archive.findFile('thktree-export/thktree-manifest.json');
      if (manifestFile == null) {
        return ImportResult(
          status: ImportResultStatus.error,
          message: 'Invalid export file: manifest not found',
        );
      }

      // 3. 根据模式处理已有数据
      if (mode == ImportMode.overwrite) {
        await _clearExistingData();
      }

      // 4. 解压 theme 文件到目标目录
      final themesDir = Directory('${rootDir.path}/themes');
      if (!themesDir.existsSync()) {
        await themesDir.create(recursive: true);
      }

      int importedCount = 0;

      for (final file in archive) {
        if (file.isFile && file.name.startsWith('thktree-export/themes/')) {
          final relativePath =
              file.name.replaceFirst('thktree-export/themes/', '');

          // 防止路径穿越
          final normalized = p.normalize(relativePath);
          if (normalized.startsWith('..') || p.isAbsolute(normalized)) {
            continue; // 跳过路径穿越条目
          }

          final targetFile = File('${themesDir.path}/$normalized');

          // 确保父目录存在
          await targetFile.parent.create(recursive: true);

          if (mode == ImportMode.merge && targetFile.existsSync()) {
            // 合并模式：如果文件已存在，添加数字后缀
            final newPath = _getUniquePath(targetFile.path);
            await File(newPath).writeAsBytes(file.content as List<int>);
          } else {
            await targetFile.writeAsBytes(file.content as List<int>);
          }

          // 每遇到 theme.meta.json 就视为一个 theme 被导入
          if (file.name.endsWith('theme.meta.json')) {
            importedCount++;
          }
        }
      }

      return ImportResult(
        status: importedCount > 0
            ? ImportResultStatus.success
            : ImportResultStatus.conflict,
        importedThemes: importedCount,
      );
    } catch (e) {
      return ImportResult(
        status: ImportResultStatus.error,
        message: 'Import failed: $e',
      );
    }
  }

  Future<void> _clearExistingData() async {
    final themesDir = Directory('${rootDir.path}/themes');
    if (themesDir.existsSync()) {
      await themesDir.delete(recursive: true);
    }
  }

  String _getUniquePath(String originalPath) {
    final dir = p.dirname(originalPath);
    final name = p.basenameWithoutExtension(originalPath);
    final ext = p.extension(originalPath);

    int counter = 1;
    String newPath;
    do {
      newPath = '$dir/$name ${counter.toString().padLeft(2, '0')}$ext';
      counter++;
    } while (File(newPath).existsSync());

    return newPath;
  }

}
