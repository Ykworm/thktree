import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart'
    show localizedThemeTitle;
import 'package:thk_tree/ui/features/themes/theme_list_controller.dart';

class ThemeListScreen extends ConsumerWidget {
  const ThemeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themesAsync = ref.watch(themeListControllerProvider);
    return ThkLargeTitlePage(
      title: l10n.themesTabLabel,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () =>
                ref.read(themeListControllerProvider.notifier).reindex(),
            child: Icon(AppIcons.refresh),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () async {
              final title = await _promptTitle(context);
              if (title == null) return;
              if (!context.mounted) return;
              await ref
                  .read(themeListControllerProvider.notifier)
                  .createTheme(title: title);
            },
            child: Icon(AppIcons.add),
          ),
        ],
      ),
      children: [
        themesAsync.when(
          data: (themes) {
            if (themes.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.accountTree,
                        size: 40,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noThemesYet,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (int i = 0; i < themes.length; i++) ...[
                  ThkListTile(
                    title: localizedThemeTitle(l10n, themes[i].title),
                    subtitle: kDebugMode ? themes[i].themeId : null,
                    trailing: ThkListTile.chevron,
                    themeId: themes[i].themeId,
                    leading: Icon(AppIcons.folder),
                    onTap: () =>
                        context.push('/themes/${themes[i].themeId}/tree'),
                  ),
                  if (i < themes.length - 1)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 56),
                      child: Container(
                        height: 0.5,
                        color: AppColors.border,
                      ),
                    ),
                ],
              ],
            );
          },
          error: (e, st) => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(child: Text(e.toString())),
          ),
          loading: () => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        ),
      ],
    );
  }
}

Future<String?> _promptTitle(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  return showCupertinoDialog<String>(
    context: context,
    builder: (context) {
      return CupertinoAlertDialog(
        title: Text(l10n.newTheme),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ThkTextField(
            controller: controller,
            placeholder: l10n.titleHint,
            autofocus: true,
            maxLength: 30,
            onSubmitted: (value) {
              final composing = controller.value.composing;
              if (composing.isValid && !composing.isCollapsed) return;
              Navigator.of(context)
                  .pop(value.trim().isEmpty ? null : value.trim());
            },
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
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
