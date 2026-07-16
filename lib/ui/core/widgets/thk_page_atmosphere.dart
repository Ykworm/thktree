import 'package:flutter/widgets.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';

/// 页级静态 soft radial 氛围光（P3 Warm Paper）。
///
/// - **蓝光**：从 title bar 一带向下/向外释放（不是右上角团光）
/// - **绿光**：左下极淡托底
/// - 无动画；dark / [AppAtmosphere.enabled]==false 时透传 child
/// - 禁止用在列表 cell / Chat 长读区
///
/// 看哪里：主题/搜索的 **米色纸缝**（卡间、边距、空态），不是白卡表面。
class ThkPageAtmosphere extends StatelessWidget {
  const ThkPageAtmosphere({
    super.key,
    required this.child,
    this.enabled,
    /// 状态栏以下到 title 内容底的额外高度。
    /// large title 页传更大（如 96），普通 nav 默认 44。
    this.titleContentHeight = 44,
  });

  final Widget child;

  /// null → 跟随 [AppAtmosphere.enabled]
  final bool? enabled;

  /// 顶栏内容区高度（不含 status bar）；蓝光圆心贴其下缘中线。
  final double titleContentHeight;

  @override
  Widget build(BuildContext context) {
    final on = enabled ?? AppAtmosphere.enabled;
    if (!on || AppColors.brightness != Brightness.light) {
      return child;
    }

    // 蓝光从 title bar 下缘中线释放，再向下铺到纸底（nav 不透明时，可见的是「从顶栏洒出」的一截）
    final titleBarBottom =
        MediaQuery.paddingOf(context).top + titleContentHeight;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: CustomPaint(
            painter: _AtmospherePainter(titleBarBottom: titleBarBottom),
            child: const SizedBox.expand(),
          ),
        ),
        child,
      ],
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter({required this.titleBarBottom});

  /// 蓝光圆心贴在 title bar 下缘中线附近，再向下铺开
  final double titleBarBottom;

  @override
  void paint(Canvas canvas, Size size) {
    final blue = AppAtmosphere.blueGlow;
    final sage = AppAtmosphere.sageGlow;

    // 蓝：自 title bar 释放，横向铺满感，纵向只落到上半屏
    final blueRadius = (size.width * 0.78).clamp(260.0, 440.0);
    _blob(
      canvas,
      center: Offset(size.width * 0.5, titleBarBottom),
      radius: blueRadius,
      color: blue,
      // 略扁：更像从顶栏「洒」下来，而不是正圆角斑
      scaleY: 1.15,
    );

    // 绿：左下托底，更小更淡
    final sageRadius = (size.shortestSide * 0.55).clamp(220.0, 360.0);
    _blob(
      canvas,
      center: Offset(size.width * 0.08, size.height * 0.92),
      radius: sageRadius,
      color: sage,
    );
  }

  void _blob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    double scaleY = 1.0,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, scaleY);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          color.withValues(alpha: color.a * 0.4),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.38, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawCircle(Offset.zero, radius, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter oldDelegate) =>
      oldDelegate.titleBarBottom != titleBarBottom;
}
