import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thk_tree/data/services/keyword_analysis_storage.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_durations.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/lab/keyword_ranking/keyword_analysis_controller.dart';
import 'package:thk_tree/ui/features/lab/keyword_ranking/keyword_ranking_screen.dart'
    show keywordRankingFileProvider;
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// 关键词分析 — Leaf 选择屏（Task 8c）。
///
/// 展示指定 / 全部 theme 的 chat leaf，支持多选 + 全选/取消全选。
/// 选中后点击「开始分析」触发 Prompt A + B 分析流程。
///
/// 进度条放在 **顶部**（nav 下方），避免被底 tab 玻璃遮住。
class LeafSelectionScreen extends ConsumerStatefulWidget {
  const LeafSelectionScreen({super.key, this.themeId});

  /// 从主题选择页传入；为空则展示全部 theme。
  final String? themeId;

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

  String? _loadError;

  Future<void> _loadThemes() async {
    try {
      final controller = ref.read(keywordAnalysisControllerProvider.notifier);
      await controller.loadThemesAndLeaves(themeId: widget.themeId);
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isAnalyzing(AsyncValue<AnalysisProgress> analysisState) {
    return analysisState.maybeWhen(
      data: (p) =>
          p.phase == AnalysisPhase.extracting ||
          p.phase == AnalysisPhase.aggregating,
      orElse: () => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(brightnessProvider);
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(keywordAnalysisControllerProvider.notifier);
    final analysisState = ref.watch(keywordAnalysisControllerProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      // 主 CTA 在底部实心按钮；右上不再放「开始分析」
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: l10n.keywordRankingSelectThemes,
        middle: Text(l10n.keywordRankingSelectLeaves),
      ),
      child: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _loadError != null
            ? _buildError(l10n)
            : _buildContent(context, l10n, controller, analysisState),
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: AppColors.destructive,
            ),
            const SizedBox(height: 16),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadError = null;
                });
                _loadThemes();
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
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
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final analyzing = _isAnalyzing(analysisState);
    final canStart = controller.selectedLeafIds.isNotEmpty && !analyzing;

    return Column(
      children: [
        // ── 进度 / 完成 / 错误：贴在顶栏下，不会被底 tab 挡住 ──
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
                  // 刷新排行榜列表
                  ref.invalidate(keywordRankingFileProvider);
                  if (!context.mounted) return;
                  // 尽量 pop 回排行榜，保留「排行榜 → Lab」返回栈；
                  // 若栈已断再 go。
                  final router = GoRouter.of(context);
                  while (router.canPop()) {
                    final path = GoRouterState.of(context).uri.path;
                    if (path == '/lab/keyword-ranking') break;
                    router.pop();
                    if (!context.mounted) return;
                    if (GoRouterState.of(context).uri.path ==
                        '/lab/keyword-ranking') {
                      return;
                    }
                  }
                  if (context.mounted &&
                      GoRouterState.of(context).uri.path !=
                          '/lab/keyword-ranking') {
                    context.go('/lab/keyword-ranking');
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

        // 使用说明
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 8),
          child: Text(
            l10n.keywordRankingSelectLeavesHint,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),

        // 选中计数
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
          child: Text(
            l10n.keywordRankingSelectLeavesSelected(
              controller.selectedLeafIds.length,
            ),
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
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
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      16,
                      20,
                      8,
                    ),
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
                        if (!analyzing)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            onPressed: () {
                              setState(() {
                                final selectable = theme.leaves
                                    .where((l) => l.status != LeafStatus.fresh)
                                    .toList();
                                final allSelected = selectable.every(
                                  (l) => controller.selectedLeafIds.contains(
                                    l.nodeId,
                                  ),
                                );
                                if (allSelected) {
                                  controller.deselectAllForTheme(theme.themeId);
                                } else {
                                  controller.selectAllForTheme(theme.themeId);
                                }
                              });
                            },
                            child: Text(
                              theme.leaves
                                      .where(
                                        (l) => l.status != LeafStatus.fresh,
                                      )
                                      .every(
                                        (l) => controller.selectedLeafIds
                                            .contains(l.nodeId),
                                      )
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
                        isSelected: controller.selectedLeafIds.contains(
                          leaf.nodeId,
                        ),
                        onToggle: analyzing
                            ? () {}
                            : () {
                                setState(() {
                                  controller.toggleLeaf(leaf.nodeId);
                                });
                              },
                      ),
                  ]),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),

