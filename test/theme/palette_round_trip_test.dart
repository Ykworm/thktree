import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_palette_tokens.dart';

import 'palette_test_helpers.dart';

void main() {
  setUp(resetAppColorsForTest);
  tearDown(resetAppColorsForTest);

  test('warmPaper → morandi → warmPaper round-trip restores snapshot', () {
    final baseline = captureAllSemanticColors();

    AppColors.setPalette(AppColorPalette.morandi);
    expect(captureAllSemanticColors(), isNot(equals(baseline)));

    AppColors.setPalette(AppColorPalette.warmPaper);
    expect(captureAllSemanticColors(), equals(baseline));
  });
}
