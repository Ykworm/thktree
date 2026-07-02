import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// 关键词排行榜主屏。
///
/// Lab tab 子功能入口（P.9 候选），用于回顾用户最近的思考脉络：
///   - LLM 抽取每个 chat 的核心关键词（Prompt A）
///   - 跨 theme/leaf 聚合 + score 排序（Prompt B）
///   - 支持点击关键词进入详情、跳转回 chat 等
///
/// 当前（Task 7）仅提供路由占位，List / Detail / 选择 leaf 等视图
/// 在后续 Task（8 / 9 / 10）中实现。
class KeywordRankingScreen extends ConsumerWidget {
  const KeywordRankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.keywordRankingTitle),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.keywordRankingComingSoon,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}