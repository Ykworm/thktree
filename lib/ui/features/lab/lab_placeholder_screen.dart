import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_durations.dart';

/// Lab tab — experimental cosmos (not Warm Paper study).
///
/// Hard constraint: keep top [lab_bg_with_title] hero. Body stays on [labBg]
/// with neon-accent cards so Lab feels different from 主题 / 笔记 / 搜索.
class LabPlaceholderScreen extends ConsumerWidget {
  const LabPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.labBg,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.labBg,
        child: Column(
          children: [
            // 顶部背景图（覆盖灵动岛区域）— 必须保留
            Image.asset(
              'assets/background/lab_bg_with_title.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'EXPERIMENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: AppColors.labAccentBlue
                              .withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.labTabLabel,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _FeatureCard(
                        icon: CupertinoIcons.doc_text_search,
                        title: l10n.keywordRankingTitle,
                        description: l10n.keywordRankingSubtitle,
                        accent: AppColors.labAccentBlue,
                        onTap: () {
                          context.push('/lab/keyword-ranking');
                        },
                      ),
                      const SizedBox(height: 12),
                      _FeatureCard(
                        icon: CupertinoIcons.doc_plaintext,
                        title: l10n.userInputSummaryTitle,
                        description: l10n.userInputSummarySubtitle,
                        accent: AppColors.labAccentOrange,
                        onTap: () {
                          context.push('/lab/user-input-summary');
                        },
                      ),
                      const SizedBox(height: 12),
                      _FeatureCard(
                        icon: CupertinoIcons.bolt_horizontal,
                        title: l10n.thinkingCollisionTitle,
                        description: l10n.thinkingCollisionSubtitle,
                        accent: AppColors.labAccentPurple,
                        onTap: () {
                          context.push('/lab/thinking-collision');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Neon-edge experiment card on dark lab canvas.
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
          opacity: _pressed ? 0.92 : 1.0,
          duration: AppDur.copyFeedback,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accent.withValues(alpha: 0.45),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: AppColors.white.withValues(alpha: 0.35),
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
