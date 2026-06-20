import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

class ThkFillCardPageBody extends StatelessWidget {
  const ThkFillCardPageBody({
    super.key,
    required this.child,
    this.topSpacing = 12,
    this.horizontalPadding = 0,
    this.bottomPadding = 0,
    this.borderRadius = 0,
  });

  final Widget child;
  final double topSpacing;
  final double horizontalPadding;
  final double bottomPadding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: topSpacing),
        Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              horizontalPadding,
              0,
              horizontalPadding,
              bottomPadding,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
