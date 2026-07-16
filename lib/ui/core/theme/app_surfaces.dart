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

/// L3 壳层玻璃 token（tab / sheet 等）。勿污染 [AppColors.surface]。
///
/// 注意：底部 tab 必须叠在内容 **上方**（Stack），Column 并排无法磨到内容。
/// 顶栏 [navBarBackground] 保持不透明，避免 body 钻进半透 nav 把面包屑等顶内容挡住。
class AppGlass {
  AppGlass._();

  /// 暖白半透 ~55%（blur 路径；再高会像实心白块）
  static const fill = Color(0x8CFFFFFF);

  /// Android / 降级：不透明 paper-warm
  static const fillOpaque = Color(0xFFF3EFE8);

  /// 磨砂强度（仅 blur 路径；列表 cell 禁止使用）
  static const blurSigma = 20.0;

  /// 是否启用 BackdropFilter（Android 默认关）
  static bool get useBlur {
    if (Platform.isAndroid) return false;
    return true;
  }

  /// 当前平台壳层填充色（tab / sheet）
  static Color get chromeFill => useBlur ? fill : fillOpaque;

  /// 顶栏：不透明 surface，避免半透 nav 导致 body 上顶、面包屑被挡
  static Color get navBarBackground => AppColors.surface;

  /// tab 内容区高度（不含 home indicator）
  static const tabBarContentHeight = 6.0 + 49.0 + 2.0;
}

/// L0 页级氛围光 token（P3）。仅主题列表 / 搜索等静页；Chat/笔记/设置默认不用。
///
/// 静态 soft radial，非 Aurora 动画 mesh。改 [enabled] 可整段关掉。
/// 剂量：克制可见——比「看不见」略强，比「海报光」弱一截。
class AppAtmosphere {
  AppAtmosphere._();

  /// 总开关（无设置页项；需要时可 false）
  static bool enabled = true;

  /// 自 title bar 释出的 blue（核心约 10%，径向淡出）
  static Color get blueGlow =>
      AppColors.accent.withValues(alpha: 0.10);

  /// 左下 sage（约 8%，更弱，只托底）
  static Color get sageGlow =>
      AppColors.paletteSage.withValues(alpha: 0.08);

  /// 光斑参考直径（painter 会按屏宽再 clamp）
  static const blobSize = 380.0;
}
