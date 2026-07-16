import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// P0 Warm Paper Glass：断言 light 语义色真源（shipped AppColors），非硬编码旁路。
void main() {
  setUp(() => AppColors.setBrightness(Brightness.light));
  tearDown(() => AppColors.setBrightness(Brightness.light));

  test('paper / paper-warm / white card', () {
    expect(AppColors.pageBg.toARGB32(), 0xFFF7F5F0);
    expect(AppColors.surfaceMuted.toARGB32(), 0xFFF3EFE8);
    expect(AppColors.surface.toARGB32(), 0xFFFFFFFF);
  });

  test('ink text ladder', () {
    expect(AppColors.textPrimary.toARGB32(), 0xFF1F2933);
    expect(AppColors.textSecondary.toARGB32(), 0xFF4A5568);
    expect(AppColors.textTertiary.toARGB32(), 0xFF8492A6);
    expect(AppColors.textQuaternary.toARGB32(), 0xFFB8C2CC);
  });

  test('accent fog blue + soft pressed', () {
    expect(AppColors.accent.toARGB32(), 0xFF4A7AB5);
    expect(AppColors.accentDeep.toARGB32(), 0xFF3D6A9E);
    expect(AppColors.accentLight.toARGB32(), 0xFFEDF2F8);
    expect(AppColors.userBubbleBg, AppColors.accentLight);
  });

  test('five-color theme + tile + node palettes aligned', () {
    const five = [
      0xFF4A7AB5,
      0xFF5A9E7F,
      0xFFC47856,
      0xFFC9A24E,
      0xFF8B6AAE,
    ];
    expect(AppColors.themeColors.map((c) => c.toARGB32()), five);
    expect(AppColors.themeTileColors.map((c) => c.toARGB32()), five);
    expect(
      AppColors.nodePalettes.map((p) => p.circle.toARGB32()).toList(),
      five,
    );
  });

  test('success is sage; destructive hard red; lab accents untouched', () {
    expect(AppColors.success.toARGB32(), 0xFF5A9E7F);
    expect(AppColors.destructive.toARGB32(), 0xFFDC2626);
    expect(AppColors.labAccentBlue.toARGB32(), 0xFF3B82F6);
    expect(AppColors.labAccentOrange.toARGB32(), 0xFFF97316);
    expect(AppColors.labAccentPurple.toARGB32(), 0xFFA855F7);
    expect(AppColors.labBg.toARGB32(), 0xFF0F1035);
  });

  test('semantic clay/gold/plum match five-color system', () {
    expect(AppColors.clay, AppColors.paletteClay);
    expect(AppColors.gold, AppColors.paletteGold);
    expect(AppColors.plum, AppColors.palettePlum);
  });
}
