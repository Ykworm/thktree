import 'package:flutter/widgets.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';

/// 页级静态 soft radial 氛围光（P3 Warm Paper）。
///
/// - 右上 blue、左下 sage；核心可见、边缘淡出
/// - 无动画；dark / [AppAtmosphere.enabled]==false 时透传 child
/// - 禁止用在列表 cell / Chat 长读区
///
/// 看哪里：主题/搜索页的 **米色纸缝**（白卡之间、左右边距、空态大片底），
/// 不是白卡表面本身。
class ThkPageAtmosphere extends StatelessWidget {
  const ThkPageAtmosphere({
    super.key,
    required this.child,
    this.enabled,
  });

  final Widget child;

  /// null → 跟随 [AppAtmosphere.enabled]
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final on = enabled ?? AppAtmosphere.enabled;
    if (!on || AppColors.brightness != Brightness.light) {
      return child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(child: _AtmospherePaint()),
        child,
      ],
    );
  }
}

/// 全页铺两团径向光（CustomPainter 比 Positioned 圆更稳、落点更好控）。
class _AtmospherePaint extends StatelessWidget {
  const _AtmospherePaint();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _AtmospherePainter(),
      child: SizedBox.expand(),
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final blue = AppAtmosphere.blueGlow;
    final sage = AppAtmosphere.sageGlow;
    // 直径随屏宽，小屏也够大
    final r = (size.shortestSide * 0.72).clamp(280.0, 520.0);

    // 右上 blue
    _blob(
      canvas,
      center: Offset(size.width * 0.88, size.height * 0.12),
      radius: r,
      color: blue,
    );
    // 左下 sage
    _blob(
      canvas,
      center: Offset(size.width * 0.12, size.height * 0.82),
      radius: r * 1.05,
      color: sage,
    );
  }

  void _blob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          color.withValues(alpha: color.a * 0.45),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter oldDelegate) => false;
}
