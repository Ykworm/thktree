import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_logger.dart';

import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/ui/features/llm/llm_providers_screen.dart';

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
            _LlmProvidersEntry(),
          ],
        ),
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
        leading: Icon(logger.hasRemoteLogging ? CupertinoIcons.cloud_fill : CupertinoIcons.cloud),
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
        leading: const Icon(CupertinoIcons.doc_text),
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
                  style: const TextStyle(
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

class _LlmProvidersEntry extends ConsumerWidget {
  const _LlmProvidersEntry();

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
      leading: const Icon(AppIcons.cloud),
      title: l10n.llmProvidersTitle,
      subtitle: subtitle,
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => const LlmProvidersScreen(),
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
      leading: const Icon(CupertinoIcons.globe),
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
                      child: Icon(AppIcons.check, size: 18, color: CupertinoColors.systemBlue),
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
                      child: Icon(AppIcons.check, size: 18, color: CupertinoColors.systemBlue),
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
                      child: Icon(AppIcons.check, size: 18, color: CupertinoColors.systemBlue),
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
