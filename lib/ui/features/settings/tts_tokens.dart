import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// TTS 模块专有 design tokens。
///
/// 复用的引用 AppColors / AppTheme / AppIcons，本文件只放 TTS 专属值。
/// v1 范围：player 页背景、动效、scroll 浮按钮、settings 列表。
/// v2+ 路线图：见 docs/.../2026-06-05-语音播放功能-design.md#11
class TtsSpacing {
  TtsSpacing._();

  // player 页 — 更紧凑的间距
  static const double playerPagePaddingX = 24;
  static const double playerPagePaddingY = 12;
  static const double playerSectionGap = 20;
  static const double playerTextMaxWidth = 520;
  static const double playerTextLineHeight = 1.7;

  // 底部毛玻璃控制面板
  static const double controlPanelRadius = 20.0;
  static const double controlPanelBlurSigma = 20.0;
  /// 表面 alpha：值越低，BackdropFilter 模糊越明显。0.5 对齐 iOS systemMaterial 视觉。
  static const double controlPanelSurfaceAlpha = 0.35;
  static const double controlPanelPaddingH = 20.0;
  static const double controlPanelPaddingV = 14.0;

  // 速度标签按钮
  static const double speedLabelFontSize = 15.0;
  static const double speedLabelVerticalPadding = 6.0;
  static const double speedLabelHorizontalPadding = 12.0;

  // MessageBubble 按钮
  static const double messageBubbleButtonGap = 12;
  static const double messageBubbleIconSize = 18;

  // settings section
  static const double settingSectionGap = 8;
  static const double voiceRowPaddingX = 16;
  static const double voiceRowPaddingY = 12;
  static const double voiceRowGap = 12;
  static const double voiceRowHeight = 56;
  static const double voiceLeadingIconSize = 28;
}

class TtsDimensions {
  TtsDimensions._();

  // 底部 mini bar 总高（锁死 BackdropFilter saveLayer 范围，避免范围扩张糊整页）
  static const double controlPanelHeight = 68.0;

  // player button — mini bar 尺寸
  static const double playerButtonSize = 40;      // 圆形直径
  static const double playerButtonIconSize = 18;  // 图标尺寸
  static const double playerButtonRadius = 20;    // 圆形 = size/2

  // 进度环（播放中）
  static const double progressRingWidth = 3;
  static const double progressRingGap = 4;        // 环与按钮间距

  // slider
  static const double sliderHeight = 28;
  static const double sliderTrackHeight = 4;

  // pulse dot (Champagne gold 指示)
  static const double pulseDotSize = 8;
  static const double pulseDotGap = 8;

  // 浮按钮
  static const double backToTopSize = 40;
  static const double backToTopIconSize = 18;
}

class TtsMotion {
  TtsMotion._();

  // 通用
  static const Duration transitionButton = Duration(milliseconds: 200);
  static const Duration fadeInText = Duration(milliseconds: 400);
  static const Duration pressDuration = Duration(milliseconds: 100);
  static const double pressScale = 0.97;

  // 波形 — 放大增强视觉存在感
  static const int waveformBarCount = 5;
  static const double waveformBarWidth = 5;
  static const double waveformBarGap = 8;
  static const double waveformBarHeightMin = 8;
  static const double waveformBarHeightMax = 48;
  static const double waveformBarRadius = 3;
  static const Duration waveformTickInterval = Duration(milliseconds: 100);
  static const double waveformTickNoise = 0.35;
  static const double waveformTickSinAmp = 0.65;

  // 脉冲环
  static const int pulseRingCount = 2;
  static const Duration pulseRingDuration = Duration(milliseconds: 1800);
  static const Duration pulseRingStagger = Duration(milliseconds: 900);
  static const double pulseRingStartSize = 1.0;
  static const double pulseRingEndSize = 1.8;
  static const double pulseRingAlphaFrom = 0.35;
  static const double pulseRingAlphaTo = 0.0;
  static const double pulseRingStrokeWidth = 1.5;

  // 背景 ambient
  static const Duration glowShiftDuration = Duration(milliseconds: 2400);
  static const double glowShiftAlphaIdle = 0.04;
  static const double glowShiftAlphaSpeaking = 0.08;
  static const double glowShiftRadius = 0.55;
  static const Alignment glowShiftCenter = Alignment.topCenter;
  static const double perMessageTintAlpha = 0.02;

  // scroll 浮按钮
  static const double scrollShowThreshold = 100;
  static const Duration scrollHideDelay = Duration(milliseconds: 200);
  static const Duration scrollFadeDuration = Duration(milliseconds: 250);
  static const Duration scrollBackToTopDuration = Duration(milliseconds: 300);
  static const Curve scrollBackToTopCurve = Curves.easeOut;
  static const double scrollBackToTopBottom = 220;
  static const double scrollBackToTopRight = 16;

  // 阴影
  static const double backToTopShadowAlpha = 0.04;
  static const double backToTopShadowBlur = 8;
  static const double backToTopShadowOffsetY = 2;
}

class TtsColors {
  TtsColors._();

  // 背景 / 文本（复用 AppColors 别名）
  static Color get playerBg => AppColors.pageBg;
  static Color get playerSurface => AppColors.surface;
  static Color get textPrimary => AppColors.textPrimary;
  static Color get textSecondary => AppColors.textSecondary;
  static Color get textTertiary => AppColors.textTertiary;
  static Color get divider => AppColors.border;

  // 交互态
  static const Color actionActive = CupertinoColors.systemBlue;
  // Slate 500，与 AppColors.textSecondary (light mode) 保持一致
  static const Color actionIdle = Color(0xFF64748B);
  static Color get sliderTrack => AppColors.surfaceMuted;
  static Color get pulseDot => AppColors.champagneGold;
  static Color get checkmark => AppColors.accent;

  // 浮按钮
  static Color get backToTopBg => AppColors.surface;
  static Color get backToTopFg => AppColors.textSecondary;

  // 波形
  static Color get waveformIdle => AppColors.textTertiary;
  static final Color waveformActive = actionActive;
}
