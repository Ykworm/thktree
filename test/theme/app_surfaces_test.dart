import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';

void main() {
  test('contentCard is white surface with border and soft shadow', () {
    final d = AppSurfaces.contentCard();
    expect(d.color, AppColors.surface);
    expect(d.border, isNotNull);
    expect(d.boxShadow, isNotNull);
    expect(d.boxShadow!, isNotEmpty);
  });

  test('assistantBubble matches content card surface', () {
    final d = AppSurfaces.assistantBubble();
    expect(d.color, AppColors.surface);
    expect(d.boxShadow, isNotNull);
  });

  test('userBubble uses accentLight without heavy elevation', () {
    final d = AppSurfaces.userBubble();
    expect(d.color, AppColors.accentLight);
    expect(d.boxShadow, isNull);
  });

  test('page canvas token is paper, not pure white', () {
    AppColors.setBrightness(Brightness.light);
    expect(AppColors.pageBg, isNot(AppColors.surface));
    expect(AppColors.pageBg.toARGB32(), 0xFFF7F5F0);
  });

  test('AppGlass fill is translucent; opaque fallback is solid paper-warm', () {
    expect(AppGlass.fill.a, lessThan(1.0));
    expect(AppGlass.fill.toARGB32() & 0x00FFFFFF, 0x00FFFFFF);
    expect(AppGlass.fillOpaque.a, 1.0);
    expect(AppGlass.fillOpaque.toARGB32(), 0xFFF3EFE8);
    expect(AppGlass.blurSigma, 14.0);
    expect(AppGlass.chromeFill, anyOf(AppGlass.fill, AppGlass.fillOpaque));
  });
}
