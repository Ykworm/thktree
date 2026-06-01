import 'package:flutter/cupertino.dart';

/// iOS 原生风格列表项，替代 Material 的 [ListTile]。
///
/// 基于 [CupertinoListTile]，提供默认的右箭头、leading icon 背景等 iOS 风格效果。
///
/// 示例：
/// ```dart
/// ThkListTile(
///   title: '账户',
///   subtitle: 'user@email.com',
///   leading: Icon(CupertinoIcons.person),
///   trailing: ThkListTile.chevron,
///   onTap: () => ...,
/// )
/// ```
class ThkListTile extends StatelessWidget {
  /// 创建 iOS 风格列表项。
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
  });

  /// 主标题文本。
  final String title;

  /// 副标题文本。
  final String? subtitle;

  /// 附加信息，显示在标题右侧、trailing 左侧。
  final String? additionalInfo;

  /// 左侧图标或 Widget。
  final Widget? leading;

  /// 右侧尾部 Widget，默认为右箭头 [chevron]。
  final Widget? trailing;

  /// 点击回调。
  final VoidCallback? onTap;

  /// 背景色。
  final Color? backgroundColor;

  /// 内边距。
  final EdgeInsetsGeometry? padding;

  /// 默认右箭头。
  static const Widget chevron = CupertinoListTileChevron();

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      additionalInfo: additionalInfo != null ? Text(additionalInfo!) : null,
      leading: leading != null
          ? Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconTheme(
                data: const IconThemeData(
                  color: CupertinoColors.systemBlue,
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
