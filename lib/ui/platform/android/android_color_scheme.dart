// Android 平台设计令牌落地 —— code-first 单一真源。
//
// 设计约定见 TalkWithClaude/Android-handoff.md §2 / §2.7：
// - 品牌色（accent 蓝 + 5 主题色 + 节点多色）必须继承 ThkTree，不得换色；
// - 基于 AppColors 真源构造自定义 Material 3 ColorScheme（不套用 Material 默认
//   ColorScheme，否则 primary 会变成 Material 紫，覆盖品牌色）；
// - 关闭 Dynamic Color（Monet）：我们提供自己的 light/dark 两套，保证品牌一致；
// - 触摸目标 ≥ 48dp（比通用 token 的 44 更贴合 Android 可达性）。
//
// 本文件是 Flutter 同仓库方案下的"零额外维护"落地：直接复用 app_colors.dart，
// 任何改色都走 AppColors，guard / 同步脚本原样可用。

import 'package:flutter/material.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// 手机 / 平板 large-screen 断点（dp）。≥ 600 走导航栏（rail），否则底部导航。
const double kAndroidTabletBreakpoint = 600.0;

/// Android 触摸目标最小尺寸（dp）。Material 建议 48，比通用 token 的 44 大。
const double kAndroidMinTouchTarget = 48.0;

/// 由 [AppColors] 真源构造 Material 3 [ColorScheme]。
///
/// 不接收 brightness 参数：直接读取 [AppColors.brightness]（已随系统/设置切换），
/// 所有 getter 返回的就是当前亮度下的值，保证与 App 其余部分完全一致。
///
/// 映射原则：
/// - `accent`（雾蓝 paper blue）→ primary
/// - `textPrimary` → onSurface / onBackground
/// - `surface` / `pageBg` → surface / background
/// - `destructive` → error
/// - `border` → outline
/// - `scrim` / `elevationShadow` → scrim / shadow
/// 5 主题色与节点多色作为独立资源保留（Material 无现成"每主题强调色"槽位）。
ColorScheme androidColorScheme() {
  final isDark = AppColors.brightness == Brightness.dark;
  return ColorScheme(
    brightness: AppColors.brightness,
    // 通用交互色：雾蓝 accent
    primary: AppColors.accent,
    onPrimary: AppColors.onSurface, // 白
    primaryContainer: AppColors.accentLight,
    onPrimaryContainer: isDark ? AppColors.accent : AppColors.accentDeep,
    // 次级交互：pressed 深蓝
    secondary: AppColors.accentDeep,
    onSecondary: AppColors.onSurface,
    secondaryContainer: AppColors.accentLight,
    onSecondaryContainer: AppColors.accentDeep,
    // 第三色：复用到主题色盘首色（蓝），保留品牌
    tertiary: AppColors.themeColors[0],
    onTertiary: AppColors.onSurface,
    tertiaryContainer: AppColors.accentLight,
    onTertiaryContainer: AppColors.themeColors[0],
    // 错误 / 破坏
    error: AppColors.destructive,
    onError: AppColors.onSurface,
    errorContainer: AppColors.destructive.withValues(alpha: 0.12),
    onErrorContainer: AppColors.destructive,
    // 中性底座
    // ignore: deprecated_member_use
    background: AppColors.pageBg,
    // ignore: deprecated_member_use
    onBackground: AppColors.textPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    // ignore: deprecated_member_use
    surfaceVariant: AppColors.surfaceMuted,
    onSurfaceVariant: AppColors.textSecondary,
    // 边框 / 阴影 / 遮罩
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    shadow: AppColors.elevationShadow,
    scrim: AppColors.scrim,
    // 反色表面（dark 下用于 snackbar 等）
    inverseSurface: isDark ? AppColors.surface : AppColors.pageBg,
    onInverseSurface: isDark ? AppColors.textPrimary : AppColors.textPrimary,
    inversePrimary: AppColors.accentLight,
    surfaceTint: AppColors.accent,
  );
}

/// 由 [androidColorScheme] 构造完整 [ThemeData]，供 Android 壳包裹 Material 组件。
///
/// 字体沿用 AppTheme 的文本尺度习惯（见 app_theme.dart）；Android 原生默认 Roboto，
/// 此处用 Flutter 默认字体栈（含拉丁 + 中文 fallback），保持跨端文本层级一致。
ThemeData androidTheme() {
  final scheme = androidColorScheme();
  // ThemeData.from(colorScheme:) 默认即 Material 3；底部导航高度 ≥ 48dp 触摸区。
  return ThemeData.from(colorScheme: scheme).copyWith(
    navigationBarTheme: const NavigationBarThemeData(
      height: 80.0,
    ),
  );
}
