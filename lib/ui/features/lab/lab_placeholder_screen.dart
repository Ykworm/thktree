import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_durations.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';

/// 专属 Lab 背景色：清冷的科技银灰（区别于书房的暖纸色）
const _kLabCoolBg = AppColors.labCoolBg;

/// Lab tab — 实验台调性。
///
/// - 调性区分：书房是“暖白/人文”，Lab 是“冷白/科技”。
/// - 我们使用极简的冷灰背景 [ _kLabCoolBg ]，搭配纯白高亮卡片。
/// - 保留原图的鲜艳与对比度（不加漂白滤镜），作为页面的视觉中心。
class LabPlaceholderScreen extends ConsumerWidget {
  const LabPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: CupertinoPageScaffold(
        backgroundColor: _kLabCoolBg,
        child: CustomScrollView(
          slivers: [
            // ── Hero：原汁原味的鲜艳顶图 ──────────
            SliverToBoxAdapter(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Image.asset(
                    'assets/background/lab_bg_with_title.png',
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                  ),
                  // 底部柔和过渡到冷灰背景
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
                              _kLabCoolBg.withValues(alpha: 0),
                              _kLabCoolBg,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── 功能卡（科技感高亮白卡）────────────────────────
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

/// 清透科技感的入口卡片：纯白底 + 淡蓝阴影 + 左侧色条 + 彩色图标井
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
          opacity: _pressed ? 0.8 : 1.0,
          duration: AppDur.copyFeedback,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.black.withValues(alpha: 0.03),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
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
                    color: accent.withValues(alpha: 0.1),
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
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
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
