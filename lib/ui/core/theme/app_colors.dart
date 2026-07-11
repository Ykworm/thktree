// Design System — 修改配色前请先阅读 docs/_shared/design-system.md
// 详细方案: docs/visual/warm-minimal-design-plan.md

import 'dart:ui';
import 'package:flutter/painting.dart';

/// 典雅黑金色彩系统。
///
/// 设计哲学：
/// - 低调奢华：哑光香槟 + 暖灰调，不闪亮、不张扬
/// - 颜色有归属：每个主题"拥有"一个颜色，图标/指示器跟随
/// - 颜色有边界：只出现在结构元素上（icon、指示器），不铺满
/// - 中性底座：背景/文字保持中性，交互色用现代蓝（白底 + slate 文字 + 蓝按钮）
class AppColors {
  AppColors._();

  // ── 亮度控制（深色模式）──────────────────────────────────────────
  static Brightness _brightness = Brightness.light;
  static Brightness get brightness => _brightness;
  static void setBrightness(Brightness b) => _brightness = b;

  // ── 节点配色系统（themes 模块）──────────────────────────────────
  /// 节点卡片配色：圆圈 + 标题 + 副标题。
  /// 每套色相差距 ≥ 40°，饱和度 30–45%，白底一眼可辨。
  /// 与全局 accent 金黄协调，基于 nodeId hash 稳定分配。
  static const nodePalettes = [
    NodePalette(
      Color(0xFFD4A853), // circle: 暖琥珀 — 主锚色，与 accent 同族
      Color(0xFF3A3428), // title: 深棕灰
      Color(0xFF997A42), // subtitle: 琥珀棕
    ),
    NodePalette(
      Color(0xFF4BA3A0), // circle: 青碧 — 冷调对比，清新
      Color(0xFF283A39), // title: 深青灰
      Color(0xFF5B8B89), // subtitle: 中青灰
    ),
    NodePalette(
      Color(0xFFC87A8F), // circle: 玫柔 — 暖粉，柔和区分
      Color(0xFF3A2832), // title: 深玫灰
      Color(0xFF9B6B7A), // subtitle: 中玫灰
    ),
    NodePalette(
      Color(0xFF7B8BC4), // circle: 靛蓝 — 冷静桥色
      Color(0xFF282E3A), // title: 深靛灰
      Color(0xFF6B7BA0), // subtitle: 中靛灰
    ),
    NodePalette(
      Color(0xFF7A9B5E), // circle: 橄榄 — 自然中性
      Color(0xFF2E3A28), // title: 深橄榄灰
      Color(0xFF6B8B55), // subtitle: 中橄榄灰
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
  /// 与 themeTileColors 统一为 Lab 式现代鲜明色，确保详情页 header 与列表卡片同色相。
  static const themeColors = [
    Color(0xFF3B82F6), // 蓝
    Color(0xFFF97316), // 橙
    Color(0xFFA855F7), // 紫
    Color(0xFF06B6D4), // 青
    Color(0xFF22C55E), // 绿
  ];

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

  // ── 主题网格精选色盘（Lab 式现代鲜明色，避开 nodePalettes 的泥灰）──
  /// 用于 themes 列表网格卡片的图标徽章，按 themeId 稳定分配。
  static const themeTileColors = [
    Color(0xFF3B82F6), // 蓝
    Color(0xFFF97316), // 橙
    Color(0xFFA855F7), // 紫
    Color(0xFF06B6D4), // 青
    Color(0xFF22C55E), // 绿
  ];

  /// 根据 themeId 生成稳定的网格色（hash 取模）。
  static Color themeTileColorFor(String themeId) {
    return themeTileColors[themeId.hashCode.abs() % themeTileColors.length];
  }

  // ── 通用按钮色（全局固定，不随主题变化）─────────────────────────
  static const accent         = Color(0xFF3B82F6); // 现代蓝 — 通用交互色（Lab 同款，白底对比度好）
  static Color get accentLight => _brightness == Brightness.light
      ? const Color(0xFFEBF2FE) // 浅蓝 tint
      : const Color(0xFF1E3A5F); // 深蓝底
  static const accentDeep     = Color(0xFF2563EB); // pressed 深蓝

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

  // ── Chat / Sheet overlay ────────────────────────────────────────
  /// Sheet 遮罩层（50% 透明黑）
  static const scrim = Color(0x80000000);

  /// 浮层阴影色（12% 透明黑）
  static Color get elevationShadow =>
      const Color(0x1F000000);

  // ── 中性原语（亮度无关，供裸 CupertinoColors.white/black/transparent 收口）──
  static const white       = Color(0xFFFFFFFF);
  static const black       = Color(0xFF000000);
  static const transparent = Color(0x00000000);

  /// 遮罩层变体（黑底不同透明度，替代裸 Color(0x…)）
  static const scrimStrong = Color(0xF0000000); // ~94%
  static const scrimMid    = Color(0x61000000); // ~38%
  static const scrimSoft   = Color(0x0D000000); // ~5%（0x0D / 0x0F 合并）

  // ── 装饰性特征色（lab / 波形指示器，非核心系统色，供裸色收口）────
  static const labBg           = Color(0xFF0F1035);
  static const labAccentBlue   = Color(0xFF3B82F6);
  static const labAccentOrange = Color(0xFFF97316);
  static const labAccentPurple = Color(0xFFA855F7);
  static const waveTeal    = Color(0xFF5AC8FA);
  static const waveOrange  = Color(0xFFFF9500);
  static const wavePurple  = Color(0xFFAF52DE);

  /// 思考过程区块背景（light = surfaceMuted, dark 待补）
  static Color get thinkingBg => surfaceMuted;

  /// Markdown 代码块背景（light = pageBg, dark 待补）
  static Color get markdownCodeBg => pageBg;

  /// 用户消息气泡背景（light = accentLight, dark 待补）
  static Color get userBubbleBg => accentLight;

  /// 助手消息气泡背景
  static Color get assistantBubbleBg => surface;

  /// 助手消息气泡边框（0.5px）
  static Color get assistantBubbleBorder => border;

  /// 问题来源标签色（accent 50% 透明）
  static const questionSourceTag = Color(0x803B82F6);
}

/// 节点卡片配色方案（圆圈 + 标题 + 副标题）。
class NodePalette {
  const NodePalette(this.circle, this.title, this.subtitle);
  final Color circle;
  final Color title;
  final Color subtitle;
}
