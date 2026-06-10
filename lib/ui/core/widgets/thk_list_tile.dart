import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// iOS 原生风格列表项，替代 Material 的 [ListTile]。
///
/// 可选传入 [themeId] 使 leading 图标跟随主题色。
class ThkListTile extends StatelessWidget {
  const ThkListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.additionalInfo,
    this.leading,
    this.trailing = chevron,
    this.onTap,
    this.backgroundColor,
    this.padding,
    this.themeId,
  });

  final String title;
  final String? subtitle;
  final String? additionalInfo;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final String? themeId;

  static const Widget chevron = CupertinoListTileChevron();

  @override
  Widget build(BuildContext context) {
    final iconBg = themeId != null
        ? AppColors.tintForTheme(themeId!)
        : AppColors.accentLight;
    final iconColor = themeId != null
        ? AppColors.colorForTheme(themeId!)
        : AppColors.accent;

    return CupertinoListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      additionalInfo: additionalInfo != null ? Text(additionalInfo!) : null,
      leading: leading != null
          ? Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: iconColor,
                  size: 16,
                ),
                child: Center(child: leading!),
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      backgroundColor: backgroundColor,
      padding: padding,
    );
  }
}
