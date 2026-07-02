import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thk_tree/data/services/keyword_analysis_storage.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/features/lab/keyword_ranking/keyword_analysis_controller.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// 关键词分析 — Leaf 选择屏（Task 8c）。
///
/// 展示所有 theme 的 chat leaf，支持多选 + 全选/取消全选。
/// 选中后点击「开始分析」触发 Prompt A + B 分析流程。
///
/// 设计原则（§ 5.6）：
/// - Theme 列表：展示 theme 名称，不可直接选择
/// - 每个 leaf：checkbox + 状态徽章（pending/fresh/stale）
/// - 顶部导航栏：返回 + 「开始分析」按钮
/// - 支持全选/取消全选
class LeafSelectionScreen extends ConsumerStatefulWidget {
  const LeafSelectionScreen({super.key});

  @override
  ConsumerState<LeafSelectionScreen> createState() =>
      _LeafSelectionScreenState();
}

class _LeafSelectionScreenState extends ConsumerState<LeafSelectionScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    final controller = ref.read(keywordAnalysisControllerProvider.notifier);
    await controller.loadThemesAndLeaves();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(brightnessProvider);
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(keywordAnalysisControllerProvider.notifier);
    final analysisState = ref.watch(keywordAnalysisControllerProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: l10n.keywordRankingTitle,
        middle: Text(l10n.keywordRankingSelectLeaves),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: controller.selectedLeafIds.isEmpty
              ? null
              : () => _startAnalysis(context),
          child: Text(
            l10n.keywordRankingStartAnalysis,
            style: TextStyle(
              fontSize: 17,
              color: controller.selectedLeafIds.isEmpty
                  ? AppColors.textTertiary
                  : null,
            ),
          ),
        ),
      ),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _buildContent(context, l10n, controller, analysisState),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    KeywordAnalysisController controller,
    AsyncValue<AnalysisProgress> analysisState,
  ) {
    final themeLeaves = controller.themeLeaves;

    if (themeLeaves.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.tray,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.keywordRankingNoThemes,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 使用说明
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 8),
          child: Text(
            l10n.keywordRankingSelectLeavesHint,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        // 选中计数
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
          child: Text(
            l10n.keywordRankingSelectLeavesSelected(
              controller.selectedLeafIds.length,
            ),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ),

        // Theme + Leaf 列表
        Expanded(
          child: CustomScrollView(
            slivers: [
              for (final theme in themeLeaves) ...[
                // Theme 标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.folder,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            theme.themeTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // 全选/取消全选按钮
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          onPressed: () {
                            setState(() {
                              final allSelected = theme.leaves.every(
                                  (l) =>
                                      controller.selectedLeafIds
                                          .contains(l.nodeId));
                              if (allSelected) {
                                controller
                                    .deselectAllForTheme(theme.themeId);
                              } else {
                                controller
                                    .selectAllForTheme(theme.themeId);
                              }
                            });
                          },
                          child: Text(
                            theme.leaves.every((l) =>
                                    controller.selectedLeafIds
                                        .contains(l.nodeId))
                                ? l10n.keywordRankingDeselectAll
                                : l10n.keywordRankingSelectAll,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Leaf 列表
                SliverList(
                  delegate: SliverChildListDelegate([
                    for (final leaf in theme.leaves)
                      _LeafTile(
                        leaf: leaf,
                        isSelected: controller.selectedLeafIds
                            .contains(leaf.nodeId),
                        onToggle: () {
                          setState(() {
                            controller.toggleLeaf(leaf.nodeId);
                          });
                        },
                      ),
                  ]),
                ),
              ],
              // 底部留白
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),

        // 分析进度/状态栏
        analysisState.when(
          data: (progress) {
            if (progress.phase == AnalysisPhase.extracting ||
                progress.phase == AnalysisPhase.aggregating) {
              return _ProgressBanner(
                progress: progress,
                onCancel: () {
                  controller.cancel();
                  controller.reset();
                },
              );
            }
            if (progress.phase == AnalysisPhase.done) {
              return _DoneBanner(
                onDismiss: () {
                  controller.reset();
                  if (context.mounted) {
                    context.pop();
                  }
                },
              );
            }
            if (progress.phase == AnalysisPhase.error) {
              return _ErrorBanner(
                error: progress.error ?? '',
                onRetry: () => _startAnalysis(context),
                onDismiss: controller.reset,
              );
            }
            return const SizedBox.shrink();
          },
          loading: () => const SizedBox.shrink(),
          error: (e, _) => _ErrorBanner(
            error: e.toString(),
            onRetry: () => _startAnalysis(context),
            onDismiss: controller.reset,
          ),
        ),
      ],
    );
  }

  Future<void> _startAnalysis(BuildContext context) async {
    final controller = ref.read(keywordAnalysisControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    // 二次确认
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.keywordRankingStartAnalysis),
        content: Text(
          l10n.keywordRankingSelectLeavesSelected(
            controller.selectedLeafIds.length,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.keywordRankingStartAnalysis),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await controller.startAnalysis();
    }
  }
}

/// 单个 leaf 行：checkbox + 状态徽章。
class _LeafTile extends StatelessWidget {
  const _LeafTile({
    required this.leaf,
    required this.isSelected,
    required this.onToggle,
  });

  final LeafWithStatus leaf;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(52, 10, 20, 10),
        color: material.Colors.transparent,
        child: Row(
          children: [
            // Checkbox
            Icon(
              isSelected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              size: 24,
              color: isSelected ? AppColors.accent : AppColors.textTertiary,
            ),
            const SizedBox(width: 12),

            // Title
            Expanded(
              child: Text(
                leaf.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            // 状态徽章
            _StatusBadge(status: leaf.status, l10n: l10n),
          ],
        ),
      ),
    );
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
      LeafStatus.pending => (l10n.keywordRankingLeafStatusPending, AppColors.textTertiary),
      LeafStatus.fresh => (l10n.keywordRankingLeafStatusFresh, AppColors.accent),
      LeafStatus.stale => (l10n.keywordRankingLeafStatusStale, AppColors.destructive),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 分析进度横幅。
class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({
    required this.progress,
    required this.onCancel,
  });

  final AnalysisProgress progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12),
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const CupertinoActivityIndicator(radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  progress.phase == AnalysisPhase.extracting
                      ? '${l10n.keywordRankingAnalyzing} '
                        '${progress.completedLeaves}/${progress.totalLeaves}'
                      : l10n.keywordRankingAnalyzing,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onCancel,
                child: Text(
                  l10n.cancel,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.destructive,
                  ),
                ),
              ),
            ],
          ),
          if (progress.currentLeafTitle != null) ...[
            const SizedBox(height: 4),
            Text(
              progress.currentLeafTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: material.LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: AppColors.border,
              valueColor: material.AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分析完成横幅。
class _DoneBanner extends StatelessWidget {
  const _DoneBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12),
      color: AppColors.surface,
      child: Row(
        children: [
          Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 20,
            color: AppColors.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.keywordRankingAnalysisDone,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: onDismiss,
            child: Text(
              'OK',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分析错误横幅。
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.error,
    required this.onRetry,
    required this.onDismiss,
  });

  final String error;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12),
      color: AppColors.destructive.withValues(alpha: 0.1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: 18,
                color: AppColors.destructive,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.keywordRankingAnalysisFailed(error),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.destructive,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                onPressed: onDismiss,
                child: Text(
                  l10n.cancel,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                onPressed: onRetry,
                child: Text(
                  l10n.retry,
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
    );
  }
}
