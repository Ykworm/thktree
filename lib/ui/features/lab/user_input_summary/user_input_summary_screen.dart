import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/lab/user_input_summary/user_input_summary_controller.dart';

/// 可选的天数范围。
const _kDayOptions = [7, 14, 30, 90];

/// 用户输入总结页面。
///
/// - 顶部天数选择 chips
/// - 报告展示区（Markdown 渲染）
/// - 支持复制
class UserInputSummaryScreen extends ConsumerStatefulWidget {
  const UserInputSummaryScreen({super.key});

  @override
  ConsumerState<UserInputSummaryScreen> createState() =>
      _UserInputSummaryScreenState();
}

class _UserInputSummaryScreenState
    extends ConsumerState<UserInputSummaryScreen> {
  @override
  void initState() {
    super.initState();
    // 延迟初始化，等 controller 就绪
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userInputSummaryControllerProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(userInputSummaryControllerProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      child: CustomScrollView(
        slivers: [
          ThkNavBar.large(
            title: l10n.userInputSummaryTitle,
          ),
          // 天数选择 chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: _DaysChips(
                selected: state.days,
                onChanged: (days) {
                  ref
                      .read(userInputSummaryControllerProvider.notifier)
                      .changeDays(days);
                },
              ),
            ),
          ),
          // 内容区
          if (state.phase == SummaryPhase.scanning ||
              state.phase == SummaryPhase.analyzing)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildLoading(context, state),
            )
          else if (state.phase == SummaryPhase.error)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildError(context, state),
            )
          else if (state.cache?.reportMarkdown != null)
            SliverToBoxAdapter(
              child: _buildReport(context, state),
            )
          else
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmpty(context, state),
            ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context, UserInputSummaryState state) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 16),
          Text(
            state.phase == SummaryPhase.scanning
                ? l10n.userInputSummaryScanning
                : l10n.userInputSummaryAnalyzing,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          if (state.inputs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.userInputSummaryFoundInputs(state.inputs.length),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: 24),
          CupertinoButton(
            onPressed: () {
              ref.read(userInputSummaryControllerProvider.notifier).cancel();
            },
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, UserInputSummaryState state) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.userInputSummaryError,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () {
                ref
                    .read(userInputSummaryControllerProvider.notifier)
                    .startAnalysis();
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, UserInputSummaryState state) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.doc_text,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.userInputSummaryEmpty(state.days),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () {
                ref
                    .read(userInputSummaryControllerProvider.notifier)
                    .startAnalysis();
              },
              child: Text(l10n.userInputSummaryGenerate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(BuildContext context, UserInputSummaryState state) {
    final l10n = AppLocalizations.of(context)!;
    final report = state.cache!.reportMarkdown!;
    final inputCount = state.cache!.inputCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 报告信息栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.doc_text,
                  size: 20,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.userInputSummaryReportInfo(
                      state.days,
                      inputCount,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 报告内容
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              report,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: AppColors.surfaceMuted,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: report));
                    _showCopiedToast(context);
                  },
                  child: Text(
                    l10n.userInputSummaryCopy,
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton.filled(
                  onPressed: () {
                    ref
                        .read(userInputSummaryControllerProvider.notifier)
                        .startAnalysis();
                  },
                  child: Text(l10n.userInputSummaryRefresh),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  void _showCopiedToast(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(AppLocalizations.of(context)!.copied),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
    // 自动关闭
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }
}

/// 天数选择 Chips。
class _DaysChips extends StatelessWidget {
  const _DaysChips({
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final days in _kDayOptions) ...[
          if (days != _kDayOptions.first) const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onChanged(days),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: days == selected
                    ? AppColors.accent
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$days',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: days == selected
                      ? AppColors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
        const Spacer(),
        Text(
          '天',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
