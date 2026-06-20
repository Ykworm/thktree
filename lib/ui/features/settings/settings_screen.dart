import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_logger.dart';

import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/ui/features/settings/llm_settings_screen.dart';
import 'package:thk_tree/ui/features/settings/tts_settings_screen.dart';
import 'package:thk_tree/data/services/export_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:thk_tree/data/services/import_service.dart';
import 'package:thk_tree/ui/features/themes/theme_list_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pathsAsync = ref.watch(appPathsProvider);
    final loggerAsync = ref.watch(appLoggerProvider);

    return ThkLargeTitlePage(
      title: l10n.settingsTitle,
      children: [
        ThkListSection(
          header: l10n.language,
          children: [
            _LanguageTile(),
          ],
        ),
        ThkListSection(
          children: [
            _LlmSettingsEntry(),
          ],
        ),
        ThkListSection(
          children: [
            _TtsEntry(),
          ],
        ),
        ThkListSection(
          children: [
            _FaceIdToggle(),
          ],
        ),
        ThkListSection(
          header: l10n.backupAndRestore,
          children: [
            _BackupEntry(),
            _RestoreEntry(),
          ],
        ),
        if (kDebugMode) ...[
          ThkListSection(
            header: 'Dev Tools',
            children: [
              _DarkModeToggle(),
            ],
          ),
        ],
        loggerAsync.when(
          data: (logger) => ThkListSection(
            children: _buildLogTiles(context, logger, l10n),
          ),
          error: (e, st) => ThkListSection(
            children: [ThkListTile(title: e.toString(), trailing: null)],
          ),
          loading: () => ThkListSection(
            children: [ThkListTile(title: l10n.loadingLogger, trailing: null)],
          ),
        ),
        pathsAsync.when(
          data: (paths) => ThkListSection(
            children: [
              ThkListTile(
                title: l10n.dataRoot,
                subtitle: paths.rootDir.path,
                trailing: null,
              ),
            ],
          ),
          error: (e, st) => ThkListSection(
            children: [ThkListTile(title: e.toString(), trailing: null)],
          ),
          loading: () => ThkListSection(
            children: [ThkListTile(title: l10n.loadingPaths, trailing: null)],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLogTiles(BuildContext context, AppLogger logger, AppLocalizations l10n) {
    return [
      ThkListTile(
        title: l10n.logFile,
        subtitle: logger.logFilePath,
        leading: const Icon(AppIcons.copy),
        trailing: null,
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: logger.logFilePath));
          if (!context.mounted) return;
          _showCopiedToast(context, l10n.copied);
        },
      ),
      ThkListTile(
        title: l10n.remoteLogging,
        subtitle: logger.hasRemoteLogging
            ? '${l10n.enabled}\n${logger.remoteLogUrl}'
            : l10n.disabled,
        leading: Icon(logger.hasRemoteLogging ? AppIcons.cloudFill : AppIcons.cloud),
        trailing: null,
        onTap: logger.hasRemoteLogging
            ? () async {
                await Clipboard.setData(ClipboardData(text: logger.remoteLogUrl));
                if (!context.mounted) return;
                _showCopiedToast(context, l10n.copied);
              }
            : null,
      ),
      ThkListTile(
        title: l10n.viewLogs,
        leading: const Icon(AppIcons.document),
        onTap: () async {
          final text = await logger.readTail();
          if (!context.mounted) return;
          final pretty = _formatLogTail(text);
          _showLogsDialog(context, l10n, pretty);
        },
      ),
    ];
  }

  void _showCopiedToast(BuildContext context, String message) {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CupertinoAlertDialog(
        content: Text(message),
      ),
    );
  }

  void _showLogsDialog(BuildContext context, AppLocalizations l10n, String pretty) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(l10n.logsTail),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Text(
                  pretty.isEmpty ? l10n.emptyLogs : pretty,
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }
}

class _DarkModeToggle extends ConsumerWidget {
  const _DarkModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(brightnessProvider);
    final isDark = brightness == Brightness.dark;

    return ThkListTile(
      leading: Icon(isDark
          ? AppIcons.moonFill
          : AppIcons.sunMaxFill),
      title: 'Dark Mode',
      subtitle: isDark ? 'Dark' : 'Light',
      trailing: CupertinoSwitch(
        value: isDark,
        onChanged: (_) {
          ref.read(brightnessProvider.notifier).toggle();
          ref
              .read(settingsControllerProvider.notifier)
              .saveDarkMode(!isDark);
        },
      ),
    );
  }
}

