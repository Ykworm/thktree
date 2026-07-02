import 'package:flutter/cupertino.dart';

import 'package:thk_tree/data/services/keyword_global_storage.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';

/// 关键词排行榜列表视图（Task 8b）。
///
/// 渲染全局聚合结果 [KeywordGlobalFile]，作为 sliver 嵌入外层
/// [CustomScrollView]（由 [KeywordRankingScreen] 提供）：
///   - 顶部「上次更新」时间
///   - 按 score 倒序排列的排名行
///   - 每行：排名 + 关键词 + score (0.00-1.00) + 跨 theme/leaf/depth 子标题
///   - 若该 keyword 的 stale 占比 > 0，在 trailing 显示 ⚠️ 徽章
///
/// 点击行触发 [onKeywordTap]（Task 9 Detail 视图）。
class KeywordListView extends StatelessWidget {
  const KeywordListView({
    super.key,
    required this.file,
    this.onKeywordTap,
  });

  final KeywordGlobalFile file;
  final void Function(GlobalKeywordEntry entry)? onKeywordTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 按 score 倒序；score 相同则按 crossThemeCount 降序保持稳定顺序。
    final sorted = file.keywords.values.toList(growable: false)
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return b.crossThemeCount.compareTo(a.crossThemeCount);
      });

    final lastUpdated = file.updatedAt;
    final children = <Widget>[];

    // 上次更新时间
    children.add(Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 12),
      child: lastUpdated != null
          ? Text(
              '${l10n.keywordRankingLastUpdated} · '
              '${_formatTimestamp(lastUpdated)}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          : Text(
              l10n.keywordRankingLastUpdated,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
    ));

    if (sorted.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Center(
          child: Text(
            l10n.keywordRankingEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ));
    } else {
      for (int i = 0; i < sorted.length; i++) {
        final entry = sorted[i];
        final rank = i + 1;
        final tile = ThkListTile(
          leading: SizedBox(
            width: 28,
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          title: entry.keyword,
          subtitle: l10n.keywordRankingLeafCount(
            entry.crossThemeCount,
            entry.crossLeafCount,
            entry.depthAvg.toStringAsFixed(1),
          ),
          additionalInfo: entry.score.toStringAsFixed(2),
          trailing: entry.staleRatio > 0
              ? Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: 18,
                  color: AppColors.destructive,
                  semanticLabel: l10n.keywordRankingStaleBadge,
                )
              : ThkListTile.chevron,
          onTap: onKeywordTap == null ? null : () => onKeywordTap!(entry),
        );
        children.add(tile);
        if (i < sorted.length - 1) {
          children.add(Padding(
            padding: const EdgeInsetsDirectional.only(start: 56),
            child: Container(height: 0.5, color: AppColors.border),
          ));
        }
      }
    }

    return SliverList(
      delegate: SliverChildListDelegate(children),
    );
  }

  /// 简化版时间戳：本地时区，yyyy-MM-dd HH:mm。
  /// 不使用 intl 包以保持轻量。
  String _formatTimestamp(DateTime utc) {
    final local = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
