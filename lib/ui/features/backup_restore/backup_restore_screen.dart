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
import 'package:thk_tree/l10n/generated/app_localizations.dart';

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
        title: Text(AppLocalizations.of(context)!.backupDeleteTitle),
        content: Text(AppLocalizations.of(context)!.backupDeleteContent),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(AppLocalizations.of(context)!.delete),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          CupertinoDialogAction(
            child: Text(AppLocalizations.of(context)!.cancel),
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
      builder: (_) => CupertinoAlertDialog(
        title: Text(AppLocalizations.of(context)!.backupBackingUp),
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
      _showAlert(AppLocalizations.of(context)!.error, e.toString());
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
          title: Text(AppLocalizations.of(context)!.backupDataConflict),
          content: Text(AppLocalizations.of(context)!.backupDataConflictContent),
          actions: [
            CupertinoDialogAction(
              child: Text(AppLocalizations.of(context)!.backupOverwrite),
              onPressed: () => Navigator.of(ctx).pop(ImportMode.overwrite),
            ),
            CupertinoDialogAction(
              child: Text(AppLocalizations.of(context)!.backupMerge),
              onPressed: () => Navigator.of(ctx).pop(ImportMode.merge),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: Text(AppLocalizations.of(context)!.cancel),
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
      builder: (_) => CupertinoAlertDialog(
        title: Text(AppLocalizations.of(context)!.backupRestoring),
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
      _showAlert(AppLocalizations.of(context)!.error, error.toString());
    } else if (result != null) {
      if (result.status == ImportResultStatus.success) {
        ref.invalidate(appPathsProvider);
        _refreshBackups();
        _showAlert(AppLocalizations.of(context)!.success, AppLocalizations.of(context)!.backupRestoreSuccess);
      } else {
        _showAlert(AppLocalizations.of(context)!.error, result.message ?? AppLocalizations.of(context)!.backupRestoreFailed);
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
            child: Text(AppLocalizations.of(context)!.ok),
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
        title: Text(AppLocalizations.of(context)!.backupReminderInterval),
        actions: [
          ...options.map((d) => CupertinoDialogAction(
                child: Text(d == current
                    ? AppLocalizations.of(context)!.backupReminderDaysCurrent(d)
                    : AppLocalizations.of(context)!.backupReminderDays(d)),
                onPressed: () => Navigator.of(ctx).pop(d),
              )),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(AppLocalizations.of(context)!.cancel),
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
    if (t == null) return AppLocalizations.of(context)!.backupNotYet;
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
      navigationBar: CupertinoNavigationBar(middle: Text(AppLocalizations.of(context)!.backupTitle)),
      child: SafeArea(
        child: CupertinoScrollbar(
          child: ListView(
            children: [
              _sectionHeader(AppLocalizations.of(context)!.backupAutoSection),
              _row(
                leading: const Icon(CupertinoIcons.clock_fill),
                title: AppLocalizations.of(context)!.backupAutoTitle,
                subtitle: AppLocalizations.of(context)!.backupAutoSubtitle,
                trailing: CupertinoSwitch(
                  value: settings?.autoBackupEnabled ?? true,
                  onChanged: (v) => ref
                      .read(settingsControllerProvider.notifier)
                      .saveAutoBackupEnabled(v),
                ),
              ),
              _row(
                leading: const Icon(CupertinoIcons.timer),
                title: AppLocalizations.of(context)!.backupLastBackup,
                subtitle: _fmtTime(settings?.lastAutoBackupAt),
                trailing: const SizedBox.shrink(),
              ),

              _sectionHeader(AppLocalizations.of(context)!.backupLocalSection(_backups.length)),
              if (_backups.isEmpty)
                _emptyHint(AppLocalizations.of(context)!.backupLocalEmpty)
              else
                ..._backups.map(_backupTile),

              _sectionHeader(AppLocalizations.of(context)!.backupManualSection),
              _row(
                leading: const Icon(CupertinoIcons.share),
                title: AppLocalizations.of(context)!.backupManualShare,
                subtitle: AppLocalizations.of(context)!.backupManualShareSubtitle,
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                onTap: _manualBackup,
              ),
              _row(
                leading: const Icon(CupertinoIcons.download_circle),
                title: AppLocalizations.of(context)!.backupManualRestore,
                subtitle: AppLocalizations.of(context)!.backupManualRestoreSubtitle,
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                onTap: _restore,
              ),

              _sectionHeader(AppLocalizations.of(context)!.backupReminderSection),
              _row(
                leading: const Icon(CupertinoIcons.bell),
                title: AppLocalizations.of(context)!.backupReminderToggle,
                subtitle: AppLocalizations.of(context)!.backupReminderToggleSubtitle,
                trailing: CupertinoSwitch(
                  value: settings?.backupReminderEnabled ?? true,
                  onChanged: (v) => ref
                      .read(settingsControllerProvider.notifier)
                      .saveBackupReminderEnabled(v),
                ),
              ),
              _row(
                leading: const Icon(CupertinoIcons.calendar),
                title: AppLocalizations.of(context)!.backupReminderInterval,
                subtitle: AppLocalizations.of(context)!.backupReminderSubtitle(settings?.backupReminderIntervalDays ?? 3),
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
            Icon(CupertinoIcons.doc, color: AppColors.accent),
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