        // 底部实心主 CTA（非磨砂；accent 填充）
        if (!analyzing)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSp.screenPadding,
              8,
              AppSp.screenPadding,
              12,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ThkButton.filled(
                label: l10n.keywordRankingStartAnalysis,
                onPressed: canStart ? () => _startAnalysis(context) : null,
                disabled: !canStart,
                padding: const EdgeInsets.symmetric(vertical: 14),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _startAnalysis(BuildContext context) async {
    final controller = ref.read(keywordAnalysisControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    if (controller.selectedLeafIds.isEmpty) return;

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
      // 先立刻进入 extracting，让顶部进度条马上出现
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
    final isSelectable = leaf.status != LeafStatus.fresh;

    return GestureDetector(
      onTap: isSelectable ? onToggle : null,
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
              color: isSelectable
                  ? (isSelected ? AppColors.accent : AppColors.textTertiary)
                  : AppColors.textTertiary.withValues(alpha: 0.4),
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
                  color: isSelectable
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
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
      LeafStatus.pending => (
        l10n.keywordRankingLeafStatusPending,
        AppColors.textTertiary,
      ),
      LeafStatus.fresh => (
        l10n.keywordRankingLeafStatusFresh,
        AppColors.accent,
      ),
      LeafStatus.stale => (
        l10n.keywordRankingLeafStatusStale,
        AppColors.destructive,
      ),
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

/// 分析进度卡：高对比 accent 底 + 粗进度条 + 入场滑入。
class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.progress, required this.onCancel});

  final AnalysisProgress progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isExtracting = progress.phase == AnalysisPhase.extracting;
    final pct = (progress.progress.clamp(0.0, 1.0) * 100).round();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: AppDur.modal,
      curve: AppDur.modalCurve,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -12),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CupertinoActivityIndicator(
                    radius: 11,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isExtracting
                          ? '${l10n.keywordRankingAnalyzing} '
                                '${progress.completedLeaves}/${progress.totalLeaves}'
                          : l10n.keywordRankingAnalyzing,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentDeep,
                      ),
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    onPressed: onCancel,
                    child: Text(
                      l10n.cancel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                ],
              ),
              if (progress.currentLeafTitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  progress.currentLeafTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // 粗进度条：Tween 平滑跟进 completedLeaves
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: progress.progress.clamp(0.0, 1.0),
                  ),
                  duration: AppDur.listScroll,
                  curve: AppDur.listScrollCurve,
                  builder: (context, value, _) {
                    return material.LinearProgressIndicator(
                      value: value,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                      valueColor: material.AlwaysStoppedAnimation<Color>(
                        AppColors.accent,
                      ),
                      minHeight: 10,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分析完成卡：success 色块 + 勾选弹入 + 实心主按钮，很难被忽略。
class _DoneBanner extends StatefulWidget {
  const _DoneBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_DoneBanner> createState() => _DoneBannerState();
}

class _DoneBannerState extends State<_DoneBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    final reduce = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .reduceMotion;
    _ctrl = AnimationController(
      vsync: this,
      duration: reduce ? Duration.zero : AppDur.modal,
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            ScaleTransition(
              scale: _scale,
              child: Icon(
                CupertinoIcons.checkmark_seal_fill,
                size: 44,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.keywordRankingAnalysisDone,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ThkButton.filled(
                label: l10n.ok,
                onPressed: widget.onDismiss,
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.destructive.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.destructive.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: 22,
                  color: AppColors.destructive,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.keywordRankingAnalysisFailed(error),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.destructive,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ThkButton.plain(
                    label: l10n.cancel,
                    onPressed: onDismiss,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ThkButton.filled(
                    label: l10n.retry,
                    onPressed: onRetry,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
