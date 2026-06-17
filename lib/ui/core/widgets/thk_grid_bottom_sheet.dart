import 'package:flutter/material.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// 网格底栏操作项。
class GridAction {
  const GridAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

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
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SheetContent(
        actions: actions,
        destructiveActions: destructiveActions,
        cancelLabel: cancelLabel,
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({
    required this.actions,
    this.destructiveActions,
    required this.cancelLabel,
  });

  final List<GridAction> actions;
  final List<GridAction>? destructiveActions;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 主操作区
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: _ActionGrid(actions: actions),
            ),
            // destructive 操作区
            if (destructiveActions != null && destructiveActions!.isNotEmpty) ...[
              Container(
                height: 8,
                color: AppColors.surfaceMuted,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _ActionGrid(actions: destructiveActions!),
              ),
            ],
            // 分隔线
            Container(
              height: 0.5,
              color: AppColors.border,
            ),
            // 取消按钮
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
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<GridAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: actions.map((action) => _ActionItem(action: action)).toList(),
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
            style: TextStyle(
              fontSize: 11,
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