String _formatLogTail(String raw) {
  final buf = StringBuffer();
  final lines = const LineSplitter().convert(raw);
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    try {
      final m = jsonDecode(line) as Map<String, dynamic>;
      final id = m['id'] as String? ?? '';
      final ts = m['ts'] as String? ?? '';
      final level = m['level'] as String? ?? '';
      final msg = m['msg'] as String? ?? '';
      final attrs = m['attrs'] as Map<String, dynamic>?;
      final err = m['err'] as Map<String, dynamic>?;

      buf.write('[$ts][$level] $msg');
      if (id.isNotEmpty) {
        buf.write(' id=${id.substring(0, id.length > 10 ? 10 : id.length)}...');
      }
      if (attrs != null && attrs.isNotEmpty) {
        buf.write(' ');
        buf.write(attrs.entries.map((e) => '${e.key}=${e.value}').join(' '));
      }
      if (err != null) {
        buf.write('\n  err: ${err['msg'] ?? ''}');
        final stack = err['stack'] as String?;
        if (stack != null && stack.isNotEmpty) {
          buf.write('\n  stack: ');
          buf.write(stack.replaceAll('\n', '\n  '));
        }
      }
      buf.writeln();
    } catch (_) {
      buf.writeln(line);
    }
  }
  return buf.toString();
}

class _LlmSettingsEntry extends ConsumerWidget {
  const _LlmSettingsEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final providersAsync = ref.watch(llmProvidersProvider);

    final subtitle = providersAsync.when(
      data: (providers) => l10n.modelCount(providers.length),
      loading: () => l10n.loadingSettings,
      error: (_, _) => l10n.noModels,
    );

    return ThkListTile(
      leading: const Padding(
        padding: EdgeInsets.only(bottom: 1.5),
        child: Icon(AppIcons.cloud),
      ),
      title: l10n.llmSettings,
      subtitle: subtitle,
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => const LlmSettingsScreen(),
          ),
        );
      },
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final currentName = _localeName(currentLocale, l10n);

    return ThkListTile(
      leading: const Padding(
        padding: EdgeInsets.only(top: 1.5),
        child: Icon(AppIcons.globe),
      ),
      title: l10n.language,
      subtitle: l10n.languageSubtitle(currentName),
      additionalInfo: currentName,
      onTap: () => _showLanguagePicker(context, ref, currentLocale, l10n),
    );
  }

  String _localeName(Locale? locale, AppLocalizations l10n) {
    if (locale == null) return l10n.systemDefault;
    if (locale.languageCode == 'en') return l10n.english;
    if (locale.languageCode == 'zh') return l10n.chinese;
    return locale.languageCode;
  }

  void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    Locale? currentLocale,
    AppLocalizations l10n,
  ) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(l10n.language),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                ref.read(settingsControllerProvider.notifier).saveLocale(null);
                Navigator.of(context).pop();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.systemDefault),
                  if (currentLocale == null)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(AppIcons.check, size: 18, color: AppColors.accent),
                    ),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                ref.read(settingsControllerProvider.notifier).saveLocale('en');
                Navigator.of(context).pop();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.english),
                  if (currentLocale?.languageCode == 'en')
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(AppIcons.check, size: 18, color: AppColors.accent),
                    ),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                ref.read(settingsControllerProvider.notifier).saveLocale('zh');
                Navigator.of(context).pop();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.chinese),
                  if (currentLocale?.languageCode == 'zh')
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(AppIcons.check, size: 18, color: AppColors.accent),
                    ),
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        );
      },
    );
  }
}


class _FaceIdToggle extends ConsumerWidget {
  const _FaceIdToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsControllerProvider);
    final enabled = settingsAsync.whenOrNull(data: (s) => s.faceIdEnabled) ?? true;

    return ThkListTile(
      leading: const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Icon(AppIcons.lockShield),
      ),
      title: l10n.faceIdLock,
      subtitle: l10n.faceIdLockSubtitle,
      trailing: CupertinoSwitch(
        value: enabled,
        onChanged: (value) {
          ref.read(settingsControllerProvider.notifier).saveFaceIdEnabled(value);
        },
      ),
    );
  }
}


class _TtsEntry extends ConsumerWidget {
  const _TtsEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ThkListTile(
      leading: const Padding(
        padding: EdgeInsets.only(bottom: 2),
        child: Icon(AppIcons.ttsPlay),
      ),
      title: l10n.ttsVoiceSettings,
      subtitle: l10n.ttsVoiceSettingsSubtitle,
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const TtsSettingsScreen()),
        );
      },
    );
  }
}

class _BackupEntry extends ConsumerWidget {
  const _BackupEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pathsAsync = ref.watch(appPathsProvider);
    
    return ThkListTile(
      title: l10n.backupData,
      leading: const Padding(
        padding: EdgeInsets.only(top: 0.5),
        child: Icon(AppIcons.share),
      ),
      onTap: () async {
        final paths = pathsAsync.value;
        if (paths == null) return;
        if (!context.mounted) return;

        // 关键：在异步操作前固定 navigator 引用，避免 widget 销毁时
        // 直接调 Navigator.of(context).pop() 触发 NavigatorState.dispose
        // 期间的 !_debugLocked 断言。
        final navigator = Navigator.of(context, rootNavigator: true);

        // 显示进度对话框（fire-and-forget，不阻塞后续 export 流程）。
        unawaited(
          showCupertinoDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => CupertinoAlertDialog(
              title: Text(l10n.backupInProgress),
              content: const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CupertinoActivityIndicator(),
              ),
            ),
          ).then((_) {}).catchError((_) {}),
        );

