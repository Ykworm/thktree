import 'package:flutter/widgets.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';

/// 页级静态 soft radial 氛围光（P3 Warm Paper）。
///
/// - 右上 blue ≤5%、左下 sage ≤5%
/// - 无动画；dark / [AppAtmosphere.enabled]==false 时透传 child
/// - 禁止用在列表 cell / Chat 长读区
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

    final size = AppAtmosphere.blobSize;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 忽略指针：只装饰，不挡列表/点按
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: -size * 0.28,
                right: -size * 0.22,
                width: size,
                height: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppAtmosphere.blueGlow,
                        AppAtmosphere.blueGlow.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -size * 0.32,
                left: -size * 0.26,
                width: size * 1.05,
                height: size * 1.05,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppAtmosphere.sageGlow,
                        AppAtmosphere.sageGlow.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
