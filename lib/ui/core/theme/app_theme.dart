// Design System — 修改字体/主题配置前请先阅读 docs/visual/design-system.md

import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';

/// 典雅黑金主题配置
class AppTheme {
  AppTheme._();

  static const _fontFamily = '.SF Pro Text';
  static const _fontFamilyFallback = ['PingFang SC'];

  static CupertinoThemeData get light => CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.accent,
        scaffoldBackgroundColor: AppColors.pageBg,
        // 壳层玻璃（半透 / Android 不透明 paper）
        barBackgroundColor: AppGlass.navBarBackground,
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

  static CupertinoThemeData get dark => CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.accent,
        scaffoldBackgroundColor: AppColors.pageBg,
        barBackgroundColor: AppGlass.navBarBackground,
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

  static TextStyle get largeTitle => TextStyle(
        fontFamily: 'Cormorant Garamond',
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 34,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.textPrimary,
      );

  static TextStyle get displayTitle => TextStyle(
        fontFamily: 'Cormorant Garamond',
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.textPrimary,
      );

  // ── SF Pro text tokens ───────────────────────────────────────────

  static TextStyle get title1 => TextStyle(
        fontFamily: '.SF Pro Display',
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.36,
        color: AppColors.textPrimary,
      );

  static TextStyle get headline => TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.41,
        color: AppColors.textPrimary,
      );

  static TextStyle get callout => TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.32,
        color: AppColors.textPrimary,
      );

  static TextStyle get subhead => TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.24,
        color: AppColors.textPrimary,
      );

  static TextStyle get footnote => TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.08,
        color: AppColors.textPrimary,
      );

  static TextStyle get caption1 => TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.textPrimary,
      );
}
