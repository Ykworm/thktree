import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_palette_tokens.dart';

import 'palette_test_helpers.dart';

void main() {
  setUp(resetAppColorsForTest);
  tearDown(resetAppColorsForTest);

  test('dark mode uses slate palette ARGB baseline', () {
    AppColors.setBrightness(Brightness.dark);

    expect(AppColors.pageBg.toARGB32(), 0xFF020617);
    expect(AppColors.surface.toARGB32(), 0xFF0F172A);
    expect(AppColors.surfaceMuted.toARGB32(), 0xFF1E293B);
    expect(AppColors.textPrimary.toARGB32(), 0xFFF1F5F9);
    expect(AppColors.textSecondary.toARGB32(), 0xFF94A3B8);
    expect(AppColors.textTertiary.toARGB32(), 0xFF64748B);
    expect(AppColors.textQuaternary.toARGB32(), 0xFF475569);
    expect(AppColors.border.toARGB32(), 0xFF334155);
    expect(AppColors.borderStrong.toARGB32(), 0xFF475569);
    expect(AppColors.accentLight.toARGB32(), 0xFF1E3A5F);
    expect(AppColors.accent.toARGB32(), 0xFF4A7AB5);
    expect(AppColors.accentDeep.toARGB32(), 0xFF3D6A9E);
    expect(AppColors.elevationShadow.toARGB32(), 0x1A1F2933);
    expect(AppColors.questionSourceTag.toARGB32(), 0x804A7AB5);
    expect(AppColors.glassFill.toARGB32(), 0x8CFFFFFF);
    expect(AppColors.glassFillOpaque.toARGB32(), 0xFFF3EFE8);
  });

  test('dark morandi still resolves to slate (not morandi light values)', () {
    AppColors.setPalette(AppColorPalette.morandi);
    AppColors.setBrightness(Brightness.dark);

    expect(AppColors.pageBg.toARGB32(), 0xFF020617);
    expect(AppColors.surface.toARGB32(), 0xFF0F172A);
    expect(AppColors.accent.toARGB32(), 0xFF4A7AB5);
  });
}
