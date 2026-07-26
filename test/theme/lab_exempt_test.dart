import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_palette_tokens.dart';

import 'palette_test_helpers.dart';

void main() {
  setUp(resetAppColorsForTest);
  tearDown(resetAppColorsForTest);

  test('lab and wave tokens stay constant when switching to morandi', () {
    final labBg = AppColors.labBg.toARGB32();
    final labBlue = AppColors.labAccentBlue.toARGB32();
    final labOrange = AppColors.labAccentOrange.toARGB32();
    final labPurple = AppColors.labAccentPurple.toARGB32();
    final waveTeal = AppColors.waveTeal.toARGB32();
    final waveOrange = AppColors.waveOrange.toARGB32();
    final wavePurple = AppColors.wavePurple.toARGB32();
    final destructive = AppColors.destructive.toARGB32();

    AppColors.setPalette(AppColorPalette.morandi);

    expect(AppColors.labBg.toARGB32(), labBg);
    expect(AppColors.labAccentBlue.toARGB32(), labBlue);
    expect(AppColors.labAccentOrange.toARGB32(), labOrange);
    expect(AppColors.labAccentPurple.toARGB32(), labPurple);
    expect(AppColors.waveTeal.toARGB32(), waveTeal);
    expect(AppColors.waveOrange.toARGB32(), waveOrange);
    expect(AppColors.wavePurple.toARGB32(), wavePurple);
    expect(AppColors.destructive.toARGB32(), destructive);
  });
}
