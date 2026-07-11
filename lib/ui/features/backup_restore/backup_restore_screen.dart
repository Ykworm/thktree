import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thk_tree/data/services/auto_backup_service.dart';
import 'package:thk_tree/data/services/export_service.dart';
import 'package:thk_tree/data/services/import_service.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// 备份与恢复聚合页：自动备份 / 本地备份列表 / 手动备份 / 恢复 / 分享提醒
class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});
  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  List<File> _backups = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBackups());
  }

  void _refreshBackups() {
    final paths = ref.read(appPathsProvider).value;
    if (paths == null) return;
    setState(() {
      _backups = AutoBackupService(paths: paths).listBackups();
    });
  }

  /// 分享成功后推迟提醒一个周期
  Future<void> _snoozeReminder() async {
    final settings =
        ref.read(settingsControllerProvider).whenOrNull(data: (s) => s);
    if (settings == null) return;
    final nextDate = DateTime.now()
        .add(Duration(days: settings.backupReminderIntervalDays));
    await ref
        .read(settingsControllerProvider.notifier)
        .saveNextBackupReminderDate(nextDate);
  }

  Future<void> _shareBackup(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
    await _snoozeReminder();
  }

  Future<void> _deleteBackup(File file) async {
    final paths = ref.read(appPathsProvider).value;
    if (paths == null) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除备份'),
        content: const Text('确定删除这份本地备份？'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await AutoBackupService(paths: paths).deleteBackup(file);
    if (deleted) _refreshBackups();
  }

  Future<void> _manualBackup() async {
    final paths = ref.read(appPathsProvider).value;
    if (paths == null || _busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context, rootNavigator: true);
    unawaited(showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('备份中'),
        content: Padding(
          padding: EdgeInsets.only(top: 16),
          child: CupertinoActivityIndicator(),
        ),
      ),
    ).then((_) {}).catchError((_) {}));

    try {
      final zipFile = await ExportService(rootDir: paths.rootDir)
          .exportFull(appVersion: '1.0.0');
      if (navigator.canPop()) navigator.pop();
      await Share.shareXFiles(
        [XFile(zipFile.path)],
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      );
      await _snoozeReminder();
    } catch (e) {
      if (navigator.canPop()) navigator.pop();
      _showAlert('错误', e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final paths = ref.read(appPathsProvider).value;
    if (paths == null || _busy) return;
    FilePickerResult? pickResult;
    try {
      pickResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
    } catch (_) {
      return;
    }
    if (pickResult == null || pickResult.files.isEmpty) return;
    final zipFile = File(pickResult.files.first.path!);

    final importService = ImportService(rootDir: paths.rootDir);
    ImportMode mode = ImportMode.overwrite;
    if (importService.hasExistingData()) {
      if (!mounted) return;
      final ImportMode? chosen = await showCupertinoDialog<ImportMode>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('数据冲突'),
          content: const Text('本地已有数据，恢复将如何处理？'),
          actions: [
            CupertinoDialogAction(
              child: const Text('覆盖'),
              onPressed: () => Navigator.of(ctx).pop(ImportMode.overwrite),
            ),
            CupertinoDialogAction(
              child: const Text('合并'),
              onPressed: () => Navigator.of(ctx).pop(ImportMode.merge),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('取消'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
      if (chosen == null) return;
      mode = chosen;
    }

    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    unawaited(showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('恢复中'),
        content: Padding(
          padding: EdgeInsets.only(top: 16),
          child: CupertinoActivityIndicator(),
        ),
      ),
    ).then((_) {}).catchError((_) {}));

    setState(() => _busy = true);
    ImportResult? result;
    Object? error;
    try {
      result = await importService.importFull(zipFile: zipFile, mode: mode);
    } catch (e) {
      error = e;
    } finally {
      if (navigator.canPop()) navigator.pop();
    }
    if (!mounted) return;
    if (error != null) {
      _showAlert('错误', error.toString());
    } else if (result != null) {
      if (result.status == ImportResultStatus.success) {
        ref.invalidate(appPathsProvider);
        _refreshBackups();
        _showAlert('成功', '恢复成功');
      } else {
        _showAlert('错误', result.message ?? '恢复失败');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  void _showAlert(String title, String content) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickInterval(int current) async {
    const options = [3, 5, 7, 14];
    final chosen = await showCupertinoDialog<int>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提醒周期'),
        actions: [
          ...options.map((d) => CupertinoDialogAction(
                child: Text(d == current ? '每 $d 天（当前）' : '每 $d 天'),
                onPressed: () => Navigator.of(ctx).pop(d),
              )),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
    if (chosen != null && chosen != current) {
      await ref
          .read(settingsControllerProvider.notifier)
          .saveBackupReminderIntervalDays(chosen);
    }
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return '尚未备份';
    final d = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  String _fmtSize(File f) {
    try {
      final b = f.lengthSync();
      if (b < 1024) return '$b B';
      if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
      return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    } catch (_) {
      return '-';
    }
  }

  String _backupLabel(File f) {
    final name = f.path.split('/').last;
    final ms = int.tryParse(
        name.replaceAll(RegExp(r'^thktree-backup-|\.zip$'), ''));
    if (ms == null) return name;
    return _fmtTime(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsControllerProvider).whenOrNull(data: (s) => s);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('备份与恢复')),
      child: SafeArea(
        child: CupertinoScrollbar(
          child: ListView(
            children: [
              _sectionHeader('自动备份'),
              _row(
                leading: const Icon(CupertinoIcons.clock_fill),
                title: '自动备份',
                subtitle: '每 24 小时备份一次到本地',
                trailing: CupertinoSwitch(
                  value: settings?.autoBackupEnabled ?? true,
                  onChanged: (v) => ref
                      .read(settingsControllerProvider.notifier)
                      .saveAutoBackupEnabled(v),
                ),
              ),
              _row(
                leading: const Icon(CupertinoIcons.timer),
                title: '上次备份',
                subtitle: _fmtTime(settings?.lastAutoBackupAt),
                trailing: const SizedBox.shrink(),
              ),

              _sectionHeader('本地备份（${_backups.length}）'),
              if (_backups.isEmpty)
                _emptyHint('还没有本地备份')
              else
                ..._backups.map(_backupTile),

              _sectionHeader('手动操作'),
              _row(
                leading: const Icon(CupertinoIcons.share),
                title: '立即备份并分享',
                subtitle: '生成一份备份并分享出去',
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                onTap: _manualBackup,
              ),
              _row(
                leading: const Icon(CupertinoIcons.download_circle),
                title: '从备份文件恢复',
                subtitle: '从 zip 文件恢复数据',
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                onTap: _restore,
              ),

              _sectionHeader('分享提醒'),
              _row(
                leading: const Icon(CupertinoIcons.bell),
                title: '提醒开关',
                subtitle: '定期提醒把备份分享出去',
                trailing: CupertinoSwitch(
                  value: settings?.backupReminderEnabled ?? true,
                  onChanged: (v) => ref
                      .read(settingsControllerProvider.notifier)
                      .saveBackupReminderEnabled(v),
                ),
              ),
              _row(
                leading: const Icon(CupertinoIcons.calendar),
                title: '提醒周期',
                subtitle: '每 ${settings?.backupReminderIntervalDays ?? 3} 天提醒一次',
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                onTap: () =>
                    _pickInterval(settings?.backupReminderIntervalDays ?? 3),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Text(
          title,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );

  Widget _row({
    required Widget leading,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: AppColors.pageBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      );

  Widget _backupTile(File f) => Container(
        color: AppColors.pageBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(CupertinoIcons.doc, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_backupLabel(f), style: const TextStyle(fontSize: 16)),
                  Text(
                    _fmtSize(f),
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.share, size: 20),
              onPressed: () => _shareBackup(f),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.delete,
                  size: 20, color: AppColors.destructive),
              onPressed: () => _deleteBackup(f),
            ),
          ],
        ),
      );

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          text,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
}
