// Design System — 修改配色前请先阅读 docs/visual/design-system.md
// 详细方案: docs/visual/warm-minimal-design-plan.md

import 'package:flutter/painting.dart';

/// 清新多彩色彩系统。
///
/// 设计哲学：
/// - 多彩但和谐：5 色共享相近明度（L≈60-70%），放在一起不冲突
/// - 颜色有归属：每个主题"拥有"一个颜色，书脊线/图标/指示器跟随
/// - 颜色有边界：只出现在结构元素上（书脊线、icon、指示器），不铺满
/// - 中性底座：背景/文字/按钮保持中性（白底 + slate 文字 + indigo 按钮）
class AppColors {
  AppColors._();

  // ── 多彩主题色（清新调色盘，HSL 同明度 L≈60-70%）────────────────
  static const skyBlue       = Color(0xFF38BDF8); // 天蓝 HSL(200,80%,60%)
  static const mint          = Color(0xFF34D399); // 薄荷 HSL(160,60%,55%)
  static const lavender      = Color(0xFFA78BFA); // 薰衣草 HSL(260,70%,70%)
  static const coral         = Color(0xFFFB7185); // 珊瑚 HSL(350,80%,70%)
  static const amber         = Color(0xFFFBBF24); // 琥珀 HSL(35,85%,65%)

  /// 主题色列表，按 index 循环分配给每个主题。
  static const themeColors = [skyBlue, mint, lavender, coral, amber];

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
  static const accentLight    = Color(0xFFEEF2FF); // indigo 10% tint
  static const accentDeep     = Color(0xFF4F46E5); // pressed

  // ── Surface ──────────────────────────────────────────────────────
  static const pageBg         = Color(0xFFF8FAFC); // Slate 50 页面底色
  static const surface        = Color(0xFFFFFFFF); // 纯白 卡片
  static const surfaceMuted   = Color(0xFFF1F5F9); // Slate 100 区块

  // ── Text ─────────────────────────────────────────────────────────
  static const textPrimary    = Color(0xFF1E293B); // Slate 900
  static const textSecondary  = Color(0xFF64748B); // Slate 500
  static const textTertiary   = Color(0xFF94A3B8); // Slate 400

  // ── Structure ────────────────────────────────────────────────────
  static const border         = Color(0xFFE2E8F0); // Slate 200

  // ── Destructive ──────────────────────────────────────────────────
  static const destructive    = Color(0xFFDC2626);
}
