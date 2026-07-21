import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';

/// 壳层轻玻璃条：半透 + 可选 BackdropFilter，固定在 chrome 区域。
///
/// - **iOS 等**：blur + [AppGlass.fill]
/// - **Android**：不透明 [AppGlass.fillOpaque]（无 blur，防脏与性能）
/// - **禁止**用于列表 cell / 长文气泡
///
/// 外层用 [ClipRect] / [ClipRRect] 锁 blur saveLayer 范围。
class ThkGlassBar extends StatelessWidget {
  const ThkGlassBar({
    super.key,
    required this.child,
    this.borderRadius,
    this.border,
    this.padding,
    this.width,
    this.height,
    this.color,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  /// 填充色覆盖：默认 [AppGlass.chromeFill]（iOS 半透 + blur）。
  /// 深色 barrier 上的 sheet 应传不透明色（如 [AppGlass.fillOpaque]），
  /// 半透白叠深色 scrim 会发灰蓝。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final blur = AppGlass.useBlur;
    final decoration = BoxDecoration(
      color: color ?? AppGlass.chromeFill,
      borderRadius: borderRadius,
      border: border ??
          Border(
            top: BorderSide(
              color: AppColors.border,
              width: AppSp.dividerThickness,
            ),
          ),
    );

    Widget body = DecoratedBox(
      decoration: decoration,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );

    if (width != null || height != null) {
      body = SizedBox(width: width, height: height, child: body);
    }

    if (!blur) {
      if (borderRadius != null) {
        return ClipRRect(borderRadius: borderRadius!, child: body);
      }
      return body;
    }

    final filter = ImageFilter.blur(
      sigmaX: AppGlass.blurSigma,
      sigmaY: AppGlass.blurSigma,
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: BackdropFilter(filter: filter, child: body),
      );
    }

    return ClipRect(
      child: BackdropFilter(filter: filter, child: body),
    );
  }
}
