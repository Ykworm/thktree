import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';

/// iOS Settings 风格的 inset grouped 列表分组容器。
///
/// 类似 iOS 设置中的圆角分组列表，自动处理圆角、背景和分隔线。
///
/// 示例：
/// ```dart
/// ThkListSection(
///   header: '通用',
///   children: [
///     ThkListTile(title: '语言', trailing: Text('中文')),
///     ThkListTile(title: '主题', trailing: Text('默认')),
///   ],
/// )
/// ```
class ThkListSection extends StatelessWidget {
  /// 创建 iOS 风格的分组列表。
  const ThkListSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.margin = const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
    this.additionalDividerMargin = 56,
    this.backgroundColor,
  });

  /// 分组头部文本，通常为大写灰色小字。
  final String? header;

  /// 分组尾部文本。
  final String? footer;

  /// 列表项子组件。
  final List<Widget> children;

  /// 分组外边距。
  final EdgeInsetsDirectional margin;

  /// 分隔线左侧缩进，默认 56pt（对齐标题文本左侧）。
  final double additionalDividerMargin;

  /// 背景色，默认使用系统 grouped 背景。
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    // 分组外区域用 paper；分组本体白卡 + hair + 轻影（Warm Paper L1/L2）
    return CupertinoListSection.insetGrouped(
      backgroundColor: AppColors.pageBg,
      decoration: AppSurfaces.contentCard(radius: AppSp.cardRadius),
      separatorColor: AppColors.border,
      header: header != null
          ? Text(
              header!,
              style: CupertinoTheme.of(context)
                  .textTheme
                  .textStyle
                  .copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
            )
          : null,
      footer: footer != null
          ? Text(
              footer!,
              style: CupertinoTheme.of(context)
                  .textTheme
                  .textStyle
                  .copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
            )
          : null,
      margin: margin,
      additionalDividerMargin: additionalDividerMargin,
      children: children,
    );
  }
}
