// Design System — 修改配色前请先阅读 docs/visual/design-system.md
// 详细方案: docs/visual/warm-minimal-design-plan.md

import 'dart:ui';
import 'package:flutter/painting.dart';

/// 典雅黑金色彩系统。
///
/// 设计哲学：
/// - 低调奢华：哑光香槟 + 暖灰调，不闪亮、不张扬
/// - 颜色有归属：每个主题"拥有"一个颜色，图标/指示器跟随
/// - 颜色有边界：只出现在结构元素上（icon、指示器），不铺满
/// - 中性底座：背景/文字/按钮保持中性（白底 + slate 文字 + indigo 按钮）
class AppColors {
  AppColors._();

  // ── 亮度控制（深色模式）──────────────────────────────────────────
  static Brightness _brightness = Brightness.light;
  static Brightness get brightness => _brightness;
  static void setBrightness(Brightness b) => _brightness = b;

  // ── 节点配色系统（themes 模块）──────────────────────────────────
  /// 节点卡片配色：圆圈 + 标题 + 副标题，典雅黑金色调。
  /// 与主题色完全解耦，基于 nodeId hash 稳定分配。
  static const nodePalettes = [
    NodePalette(
      Color(0xFFB8A07A), // circle: 暖金
      Color(0xFF4A4A4A), // title: 深灰
      Color(0xFF8B7355), // subtitle: 棕灰
    ),
    NodePalette(
      Color(0xFF7A8B7A), // circle: 灰绿
      Color(0xFF3D4A3D), // title: 深绿灰
      Color(0xFF6B7B6B), // subtitle: 中绿灰
    ),
    NodePalette(
      Color(0xFF8B7A8B), // circle: 灰紫
      Color(0xFF4A3D4A), // title: 深紫灰
      Color(0xFF7B6B7B), // subtitle: 中紫灰
    ),
    NodePalette(
      Color(0xFF8B7A7A), // circle: 灰粉
      Color(0xFF4A3D3D), // title: 深粉灰
      Color(0xFF7B6B6B), // subtitle: 中粉灰
    ),
    NodePalette(
      Color(0xFF7A7A8B), // circle: 灰蓝
      Color(0xFF3D3D4A), // title: 深蓝灰
      Color(0xFF6B6B7B), // subtitle: 中蓝灰
    ),
  ];

  /// 根据 nodeId 生成稳定的节点配色。
  static NodePalette paletteForNode(String nodeId) {
    return nodePalettes[nodeId.hashCode.abs() % nodePalettes.length];
  }

  // ── 典雅黑金色调（低饱和度，HSL 明度 L≈50-65%）────────────────
  static const champagneGold  = Color(0xFFC4A77D); // 香槟金 HSL(36,33%,63%)
  static const warmGray        = Color(0xFF8E8B82); // 烟灰 HSL(42,4%,53%)
  static const dustyRose       = Color(0xFFA89090); // 玫瑰灰 HSL(0,10%,61%)
  static const sageGray        = Color(0xFF8B9080); // 橄榄灰 HSL(80,7%,53%)
  static const slateBlue       = Color(0xFF6B7B8E); // 深蓝灰 HSL(210,14%,49%)

  /// 主题色列表，按 index 循环分配给每个主题。
  static const themeColors = [champagneGold, warmGray, dustyRose, sageGray, slateBlue];

  /// 根据 themeId 生成稳定的主题色（hash 取模）。
  static Color colorForTheme(String themeId) {
    return themeColors[themeId.hashCode.abs() % themeColors.length];
  }

  /// 主题色对应的 10% tint（用于背景、leading icon 背景）。
  static Color tintForTheme(String themeId) {
    final c = colorForTheme(themeId);
    return Color.from(
      alpha: 1.0,
      red: c.r + (1.0 - c.r) * 0.85,
      green: c.g + (1.0 - c.g) * 0.85,
      blue: c.b + (1.0 - c.b) * 0.85,
    );
  }

  // ── 通用按钮色（全局固定，不随主题变化）─────────────────────────
  static const accent         = Color(0xFF6366F1); // Indigo — 通用交互色
  static Color get accentLight => _brightness == Brightness.light
      ? const Color(0xFFEEF2FF) // indigo 10% tint
      : const Color(0xFF1E1B4B); // Indigo 950
  static const accentDeep     = Color(0xFF4F46E5); // pressed

  // ── Surface ──────────────────────────────────────────────────────
  static Color get pageBg => _brightness == Brightness.light
      ? const Color(0xFFF8FAFC) // Slate 50
      : const Color(0xFF020617); // Slate 950
  static Color get surface => _brightness == Brightness.light
      ? const Color(0xFFFFFFFF) // 纯白
      : const Color(0xFF0F172A); // Slate 900
  static Color get surfaceMuted => _brightness == Brightness.light
      ? const Color(0xFFF1F5F9) // Slate 100
      : const Color(0xFF1E293B); // Slate 800

  // ── Text ─────────────────────────────────────────────────────────
  static Color get textPrimary => _brightness == Brightness.light
      ? const Color(0xFF1E293B) // Slate 900
      : const Color(0xFFF1F5F9); // Slate 100
  static Color get textSecondary => _brightness == Brightness.light
      ? const Color(0xFF64748B) // Slate 500
      : const Color(0xFF94A3B8); // Slate 400
  static Color get textTertiary => _brightness == Brightness.light
      ? const Color(0xFF94A3B8) // Slate 400
      : const Color(0xFF64748B); // Slate 500

  // ── Structure ────────────────────────────────────────────────────
  static Color get border => _brightness == Brightness.light
      ? const Color(0xFFE2E8F0) // Slate 200
      : const Color(0xFF334155); // Slate 700

  // ── Destructive ──────────────────────────────────────────────────
  static const destructive    = Color(0xFFDC2626);

  // ── Semantic ─────────────────────────────────────────────────────
  static const success       = Color(0xFF34C759); // systemGreen
  static const onSurface     = Color(0xFFFFFFFF); // 卡片上前景色（白色）
}

/// 节点卡片配色方案（圆圈 + 标题 + 副标题）。
class NodePalette {
  const NodePalette(this.circle, this.title, this.subtitle);
  final Color circle;
  final Color title;
  final Color subtitle;
}
