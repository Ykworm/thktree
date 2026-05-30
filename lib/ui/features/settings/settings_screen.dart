import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_logger.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/ui/features/llm/llm_providers_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pathsAsync = ref.watch(appPathsProvider);
    final loggerAsync = ref.watch(appLoggerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
          _LanguageTile(),
          _LlmProvidersEntry(),
          loggerAsync.when(
            data: (logger) => _LogsTile(logger: logger),
            error: (e, st) => ListTile(title: Text(e.toString())),
            loading: () => ListTile(title: Text(l10n.loadingLogger)),
          ),
          pathsAsync.when(
            data: (paths) => _PathsTile(paths: paths),
            error: (e, st) => ListTile(title: Text(e.toString())),
            loading: () => ListTile(title: Text(l10n.loadingPaths)),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

class _LogsTile extends StatelessWidget {
  const _LogsTile({required this.logger});

  final AppLogger logger;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        ListTile(
          title: Text(l10n.logFile),
          subtitle: Text(logger.logFilePath),
          trailing: const Icon(Icons.copy),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: logger.logFilePath));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copied)));
          },
        ),
        ListTile(
          title: Text(l10n.remoteLogging),
          subtitle: Text(
            logger.hasRemoteLogging ? '${l10n.enabled}\n${logger.remoteLogUrl}' : l10n.disabled,
          ),
          trailing: Icon(logger.hasRemoteLogging ? Icons.cloud_done : Icons.cloud_off),
          onTap: logger.hasRemoteLogging
              ? () async {
                  await Clipboard.setData(ClipboardData(text: logger.remoteLogUrl));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copied)));
                }
              : null,
        ),
        ListTile(
          title: Text(l10n.viewLogs),
          trailing: const Icon(Icons.article),
          onTap: () async {
            final text = await logger.readTail();
            if (!context.mounted) return;
            final pretty = _formatLogTail(text);
            await showDialog<void>(
              context: context,
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return AlertDialog(
                  title: Text(l10n.logsTail),
                  content: SizedBox(
                    width: 560,
                    child: SingleChildScrollView(
                      child: SelectableText(pretty.isEmpty ? l10n.emptyLogs : pretty),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.close),
                    ),
                  ],
                );
              },
            );
          },
        ),
        const Divider(height: 1),
      ],
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

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.cloud),
          title: Text(l10n.llmProvidersTitle),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LlmProvidersScreen(),
              ),
            );
          },
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _PathsTile extends StatelessWidget {
  const _PathsTile({required this.paths});

  final AppPaths paths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      title: Text(l10n.dataRoot),
      subtitle: Text(paths.rootDir.path),
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

    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.language),
      subtitle: Text(l10n.languageSubtitle(currentName)),
      trailing: const Icon(Icons.chevron_right),
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
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.language),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LanguageOption(
                label: l10n.systemDefault,
                isSelected: currentLocale == null,
                onTap: () {
                  ref.read(settingsControllerProvider.notifier).saveLocale(null);
                  Navigator.of(context).pop();
                },
              ),
              _LanguageOption(
                label: l10n.english,
                isSelected: currentLocale?.languageCode == 'en',
                onTap: () {
                  ref.read(settingsControllerProvider.notifier).saveLocale('en');
                  Navigator.of(context).pop();
                },
              ),
              _LanguageOption(
                label: l10n.chinese,
                isSelected: currentLocale?.languageCode == 'zh',
                onTap: () {
                  ref.read(settingsControllerProvider.notifier).saveLocale('zh');
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: onTap,
    );
  }
}
