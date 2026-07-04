import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// Lab tab 占位屏幕 + 子功能入口列表。
///
/// 当前（Task 7）只暴露已上线的「关键词排行榜」入口：
///   - 点击卡片 → push 到 `/lab/keyword-ranking`
///
/// 其他 Lab 子功能（AI 摘要交互卡 / 多节点对比 / 思维碰撞原型 / AI 写节点 /
/// AI 节点标签建议）后续单独迭代，本屏保留兜底视觉（lab_bg_with_title 装饰图）。
class LabPlaceholderScreen extends ConsumerWidget {
  const LabPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0F1035),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.surface,
        child: Column(
          children: [
            // 顶部背景图（覆盖灵动岛区域）
            Image.asset(
              'assets/background/lab_bg_with_title.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
            // 安全区域内的内容（使用 Expanded 来约束高度）
            Expanded(
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    children: [
                      // 功能块卡片
                      _FeatureCard(
                        icon: CupertinoIcons.doc_text_search,
                        title: l10n.keywordRankingTitle,
                        description: l10n.keywordRankingSubtitle,
                        color: const Color(0xFF3B82F6), // 蓝色系
                        onTap: () {
                          context.push('/lab/keyword-ranking');
                        },
                      ),
                      const SizedBox(height: 12),
                      _FeatureCard(
                        icon: CupertinoIcons.doc_plaintext,
                        title: l10n.userInputSummaryTitle,
                        description: l10n.userInputSummarySubtitle,
                        color: const Color(0xFFF97316), // 橙色系
                        onTap: () {
                          context.push('/lab/user-input-summary');
                        },
                      ),
                      const SizedBox(height: 12),
                      _FeatureCard(
                        icon: CupertinoIcons.bolt_horizontal,
                        title: l10n.thinkingCollisionTitle,
                        description: l10n.thinkingCollisionSubtitle,
                        color: const Color(0xFFA855F7), // 紫色系
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

/// 功能块卡片组件
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.color = AppColors.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}