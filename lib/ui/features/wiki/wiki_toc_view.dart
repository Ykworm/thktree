import 'package:flutter/cupertino.dart';
import 'package:thk_tree/data/models/wiki_node.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';

/// Wiki 目录导航底部 sheet。
///
/// 显示树形缩进目录，当前正在阅读的 section 高亮。
class WikiTocView extends StatelessWidget {
  const WikiTocView({
    super.key,
    required this.nodes,
    required this.onNodeTap,
    this.currentNodeId,
  });

  final List<WikiNode> nodes;
  final ValueChanged<String> onNodeTap;
  final String? currentNodeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(
                    AppIcons.listBullet,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.wikiTocTitle,
                    style: AppTheme.headline.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // List
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(
                  AppSp.screenPadding,
                  0,
                  AppSp.screenPadding,
                  16 + bottomPadding,
                ),
                itemCount: nodes.length,
                itemBuilder: (context, index) {
                  final node = nodes[index];
                  return _TocItem(
                    node: node,
                    isCurrent: node.nodeId == currentNodeId,
                    onTap: () => onNodeTap(node.nodeId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TocItem extends StatelessWidget {
  const _TocItem({
    required this.node,
    required this.isCurrent,
    required this.onTap,
  });

  final WikiNode node;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            SizedBox(width: (node.depth - 1) * 16),
            Expanded(
              child: Text(
                node.title,
                style: AppTheme.body.copyWith(
                  color: isCurrent ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: isCurrent
                      ? FontWeight.w700
                      : (node.depth <= 2 ? FontWeight.w600 : FontWeight.w400),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrent)
              Icon(
                AppIcons.check,
                size: 16,
                color: AppColors.accent,
              )
            else
              Icon(
                AppIcons.chevronRight,
                size: 14,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
