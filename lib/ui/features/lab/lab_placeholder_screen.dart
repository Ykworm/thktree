import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_durations.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';

/// Lab tab — 实验台调性，但 **不是** 深色夜店。
///
/// - 硬约束：保留顶部 [lab_bg_with_title] 英雄图（图内已有 Lab 字标）
/// - 画布：Warm Paper [pageBg]，与书房同底座，但用 Lab 三色徽章区分
/// - 不再重复 EXPERIMENT / Lab 标题；图下直接接功能卡
class LabPlaceholderScreen extends ConsumerWidget {
  const LabPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 顶图偏亮/彩，状态栏用深色图标更清晰
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.pageBg,
        child: CustomScrollView(
          slivers: [
            // ── Hero：顶图 + 底缘柔和过渡到纸底（消掉硬切缝）──────────
            SliverToBoxAdapter(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Image.asset(
                    'assets/background/lab_bg_with_title.png',
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                  ),
                  // 白 → pageBg 渐变，盖住图底白边与内容区的硬接缝
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 48,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.pageBg.withValues(alpha: 0),
                              AppColors.pageBg,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── 功能卡（浅色纸上的实验入口）────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSp.screenPadding,
                4,
                AppSp.screenPadding,
                bottomPad > 0 ? bottomPad + 16 : 32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _FeatureCard(
                    icon: CupertinoIcons.doc_text_search,
                    title: l10n.keywordRankingTitle,
                    description: l10n.keywordRankingSubtitle,
                    accent: AppColors.labAccentBlue,
                    onTap: () => context.push('/lab/keyword-ranking'),
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    icon: CupertinoIcons.doc_plaintext,
                    title: l10n.userInputSummaryTitle,
                    description: l10n.userInputSummarySubtitle,
                    accent: AppColors.labAccentOrange,
                    onTap: () => context.push('/lab/user-input-summary'),
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    icon: CupertinoIcons.bolt_horizontal,
                    title: l10n.thinkingCollisionTitle,
                    description: l10n.thinkingCollisionSubtitle,
                    accent: AppColors.labAccentPurple,
                    onTap: () => context.push('/lab/thinking-collision'),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 浅色实验入口卡：白卡 + 左侧色条 + 彩色图标井（与主题列表徽章同源逻辑，
/// 但用 Lab 霓虹三色，形成「同底座、不同口音」）。
class _FeatureCard extends StatefulWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color accent;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: AppDur.copyFeedback,
        curve: AppDur.copyFeedbackCurve,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.94 : 1.0,
          duration: AppDur.copyFeedback,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: AppSurfaces.contentCard(radius: 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 44,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.description,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: AppColors.textTertiary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
