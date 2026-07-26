// Design System — 修改配色前请先阅读 docs/_shared/design-system.md
// Warm Paper Glass（安静书房）light 真源：docs/_tmp/warm-paper-tokens.md

import 'dart:ui';

import 'package:flutter/painting.dart';

import 'app_palette_tokens.dart';

export 'app_palette_tokens.dart' show AppColorPalette, NodePalette;

/// 语义色系统：light 下用户可选 warmPaper / morandi；dark 下统一 slate。
///
/// 设计哲学：
/// - 纸做底座：pageBg / surfaceMuted 暖纸，内容 surface 白卡
/// - 唯一主交互：雾蓝 accent；五色（blue/sage/clay/gold/plum）只作分类与语义
/// - 颜色有边界：结构/壳层用色，不大面积铺霓虹
/// - Lab 装饰色独立，不随书房换肤
class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.light;
  static Brightness get brightness => _brightness;
  static void setBrightness(Brightness b) => _brightness = b;

  static AppColorPalette _palette = AppColorPalette.warmPaper;
  static AppColorPalette get palette => _palette;
  static void setPalette(AppColorPalette p) => _palette = p;

  static AppPaletteTokens get _current => _brightness == Brightness.dark
      ? AppThemeRegistry.slate
      : AppThemeRegistry.of(_palette);

  static Color get paletteBlue => _current.paletteBlue;
  static Color get paletteSage => _current.paletteSage;
  static Color get paletteClay => _current.paletteClay;
  static Color get paletteGold => _current.paletteGold;
  static Color get palettePlum => _current.palettePlum;

  static List<NodePalette> get nodePalettes => _current.nodePalettes;

  static NodePalette paletteForNode(String nodeId) {
    return nodePalettes[nodeId.hashCode.abs() % nodePalettes.length];
  }

  static Color get champagneGold => _current.champagneGold;
  static Color get warmGray => _current.warmGray;
  static Color get dustyRose => _current.dustyRose;
  static Color get sageGray => _current.sageGray;
  static Color get slateBlue => _current.slateBlue;

  static Color get matteGoldLight => _current.matteGoldLight;
  static Color get matteGoldBg => _current.matteGoldBg;
  static Color get matteGoldBorder => _current.matteGoldBorder;
  static Color get textMatteGoldDark => _current.textMatteGoldDark;
  static Color get matteGold => _current.matteGold;

  static const labCoolBg = Color(0xFFF2F4F7);

  static List<Color> get themeColors => _current.themeColors;

  static Color colorForTheme(String themeId) {
    return themeColors[themeId.hashCode.abs() % themeColors.length];
  }

  static Color tintForTheme(String themeId) {
    final c = colorForTheme(themeId);
    return Color.from(
      alpha: 1.0,
      red: c.r + (1.0 - c.r) * 0.85,
      green: c.g + (1.0 - c.g) * 0.85,
      blue: c.b + (1.0 - c.b) * 0.85,
    );
  }

  static List<Color> get themeTileColors => _current.themeTileColors;

  static Color themeTileColorFor(String themeId) {
    return themeTileColors[themeId.hashCode.abs() % themeTileColors.length];
  }

  static Color get accent => _current.accent;
  static Color get accentLight => _current.accentLight;
  static Color get accentDeep => _current.accentDeep;

  static Color get pageBg => _current.pageBg;
  static Color get surface => _current.surface;
  static Color get surfaceMuted => _current.surfaceMuted;

  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textTertiary => _current.textTertiary;
  static Color get textQuaternary => _current.textQuaternary;

  static Color get border => _current.border;
  static Color get borderStrong => _current.borderStrong;

  static const destructive = Color(0xFFDC2626);
  static Color get success => _current.success;
  static const onSurface = Color(0xFFFFFFFF);

  static Color get clay => _current.clay;
  static Color get gold => _current.gold;
  static Color get plum => _current.plum;

  static const scrim = Color(0x80000000);

  static Color get elevationShadow => _current.elevationShadow;

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Color(0x00000000);

  static const scrimStrong = Color(0xF0000000);
  static const scrimMid = Color(0x61000000);
  static const scrimSoft = Color(0x0D000000);

  static const labBg = Color(0xFF0F1035);
  static const labAccentBlue = Color(0xFF3B82F6);
  static const labAccentOrange = Color(0xFFF97316);
  static const labAccentPurple = Color(0xFFA855F7);
  static const waveTeal = Color(0xFF5AC8FA);
  static const waveOrange = Color(0xFFFF9500);
  static const wavePurple = Color(0xFFAF52DE);

  static Color get thinkingBg => surfaceMuted;
  static Color get markdownCodeBg => pageBg;
  static Color get userBubbleBg => accentLight;
  static Color get assistantBubbleBg => surface;
  static Color get assistantBubbleBorder => border;

  static Color get questionSourceTag => _current.questionSourceTag;

  static Color get glassFill => _current.glassFill;
  static Color get glassFillOpaque => _current.glassFillOpaque;
}
