import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';
import 'package:thk_tree/ui/features/themes/theme_ui_prefs_controller.dart';

/// 管理当前主题下各 root tree 的显示/隐藏（PS layers 眼睛）。
class ManageTreesScreen extends ConsumerWidget {
  const ManageTreesScreen({super.key, required this.themeId});

  final String themeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(themeDetailControllerProvider(themeId));
    final prefsAsync = ref.watch(themeUiPrefsControllerProvider(themeId));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: ThkNavBar.inline(
        title: l10n.manageTrees,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(AppIcons.back),
        ),
      ),
      child: detailAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (detail) {
          final roots = detail.nodes
              .where((n) => n.parentId == null)
              .toList(growable: false)
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final hidden = prefsAsync.value?.hiddenRootIds ?? const <String>{};

          if (roots.isEmpty) {
            return Center(
              child: Text(
                l10n.emptyTree,
                style: AppTheme.body.copyWith(color: AppColors.textSecondary),
              ),
            );
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSp.screenPadding,
                12,
                AppSp.screenPadding,
                24,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4),
                  child: Text(
                    l10n.manageTreesHint,
                    style: AppTheme.caption1.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: AppSurfaces.contentCard(radius: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      children: [
                        for (var i = 0; i < roots.length; i++) ...[
                          if (i > 0)
                            Container(
                              height: 0.5,
                              margin: const EdgeInsets.only(left: 16),
                              color: AppColors.border,
                            ),
                          _ManageTreeRow(
                            root: roots[i],
                            isVisible: !hidden.contains(roots[i].nodeId),
                            onToggle: () {
                              final id = roots[i].nodeId;
                              final currentlyHidden = hidden.contains(id);
                              ref
                                  .read(
                                    themeUiPrefsControllerProvider(themeId)
                                        .notifier,
                                  )
                                  .setRootHidden(
                                    id,
                                    hidden: !currentlyHidden,
                                  );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ManageTreeRow extends StatelessWidget {
  const _ManageTreeRow({
    required this.root,
    required this.isVisible,
    required this.onToggle,
  });

  final NodeEntity root;
  final bool isVisible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.paletteForNode(root.nodeId);
    return SizedBox(
      height: AppSp.treeRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: palette.circle.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: palette.circle, width: 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                root.title,
                style: AppTheme.body.copyWith(
                  color: isVisible
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            CupertinoButton(
              key: ValueKey('toggle_visibility_${root.nodeId}'),
              padding: const EdgeInsets.all(8),
              minimumSize: Size.zero,
              onPressed: onToggle,
              child: Icon(
                isVisible ? AppIcons.eye : AppIcons.eyeSlash,
                color: isVisible
                    ? AppColors.accent
                    : AppColors.textTertiary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
