import 'package:flutter/material.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// 网格底栏操作项。
class GridAction {
  const GridAction({
    this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  /// 可选的测试钩子 key。仅「更多」浮层里的分支项会设置
  /// [ValueKey('branch_button')]，方便集成测试先开「更多」再定位分支入口。
  final Key? key;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
}

/// WeChat / 备忘录风格的网格底栏 Action Sheet。
///
/// 圆形图标 + 文字标签，支持主操作和 destructive 操作分组。
class ThkGridBottomSheet {
  ThkGridBottomSheet._();

  static Future<void> show({
    required BuildContext context,
    required List<GridAction> actions,
    List<GridAction>? destructiveActions,
    String cancelLabel = '取消',
    bool showCancel = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      builder: (context) => _SheetContent(
        actions: actions,
        destructiveActions: destructiveActions,
        cancelLabel: cancelLabel,
        showCancel: showCancel,
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({
    required this.actions,
    this.destructiveActions,
    required this.cancelLabel,
    required this.showCancel,
  });

  final List<GridAction> actions;
  final List<GridAction>? destructiveActions;
  final String cancelLabel;
  final bool showCancel;

  @override
  Widget build(BuildContext context) {
    // 覆盖 showModalBottomSheet 的默认 SafeArea，手动用缩小间距替代
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomSafeGap = bottomInset > 0 ? 8.0 : 4.0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 主操作区
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _ActionGrid(actions: actions),
            ),
            // destructive 操作区
            if (destructiveActions != null && destructiveActions!.isNotEmpty) ...[
              Container(
                height: 6,
                color: AppColors.surfaceMuted,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, showCancel ? 4 : 0),
                child: _ActionGrid(actions: destructiveActions!),
              ),
            ],
            // 分隔线 + 取消按钮
            if (showCancel) ...[
              Container(
                height: 0.5,
                color: AppColors.border,
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  child: Text(
                    cancelLabel,
                    style: TextStyle(
                      fontSize: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
            // 底部缩小的安全距离（替代默认 SafeArea 的全量 bottomInset）
            SizedBox(height: bottomSafeGap),
          ],
        ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<GridAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxFourColumnWidth =
            (constraints.maxWidth - 12 * (4 - 1)) / 4; // spacing=12
        final itemWidth = maxFourColumnWidth.clamp(80.0, 84.0);
        return Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final action in actions)
                SizedBox(
                  width: itemWidth,
                  child: _ActionItem(action: action),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({required this.action});

  final GridAction action;

  @override
  Widget build(BuildContext context) {
    // 10% opacity tint for icon background
    final tintColor = action.color.withAlpha(25);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        action.onPressed();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tintColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              action.icon,
              size: 22,
              color: action.color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            action.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.15,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
