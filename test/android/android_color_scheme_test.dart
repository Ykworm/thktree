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
    // 通用交互色：现代蓝必须成为 primary（而非 Material 默认紫）。
    expect(s.primary, AppColors.accent);
    expect(s.primary.toARGB32(), 0xFF3B82F6);
    // 中性底座 + 错误色
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
    // 暗色下 surface 应为 Slate 900（非白），验证取的是 AppColors 暗值。
    expect(s.surface.toARGB32(), AppColors.surface.toARGB32());
    expect(s.surface, isNot(equals(const Color(0xFFFFFFFF))));
    expect(s.primary, AppColors.accent); // accent 不随亮度变
  });

  test('androidTheme 底部导航高度 ≥ 48 触摸区', () {
    AppColors.setBrightness(Brightness.light);
    final theme = androidTheme();
    expect(
      theme.navigationBarTheme.height!,
      greaterThanOrEqualTo(48.0),
    );
  });

  test('全局只有一个可见的真源：accent 即 handoff 指定的现代蓝', () {
    // 若此处失败，说明有人改了 AppColors.accent，需同步 review。
    expect(AppColors.accent.toARGB32(), 0xFF3B82F6);
  });
}
