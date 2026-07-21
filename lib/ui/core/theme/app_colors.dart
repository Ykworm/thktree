// Design System — 修改配色前请先阅读 docs/_shared/design-system.md
// Warm Paper Glass（安静书房）light 真源：docs/_tmp/warm-paper-tokens.md

import 'dart:ui';
import 'package:flutter/painting.dart';

/// Warm Paper Glass 色彩系统（light 为暖米色；dark 暂保持 slate 深色，另 topic）。
///
/// 设计哲学：
/// - 纸做底座：pageBg / surfaceMuted 暖纸，内容 surface 白卡
/// - 唯一主交互：雾蓝 accent；五色（blue/sage/clay/gold/plum）只作分类与语义
/// - 颜色有边界：结构/壳层用色，不大面积铺霓虹
/// - Lab 装饰色独立，不随书房换肤
class AppColors {
  AppColors._();

  // ── 亮度控制（深色模式）──────────────────────────────────────────
  static Brightness _brightness = Brightness.light;
  static Brightness get brightness => _brightness;
  static void setBrightness(Brightness b) => _brightness = b;

  // ── 五色系统（分类 + 主题 tile；与 accent 同族 blue）──────────────
  /// 主线蓝（与 [accent] 同色）
  static const paletteBlue = Color(0xFF4A7AB5);
  static const paletteSage = Color(0xFF5A9E7F);
  static const paletteClay = Color(0xFFC47856);
  static const paletteGold = Color(0xFFC9A24E);
  static const palettePlum = Color(0xFF8B6AAE);

  // ── 节点配色系统（themes 模块）──────────────────────────────────
  /// 节点卡片：圆圈用五色实色；标题/副标题用 ink 系，白卡上可读。
  static const nodePalettes = [
    NodePalette(
      paletteBlue, // circle: blue
      Color(0xFF1F2933), // title: ink
      Color(0xFF4A5568), // subtitle: ink-2
    ),
    NodePalette(
      paletteSage,
      Color(0xFF1F2933),
      Color(0xFF4A5568),
    ),
    NodePalette(
      paletteClay,
      Color(0xFF1F2933),
      Color(0xFF4A5568),
    ),
    NodePalette(
      paletteGold,
      Color(0xFF1F2933),
      Color(0xFF4A5568),
    ),
    NodePalette(
      palettePlum,
      Color(0xFF1F2933),
      Color(0xFF4A5568),
    ),
  ];

  /// 根据 nodeId 生成稳定的节点配色。
  static NodePalette paletteForNode(String nodeId) {
    return nodePalettes[nodeId.hashCode.abs() % nodePalettes.length];
  }

  // ── 典雅暖调原语（低饱和，供装饰/兼容引用）──────────────────────
  static const champagneGold = Color(0xFFC4A77D); // 香槟金
  static const warmGray = Color(0xFF8E8B82); // 烟灰
  static const dustyRose = Color(0xFFA89090); // 玫瑰灰
  static const sageGray = Color(0xFF8B9080); // 橄榄灰
  static const slateBlue = Color(0xFF6B7B8E); // 深蓝灰

  /// 主题色列表，与 [themeTileColors] / 五色系统对齐。
  static const themeColors = [
    paletteBlue, // blue
    paletteSage, // sage
    paletteClay, // clay
    paletteGold, // gold
    palettePlum, // plum
  ];

  /// 根据 themeId 生成稳定的主题色（hash 取模）。
  static Color colorForTheme(String themeId) {
    return themeColors[themeId.hashCode.abs() % themeColors.length];
  }

  /// 主题色对应的浅 tint（用于背景、leading icon 背景）。
  static Color tintForTheme(String themeId) {
    final c = colorForTheme(themeId);
    return Color.from(
      alpha: 1.0,
      red: c.r + (1.0 - c.r) * 0.85,
      green: c.g + (1.0 - c.g) * 0.85,
      blue: c.b + (1.0 - c.b) * 0.85,
    );
  }

