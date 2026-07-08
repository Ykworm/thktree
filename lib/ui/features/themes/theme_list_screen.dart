import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart' show brightnessProvider;
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart'
    show kUncategorizedThemeTitle, localizedThemeTitle, formatRelativeTime;
import 'package:thk_tree/ui/features/themes/theme_list_controller.dart';
import 'package:thk_tree/domain/theme.dart';

class ThemeListScreen extends ConsumerWidget {
  const ThemeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(brightnessProvider);
    final l10n = AppLocalizations.of(context)!;
    final themesAsync = ref.watch(themeListControllerProvider);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        slivers: [
          ThkNavBar.large(
            title: l10n.themesTabLabel,
            trailing: CupertinoButton(
              key: const ValueKey('add_theme_button'),
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
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              await ref.read(themeListControllerProvider.notifier).reindex();
            },
          ),
          themesAsync.when(
            data: (themes) => SliverList(
              delegate: SliverChildListDelegate(
                _buildThemeList(themes, l10n, ref, context),
              ),
            ),
            loading: () => SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, st) => SliverFillRemaining(
              child: Center(child: Text(e.toString())),
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _buildThemeList(
  List<ThemeEntity> themes,
  AppLocalizations l10n,
  WidgetRef ref,
  BuildContext context,
) {
  if (themes.isEmpty) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.accountTree, size: 40, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(l10n.noThemesYet, style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    ];
  }

  return [
    for (int i = 0; i < themes.length; i++) ...[
      GestureDetector(
        onLongPress: () => _showThemeActions(context, ref, themes[i], l10n),
        child: ThkListTile(
          title: localizedThemeTitle(l10n, themes[i].title),
          subtitle: themes[i].lastMessagePreview ??
              formatRelativeTime(l10n, themes[i].updatedAtUtcIso8601),
          trailing: themes[i].pinned
              ? Icon(AppIcons.star, color: AppColors.accent, size: 18)
              : ThkListTile.chevron,
          themeId: themes[i].themeId,
          leading: Icon(AppIcons.folder),
          onTap: () => context.push('/themes/${themes[i].themeId}/tree'),
        ),
      ),
      if (i < themes.length - 1)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 56),
          child: Container(height: AppSp.dividerThickness, color: AppColors.border),
        ),
    ],
  ];
}

Future<void> _showThemeActions(
  BuildContext context,
  WidgetRef ref,
  ThemeEntity theme,
  AppLocalizations l10n,
) async {
  final action = await showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 'rename'),
          child: Text(l10n.renameNode),
        ),
        if (theme.title != kUncategorizedThemeTitle)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'pin'),
            child: Text(theme.pinned ? l10n.unpin : l10n.pin),
          ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, 'delete'),
          child: Text(l10n.delete),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: Text(l10n.cancel),
      ),
    ),
  );

  if (action == 'rename') {
    if (!context.mounted) return;
    final newTitle = await _promptRename(context, theme.title);
    if (newTitle != null) {
      await ref.read(themeListControllerProvider.notifier).renameTheme(
            themeId: theme.themeId,
            title: newTitle,
          );
    }
  } else if (action == 'pin') {
    await ref.read(themeListControllerProvider.notifier).togglePin(
          themeId: theme.themeId,
          pinned: !theme.pinned,
        );
  } else if (action == 'delete') {
    if (!context.mounted) return;
    final confirmed = await _confirmDelete(context, theme, l10n);
    if (confirmed == true) {
      await ref.read(themeListControllerProvider.notifier).deleteTheme(
            themeId: theme.themeId,
          );
    }
  }
}

Future<String?> _promptRename(BuildContext context, String currentTitle) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: currentTitle);
  return showCupertinoDialog<String>(
    context: context,
    builder: (context) {
      return CupertinoAlertDialog(
        title: Text(l10n.renameNode),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ThkTextField(
            controller: controller,
            placeholder: l10n.enterNewTitle,
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
            child: Text(l10n.save),
          ),
        ],
      );
    },
  );
}

Future<bool?> _confirmDelete(
    BuildContext context, ThemeEntity theme, AppLocalizations l10n) {
  return showCupertinoDialog<bool>(
    context: context,
    builder: (context) {
      return CupertinoAlertDialog(
        title: Text(l10n.deleteItem),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l10n.deleteThemeConfirm(theme.title)),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      );
    },
  );
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
            key: const ValueKey('theme_title_input'),
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
            key: const ValueKey('theme_create_button'),
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
