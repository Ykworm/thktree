import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// 占位屏幕：Lab tab 的占位实现。
///
/// P.9（Lab tab）目前仅暴露一个 tab entry，具体子功能
/// （AI 摘要交互卡 / 多节点对比 / 思维碰撞原型 / AI 写节点 / AI 节点标签建议）
/// 后续单独迭代，本屏仅提供兜底展示，避免空指针或全黑页。
///
/// 视觉：白色背景（[AppColors.surface]）兜底，顶部展示 `l10n.labEmptyHint` 占位文案，
/// 下方居中展示 `assets/background/lab_bg_32pt.png` 装饰图（`BoxFit.contain` 保持比例，不撑满）。
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
