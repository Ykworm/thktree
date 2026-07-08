import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:thk_tree/data/services/export_service.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/ui/core/app_paths.dart';

/// 自动备份服务：前台补偿机制，App 进前台 + 超 24h 触发一次本地备份。
///
/// 设计要点：
/// - 备份只读用户数据，最坏只是没备份成，不会损坏现有数据
/// - 原子写入（ExportService 内部 .tmp→rename）避免半截 zip
/// - 时间戳（lastAutoBackupAt）在备份成功后由调用方更新，中断能自愈
/// - 每次备份前清理 .tmp 残留
/// - 保留最近 7 份，超出自动删最旧
class AutoBackupService {
  AutoBackupService({required this.paths});

  final AppPaths paths;

  static const _maxBackups = 7;
  static const _backupInterval = Duration(hours: 24);

  /// 进前台时调。返回 true 表示执行了备份（调用方应据此更新 lastAutoBackupAt）。
  ///
  /// [settings] 只读，用于判断 lastAutoBackupAt 是否超 24h。
  Future<bool> maybeBackup({
    required AppSettings settings,
    required String appVersion,
  }) async {
    // 1. 检查是否需要备份（距上次 > 24h）
    final last = settings.lastAutoBackupAt;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _backupInterval) {
      return false;
    }

    // 2. 清理 .tmp 残留（上次中断的）
    _cleanTmpResidue();

    // 3. 确保 backups 目录存在
    if (!paths.backupsDir.existsSync()) {
      await paths.backupsDir.create(recursive: true);
    }

    // 4. 导出（原子写入：ExportService 内部先 .tmp 再 rename）
    try {
      await ExportService(rootDir: paths.rootDir).exportFull(
        appVersion: appVersion,
        outputDir: paths.backupsDir,
      );
    } catch (_) {
      // 备份失败不抛，下次进前台重试
      return false;
    }

    // 5. 清理超出 7 份的旧备份
    _pruneOldBackups();

    return true;
  }

  /// 清理 backups/ 下的 .tmp 残留
  void _cleanTmpResidue() {
    if (!paths.backupsDir.existsSync()) return;
    for (final entity in paths.backupsDir.listSync()) {
      if (entity is File && entity.path.endsWith('.tmp')) {
        try {
          entity.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// 保留最近 _maxBackups 份，删多余的
  void _pruneOldBackups() {
    if (!paths.backupsDir.existsSync()) return;
    final backups = listBackups();
    if (backups.length <= _maxBackups) return;
    for (final file in backups.skip(_maxBackups)) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
  }

  /// 列出本地备份（新→旧），用于备份列表页展示
  List<File> listBackups() {
    if (!paths.backupsDir.existsSync()) return [];
    return paths.backupsDir
        .listSync()
        .whereType<File>()
        .where((f) =>
            p.basename(f.path).startsWith('thktree-backup-') &&
            f.path.endsWith('.zip'))
        .toList()
      ..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
  }

  /// 删除指定备份文件
  Future<bool> deleteBackup(File file) async {
    try {
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
