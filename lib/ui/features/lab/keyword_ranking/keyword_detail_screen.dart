import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import 'package:thk_tree/data/services/keyword_analysis_storage.dart';
import 'package:thk_tree/data/services/keyword_global_storage.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// 关键词详情页（Task 9）。
///
/// 展示某个关键词关联的所有 chat 卡片：
/// - 顶部：关键词 + score + 跨域统计
/// - 主体：chat 卡片列表（含分类徽章 + 状态徽章）
/// - 点击卡片 → 跳转 ThemeDetailScreen（search input 预填关键词）
class KeywordDetailScreen extends ConsumerWidget {
  const KeywordDetailScreen({
    super.key,
    required this.keyword,
  });

  final String keyword;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(brightnessProvider);
    final l10n = AppLocalizations.of(context)!;

    // 读取 keyword_global.json 获取该 keyword 的信息
    final globalStorageAsync = ref.watch(keywordGlobalStorageProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: l10n.keywordRankingTitle,
        middle: Text(keyword),
      ),
      child: globalStorageAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (globalStorage) {
          return FutureBuilder<KeywordGlobalFile>(
            future: globalStorage.loadOrInit(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CupertinoActivityIndicator());
              }
              final globalFile = snapshot.data!;
              final entry = globalFile.keywords[keyword];
              if (entry == null) {
                return Center(
                  child: Text(
                    l10n.keywordRankingEmpty,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              final leafRefs = globalFile.keywordLeafMap[keyword] ?? [];
              return _DetailContent(
                keyword: keyword,
                entry: entry,
                leafRefs: leafRefs,
              );
            },
          );
        },
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({
    required this.keyword,
    required this.entry,
    required this.leafRefs,
  });

  final String keyword;
  final GlobalKeywordEntry entry;
  final List<KeywordLeafRef> leafRefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return CustomScrollView(
      slivers: [
        // 头部：关键词信息
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // score
                Text(
                  '${l10n.keywordRankingScoreLabel}: ${entry.score.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // 跨域统计
                Text(
                  l10n.keywordRankingLeafCount(
                    entry.crossThemeCount,
                    entry.crossLeafCount,
                    entry.depthAvg.toStringAsFixed(1),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                // stale 徽章
                if (entry.staleRatio > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        size: 16,
                        color: AppColors.destructive,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.keywordRankingStaleBadge,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.destructive,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // Chat 卡片列表
        if (leafRefs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                l10n.keywordRankingNoAnalyzableLeaves,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildListDelegate([
              for (final ref in leafRefs)
                _ChatCard(
                  keyword: keyword,
                  leafRef: ref,
                ),
              const SizedBox(height: 100),
            ]),
          ),
      ],
    );
  }
}

/// 单个 chat 卡片。
///
/// 展示：chat title + 分类徽章 + 状态徽章 + 主题 + 分析时间 + 关键词列表 + 跳转按钮。
class _ChatCard extends ConsumerStatefulWidget {
  const _ChatCard({
    required this.keyword,
    required this.leafRef,
  });

  final String keyword;
  final KeywordLeafRef leafRef;

  @override
  ConsumerState<_ChatCard> createState() => _ChatCardState();
}

class _ChatCardState extends ConsumerState<_ChatCard> {
  String? _nodeTitle;
  LeafStatus _status = LeafStatus.pending;
  DateTime? _lastAnalyzedAt;
  List<KeywordEntry> _keywords = [];
  String? _categoryName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final appPaths = ref.read(appPathsProvider).requireValue;
      final nodeStore = ref.read(nodeStoreProvider).requireValue;
      final categoryStorage =
          ref.read(keywordCategoryStorageProvider).requireValue;

      // 读取节点信息
      final nodeRow = await nodeStore.getNodeRow(
        nodeId: widget.leafRef.leafId,
      );
      _nodeTitle = nodeRow['title'] as String?;

      // 读取 keyword_analysis.json
      final storage = KeywordAnalysisStorage(
        themePath: p.join(
          appPaths.themesDir.path,
          widget.leafRef.themeId,
        ),
      );
      final file = await storage.loadOrInit();
      final record = file.leaves[widget.leafRef.leafId];
      if (record != null) {
        _status = record.status;
        _lastAnalyzedAt = record.lastAnalyzedAt;
        _keywords = record.keywords;
      }

      // 读取分类名称
      final catalog = await categoryStorage.loadOrInit();
      final category =
          catalog.categories[widget.leafRef.categoryId];
      _categoryName = category?.name;

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return GestureDetector(
      onTap: () => _navigateToTheme(context),
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + 状态徽章
            Row(
              children: [
                Expanded(
                  child: Text(
                    _nodeTitle ?? widget.leafRef.leafId,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: _status, l10n: l10n),
              ],
            ),

            // 分类徽章
            if (_categoryName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _categoryName!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            // 关键词列表
            if (_keywords.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final kw in _keywords)
                    Text(
                      kw.keyword,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],

            // 分析时间
            if (_lastAnalyzedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                _formatTimestamp(_lastAnalyzedAt!),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],

            // 跳转按钮
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => _navigateToTheme(context),
                  child: Text(
                    l10n.keywordRankingJumpToChat,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTheme(BuildContext context) {
    // 跳转到 ThemeDetailScreen，search input 预填关键词
    context.push(
      '/themes/${widget.leafRef.themeId}'
      '?scrollToNodeId=${widget.leafRef.leafId}'
      '&searchPrefill=${Uri.encodeComponent(widget.keyword)}',
    );
  }

  String _formatTimestamp(DateTime utc) {
    final local = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// 状态徽章。
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.l10n});

  final LeafStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LeafStatus.pending => (
          l10n.keywordRankingLeafStatusPending,
          AppColors.textTertiary
        ),
      LeafStatus.fresh => (
          l10n.keywordRankingLeafStatusFresh,
          AppColors.accent
        ),
      LeafStatus.stale => (
          l10n.keywordRankingLeafStatusStale,
          AppColors.destructive
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == LeafStatus.stale) ...[
            Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
