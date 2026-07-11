import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/platform/android/android_brightness_controller.dart';

void main() {
  tearDown(() => AppColors.setBrightness(Brightness.light));

  test('syncNow 把注入的暗色亮度同步进 AppColors 单一真源', () {
    AppColors.setBrightness(Brightness.light);
    final c = AndroidBrightnessController(
      getBrightness: () => Brightness.dark,
    );

    c.syncNow();

    expect(AppColors.brightness, Brightness.dark);
  });

  test('didChangePlatformBrightness 触发同步', () {
    AppColors.setBrightness(Brightness.light);
    final c = AndroidBrightnessController(
      getBrightness: () => Brightness.dark,
    );

    c.didChangePlatformBrightness();

    expect(AppColors.brightness, Brightness.dark);
  });

  test('亮色来源同样生效', () {
    AppColors.setBrightness(Brightness.dark);
    final c = AndroidBrightnessController(
      getBrightness: () => Brightness.light,
    );

    c.syncNow();

    expect(AppColors.brightness, Brightness.light);
  });
}
