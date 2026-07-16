// Warm Paper Glass — L2 内容卡表面（纸上白卡）
// P1：白 surface + hair 边 + 轻影；页面 canvas 用 AppColors.pageBg。

import 'package:flutter/painting.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';

/// 内容卡 / 分组列表的统一装饰，避免各屏各自写一套 shadow/border。
class AppSurfaces {
  AppSurfaces._();

  /// 极柔 card shadow（对齐暖纸 shadow-sm 意图）
  static List<BoxShadow> get cardShadowSm => const [
        BoxShadow(
          color: Color(0x1A1F2933),
          blurRadius: 14,
          offset: Offset(0, 4),
          spreadRadius: -4,
        ),
      ];

  /// 主内容白卡：列表行卡、消息气泡、设置分组壳。
  static BoxDecoration contentCard({
    Color? color,
    double radius = AppSp.cardRadius,
    bool elevated = true,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? AppColors.border,
        width: AppSp.dividerThickness,
      ),
      boxShadow: elevated ? cardShadowSm : null,
    );
  }

  /// 助手消息：白卡 + 边 + 轻影
  static BoxDecoration assistantBubble({
    double radius = AppSp.chatBubbleRadius,
  }) =>
      contentCard(radius: radius);

  /// 用户消息：accentLight 底 + 轻边（可无影，避免糊）
  static BoxDecoration userBubble({
    double radius = AppSp.chatBubbleRadius,
  }) =>
      contentCard(
        color: AppColors.accentLight,
        radius: radius,
        elevated: false,
        borderColor: AppColors.border,
      );
}
