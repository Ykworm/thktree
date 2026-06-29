import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';

/// 占位屏幕：实验室 tab 的占位实现。
///
/// P.9（实验室 tab）目前仅暴露一个 tab entry，具体子功能
/// （AI 摘要交互卡 / 多节点对比 / 思维碰撞原型 / AI 写节点 / AI 节点标签建议）
/// 后续单独迭代，本屏仅提供兜底展示，避免空指针或全黑页。
///
/// 视觉：使用 `assets/background/lab_bg_32pt.png` 作为整页背景图（BoxFit.contain），
/// 叠加 `l10n.labEmptyHint` 占位文案。
class LabPlaceholderScreen extends ConsumerWidget {
  const LabPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(l10n.labTabLabel)),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background/lab_bg_32pt.png',
              fit: BoxFit.contain,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                l10n.labEmptyHint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
