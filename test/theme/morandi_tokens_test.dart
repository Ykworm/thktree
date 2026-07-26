import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_palette_tokens.dart';

import 'palette_test_helpers.dart';

void main() {
  setUp(resetAppColorsForTest);
  tearDown(resetAppColorsForTest);

  test('morandi light palette ARGB matches design matrix', () {
    AppColors.setPalette(AppColorPalette.morandi);

    expect(AppColors.pageBg.toARGB32(), 0xFFEBE8E3);
    expect(AppColors.surface.toARGB32(), 0xFFF5F3EF);
    expect(AppColors.surfaceMuted.toARGB32(), 0xFFE2DED8);
    expect(AppColors.textPrimary.toARGB32(), 0xFF3D3A36);
    expect(AppColors.textSecondary.toARGB32(), 0xFF6B6560);
    expect(AppColors.textTertiary.toARGB32(), 0xFF837E77);
    expect(AppColors.textQuaternary.toARGB32(), 0xFFB8B2AA);
    expect(AppColors.border.toARGB32(), 0xFFD5D0C8);
    expect(AppColors.borderStrong.toARGB32(), 0xFFC4BEB4);
    expect(AppColors.elevationShadow.toARGB32(), 0x1A3D3A36);
    expect(AppColors.accent.toARGB32(), 0xFF7B8FA1);
    expect(AppColors.accentLight.toARGB32(), 0xFFF2F4F6);
    expect(AppColors.accentDeep.toARGB32(), 0xFF6A7E90);
    expect(AppColors.questionSourceTag.toARGB32(), 0x807B8FA1);
    expect(AppColors.paletteBlue.toARGB32(), 0xFF7B8FA1);
    expect(AppColors.paletteSage.toARGB32(), 0xFF8B9A82);
    expect(AppColors.paletteClay.toARGB32(), 0xFFB89585);
    expect(AppColors.paletteGold.toARGB32(), 0xFFB8A67A);
    expect(AppColors.palettePlum.toARGB32(), 0xFF9A8A9E);
    expect(AppColors.matteGoldLight.toARGB32(), 0xFFFBFAF7);
    expect(AppColors.matteGoldBg.toARGB32(), 0xFFF8F6F2);
    expect(AppColors.matteGoldBorder.toARGB32(), 0xFFEDE9DE);
    expect(AppColors.textMatteGoldDark.toARGB32(), 0xFF6B6353);
    expect(AppColors.matteGold.toARGB32(), 0xFFB8A67A);
    expect(AppColors.glassFill.toARGB32(), 0x8CF5F3EF);
    expect(AppColors.glassFillOpaque.toARGB32(), 0xFFE2DED8);
  });
}
