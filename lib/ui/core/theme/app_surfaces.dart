// Warm Paper Glass — L2 内容卡 + L3 壳层玻璃 token
// P1：白 surface + hair 边 + 轻影；页面 canvas 用 AppColors.pageBg。
// P2：壳层克制玻璃（半透 + blur）；Android / 无障碍降级为不透明 paper。

import 'dart:io' show Platform;

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

/// L3 壳层玻璃 token（nav / tab / sheet）。勿污染 [AppColors.surface]。
class AppGlass {
  AppGlass._();

  /// 暖白半透 ~65%（iOS blur 路径 fill）
  static const fill = Color(0xA6FFFFFF);

  /// Android / 降级：不透明 paper-warm，避免低 alpha 脏边
  static const fillOpaque = Color(0xFFF3EFE8);

  /// 磨砂强度（仅 iOS 等 blur 路径；列表 cell 禁止使用）
  static const blurSigma = 14.0;

  /// 是否启用 BackdropFilter（Android 默认关，走不透明纸）
  static bool get useBlur {
    if (Platform.isAndroid) return false;
    return true;
  }

  /// 当前平台壳层填充色
  static Color get chromeFill => useBlur ? fill : fillOpaque;

  /// Cupertino 导航栏背景：半透时由系统/Flutter 做磨砂
  static Color get navBarBackground => chromeFill;
}
