import 'package:flutter/cupertino.dart';

/// iOS 原生主题配置
class AppTheme {
  AppTheme._();

  static const _fontFamily = '.SF Pro Text';
  static const _fontFamilyFallback = ['PingFang SC'];

  static CupertinoThemeData get light => const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
        barBackgroundColor: CupertinoColors.systemBackground,
        textTheme: CupertinoTextThemeData(
          primaryColor: CupertinoColors.systemBlue,
        ),
      );

  // 8 个文本 token（iOS HIG 标准）

  static TextStyle get largeTitle => const TextStyle(
        fontFamily: '.SF Pro Display',
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.37,
      );

  static TextStyle get title1 => const TextStyle(
        fontFamily: '.SF Pro Display',
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.36,
      );

  static TextStyle get headline => const TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
      );

  static TextStyle get body => const TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.41,
      );

  static TextStyle get callout => const TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.32,
      );

  static TextStyle get subhead => const TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.24,
      );

  static TextStyle get footnote => const TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.08,
      );

  static TextStyle get caption1 => const TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      );
}
