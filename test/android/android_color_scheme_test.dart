import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/platform/android/android_color_scheme.dart';

void main() {
  // AppColors 是全局静态，测试间互不污染。
  tearDown(() => AppColors.setBrightness(Brightness.light));

  test('light scheme 把 token 正确映射到 Material 3 ColorScheme', () {
    AppColors.setBrightness(Brightness.light);
    final s = androidColorScheme();

    expect(s.brightness, Brightness.light);
    expect(s.primary, AppColors.accent);
    expect(s.primary.toARGB32(), 0xFF4A7AB5);
    expect(s.surface, AppColors.surface);
    expect(s.onSurface, AppColors.textPrimary);
    expect(s.error, AppColors.destructive);
    expect(s.outline, AppColors.border);
    expect(s.scrim, AppColors.scrim);
    expect(s.shadow, AppColors.elevationShadow);
  });

  test('dark scheme 同样从 AppColors 真源取暗色值', () {
    AppColors.setBrightness(Brightness.dark);
    final s = androidColorScheme();

    expect(s.brightness, Brightness.dark);
    expect(s.surface.toARGB32(), AppColors.surface.toARGB32());
    expect(s.surface, isNot(equals(const Color(0xFFFFFFFF))));
    expect(s.primary, AppColors.accent);
  });

  test('androidTheme 底部导航高度 ≥ 48 触摸区', () {
    AppColors.setBrightness(Brightness.light);
    final theme = androidTheme();
    expect(
      theme.navigationBarTheme.height!,
      greaterThanOrEqualTo(48.0),
    );
  });

  test('全局 accent 为 Warm Paper 雾蓝（非旧 Tailwind 鲜蓝）', () {
    expect(AppColors.accent.toARGB32(), 0xFF4A7AB5);
    expect(AppColors.accent.toARGB32(), isNot(0xFF3B82F6));
  });
}
