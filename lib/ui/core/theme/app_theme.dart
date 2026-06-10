// Design System — 修改字体/主题配置前请先阅读 docs/visual/design-system.md

import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// 清新多彩主题配置
class AppTheme {
  AppTheme._();

  static const _fontFamily = '.SF Pro Text';
  static const _fontFamilyFallback = ['PingFang SC'];

  static CupertinoThemeData get light => const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.accent,
        scaffoldBackgroundColor: AppColors.pageBg,
        barBackgroundColor: AppColors.surface,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.accent,
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFamilyFallback,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
            color: AppColors.textPrimary,
          ),
        ),
      );

  // ── Serif display styles (Cormorant Garamond) ────────────────────

  static TextStyle get largeTitle => const TextStyle(
        fontFamily: 'Cormorant Garamond',
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 34,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.textPrimary,
      );

  static TextStyle get displayTitle => const TextStyle(
        fontFamily: 'Cormorant Garamond',
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.textPrimary,
      );

  // ── SF Pro text tokens ───────────────────────────────────────────

  static TextStyle get title1 => const TextStyle(
        fontFamily: '.SF Pro Display',
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.36,
        color: AppColors.textPrimary,
      );

  static TextStyle get headline => const TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => const TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.41,
        color: AppColors.textPrimary,
      );

  static TextStyle get callout => const TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.32,
        color: AppColors.textPrimary,
      );

  static TextStyle get subhead => const TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.24,
        color: AppColors.textPrimary,
      );

  static TextStyle get footnote => const TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.08,
        color: AppColors.textPrimary,
      );

  static TextStyle get caption1 => const TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.textPrimary,
      );
}