  // ── 主题网格色盘（与 themeColors 同一套五色）────────────────────
  static const themeTileColors = [
    paletteBlue,
    paletteSage,
    paletteClay,
    paletteGold,
    palettePlum,
  ];

  /// 根据 themeId 生成稳定的网格色（hash 取模）。
  static Color themeTileColorFor(String themeId) {
    return themeTileColors[themeId.hashCode.abs() % themeTileColors.length];
  }

  // ── 通用交互色（雾蓝；全局固定）────────────────────────────────
  static const accent = Color(0xFF4A7AB5); // paper blue — 唯一主交互
  static Color get accentLight => _brightness == Brightness.light
      ? const Color(0xFFEDF2F8) // blue soft 叠白 ≈ rgba(74,122,181,0.10)
      : const Color(0xFF1E3A5F); // 深蓝底（dark 另 topic，暂保留）
  static const accentDeep = Color(0xFF3D6A9E); // pressed

  // ── Surface（暖纸 + 白卡）──────────────────────────────────────
  static Color get pageBg => _brightness == Brightness.light
      ? const Color(0xFFFAF9F6) // 高明度雅白 (亮纸色)
      : const Color(0xFF020617); // Slate 950（dark 未改）
  static Color get surface => _brightness == Brightness.light
      ? const Color(0xFFFFFFFF) // 白卡
      : const Color(0xFF0F172A); // Slate 900
  static Color get surfaceMuted => _brightness == Brightness.light
      ? const Color(0xFFF2EFEA) // 柔和暖白灰
      : const Color(0xFF1E293B); // Slate 800

  // ── Text（ink 系）──────────────────────────────────────────────
  static Color get textPrimary => _brightness == Brightness.light
      ? const Color(0xFF1F2933) // ink
      : const Color(0xFFF1F5F9);
  static Color get textSecondary => _brightness == Brightness.light
      ? const Color(0xFF4A5568) // ink-2
      : const Color(0xFF94A3B8);
  static Color get textTertiary => _brightness == Brightness.light
      ? const Color(0xFF8492A6) // ink-3
      : const Color(0xFF64748B);
  /// ink-4：弱标签 / 禁用装饰（勿作正文）
  static Color get textQuaternary => _brightness == Brightness.light
      ? const Color(0xFFB8C2CC)
      : const Color(0xFF475569);

  // ── Structure ────────────────────────────────────────────────────
  /// 暖 hair 实色近似（控件更稳；语义对齐 rgba(31,41,51,0.07)）
  static Color get border => _brightness == Brightness.light
      ? const Color(0xFFE8E4DC)
      : const Color(0xFF334155);
  /// hair-2 近似
  static Color get borderStrong => _brightness == Brightness.light
      ? const Color(0xFFD9D3C8)
      : const Color(0xFF475569);

  // ── Destructive / Semantic ───────────────────────────────────────
  static const destructive = Color(0xFFDC2626); // 硬红保留
  static const success = Color(0xFF5A9E7F); // sage
  static const onSurface = Color(0xFFFFFFFF);

  /// 草稿 / 软警告（非硬删）
  static const clay = paletteClay;
  /// pin / 附属
  static const gold = paletteGold;
  /// 收集 / 合并 / 多选
  static const plum = palettePlum;

  // ── Chat / Sheet overlay ────────────────────────────────────────
  static const scrim = Color(0x80000000);

  /// 浮层阴影：暖 ink 系 ~10%
  static Color get elevationShadow => const Color(0x1A1F2933);

  // ── 中性原语 ─────────────────────────────────────────────────────
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Color(0x00000000);

  static const scrimStrong = Color(0xF0000000);
  static const scrimMid = Color(0x61000000);
  static const scrimSoft = Color(0x0D000000);

  // ── Lab / 波形（豁免书房换肤）────────────────────────────────────
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

  /// 问题来源标签（accent 50% 透明）
  static const questionSourceTag = Color(0x804A7AB5);
}

/// 节点卡片配色方案（圆圈 + 标题 + 副标题）。
class NodePalette {
  const NodePalette(this.circle, this.title, this.subtitle);
  final Color circle;
  final Color title;
  final Color subtitle;
}
