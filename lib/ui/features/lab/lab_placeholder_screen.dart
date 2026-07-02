import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';

/// Lab tab 占位屏幕 + 子功能入口列表。
///
/// 当前（Task 7）只暴露已上线的「关键词排行榜」入口：
///   - 点击卡片 → push 到 `/lab/keyword-ranking`
///
/// 其他 Lab 子功能（AI 摘要交互卡 / 多节点对比 / 思维碰撞原型 / AI 写节点 /
/// AI 节点标签建议）后续单独迭代，本屏保留兜底视觉（lab_bg 装饰图）。
class LabPlaceholderScreen extends ConsumerWidget {
  const LabPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.surface,
      navigationBar: CupertinoNavigationBar(middle: Text(l10n.labTabLabel)),
      child: SafeArea(
        child: Column(
          children: [
            // 顶部 hint 文字
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Text(
                l10n.labEmptyHint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            // Lab 子功能入口列表
            ThkListSection(
              children: [
                ThkListTile(
                  title: l10n.keywordRankingTitle,
                  subtitle: l10n.keywordRankingSubtitle,
                  onTap: () {
                    context.push('/lab/keyword-ranking');
                  },
                ),
              ],
            ),
            // 下方装饰图（BoxFit.contain 保持比例，居顶对齐）
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Image.asset(
                  'assets/background/lab_bg_32pt.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}