        File? zipFile;
        Object? exportError;
        try {
          final exportService = ExportService(rootDir: paths.rootDir);
          zipFile = await exportService.exportFull(
            appVersion: '1.0.0', // TODO: 从 package_info 获取
          );
        } catch (e) {
          exportError = e;
        } finally {
          // 无论成功失败，都关闭进度对话框。
          // 用 navigator.canPop() 而非 context.mounted：
          //   - canPop() 检查 root navigator 自身状态（不受 widget 销毁影响）
          //   - 避免 widget 已 dispose 时仍尝试 pop 触发 _debugLocked
          if (navigator.canPop()) {
            navigator.pop();
          }
        }

        if (exportError != null) {
          if (context.mounted) {
            showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: Text(l10n.error),
                content: Text(exportError.toString()),
                actions: [
                  CupertinoDialogAction(
                    child: Text(l10n.ok),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            );
          }
          return;
        }

        // 弹系统分享面板，期间 Flutter 可能进入 inactive；不再操作 Navigator。
        await Share.shareXFiles(
          [XFile(zipFile!.path)],
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        );
      },
    );
  }
}

class _RestoreEntry extends ConsumerWidget {
  const _RestoreEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pathsAsync = ref.watch(appPathsProvider);
    
    return ThkListTile(
      title: l10n.restoreData,
      leading: const Padding(
        padding: EdgeInsets.only(top: 0.5),
        child: Icon(AppIcons.download),
      ),
      onTap: () async {
        final paths = pathsAsync.value;
        if (paths == null) return;
        if (!context.mounted) return;

        // 1. 选文件（异步，期间 widget 可能被销毁）
        FilePickerResult? pickResult;
        try {
          pickResult = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['zip'],
          );
        } catch (_) {
          return;
        }
        if (!context.mounted) return;
        if (pickResult == null || pickResult.files.isEmpty) return;
        final zipFile = File(pickResult.files.first.path!);

        // 2. 冲突对话框（await user choice）
        final importService = ImportService(rootDir: paths.rootDir);
        final hasExisting = importService.hasExistingData();

        ImportMode? mode = ImportMode.overwrite;
        if (hasExisting) {
          if (!context.mounted) return;
          mode = await showCupertinoDialog<ImportMode>(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: Text(l10n.restoreConflictTitle),
              content: Text(l10n.restoreConflictMessage),
              actions: [
                CupertinoDialogAction(
                  child: Text(l10n.restoreOverwrite),
                  onPressed: () =>
                      Navigator.of(ctx).pop(ImportMode.overwrite),
                ),
                CupertinoDialogAction(
                  child: Text(l10n.restoreMerge),
                  onPressed: () => Navigator.of(ctx).pop(ImportMode.merge),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: Text(l10n.cancel),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          );
          if (mode == null) return;
        }
        if (!context.mounted) return;

        // 3. 在异步操作前固定 navigator，进度对话框关闭统一走 navigator.canPop()
        final navigator = Navigator.of(context, rootNavigator: true);

        // 显示进度对话框（fire-and-forget）。
        unawaited(
          showCupertinoDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => CupertinoAlertDialog(
              title: Text(l10n.restoreInProgress),
              content: const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CupertinoActivityIndicator(),
              ),
            ),
          ).then((_) {}).catchError((_) {}),
        );

        ImportResult? importResult;
        Object? importError;
        try {
          importResult = await importService.importFull(
            zipFile: zipFile,
            mode: mode,
          );
        } catch (e) {
          importError = e;
        } finally {
          // 无论成功失败，都关闭进度对话框。
          // canPop() 不依赖 context，避免 widget 销毁时触发 _debugLocked。
          if (navigator.canPop()) {
            navigator.pop();
          }
        }

        if (!context.mounted) return;

        // 4. 错误优先（原始异常对象）
        if (importError != null) {
          showCupertinoDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: Text(l10n.error),
              content: Text(importError.toString()),
              actions: [
                CupertinoDialogAction(
                  child: Text(l10n.ok),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          );
          return;
        }

        // 5. 业务结果
        if (importResult != null) {
          // 复制到非空局部变量，避免嵌套 if 内 Dart type promotion 失效
          final result = importResult;
          if (result.status == ImportResultStatus.success) {
            // 刷新页面
            ref.invalidate(appPathsProvider);
            ref.invalidate(themeListControllerProvider);

            showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: Text(l10n.success),
                content: Text(l10n.restoreSuccess),
                actions: [
                  CupertinoDialogAction(
                    child: Text(l10n.ok),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            );
          } else {
            showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: Text(l10n.error),
                content: Text(result.message ?? l10n.restoreFailed),
                actions: [
                  CupertinoDialogAction(
                    child: Text(l10n.ok),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            );
          }
        }
      },
    );
  }
}

