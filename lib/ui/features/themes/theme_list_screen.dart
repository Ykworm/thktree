import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart'
    show localizedThemeTitle;
import 'package:thk_tree/ui/features/themes/theme_list_controller.dart';

class ThemeListScreen extends ConsumerWidget {
  const ThemeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themesAsync = ref.watch(themeListControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            onPressed: () => ref.read(themeListControllerProvider.notifier).reindex(),
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: themesAsync.when(
        data: (themes) {
          if (themes.isEmpty) {
            return Center(child: Text(l10n.noThemesYet));
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: themes.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final theme = themes[index];
                        return ListTile(
                          title: Text(localizedThemeTitle(l10n, theme.title)),
                          subtitle: kDebugMode ? Text(theme.themeId) : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/themes/${theme.themeId}/tree'),
                        );
                      },
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: themes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final theme = themes[index];
                  return ListTile(
                    title: Text(localizedThemeTitle(l10n, theme.title)),
                    subtitle: kDebugMode ? Text(theme.themeId) : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/themes/${theme.themeId}/tree'),
                  );
                },
              );
            },
          );
        },
        error: (e, st) => Center(child: Text(e.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final title = await _promptTitle(context);
          if (title == null) return;
          if (!context.mounted) return;
          await ref.read(themeListControllerProvider.notifier).createTheme(title: title);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<String?> _promptTitle(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.newTheme),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.titleHint),
          onSubmitted: (value) {
            final composing = controller.value.composing;
            if (composing.isValid && !composing.isCollapsed) return;
            Navigator.of(context).pop(value.trim().isEmpty ? null : value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.of(context).pop(value.isEmpty ? null : value);
            },
            child: Text(l10n.create),
          ),
        ],
      );
    },
  );
}
