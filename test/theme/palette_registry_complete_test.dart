import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/ui/core/theme/app_palette_tokens.dart';

void main() {
  test('each user palette has registry entry', () {
    for (final p in AppColorPalette.values) {
      expect(AppThemeRegistry.of(p), isNotNull);
    }
  });

  test('slate shares field structure with warmPaper and morandi', () {
    const wp = AppThemeRegistry.warmPaper;
    const mor = AppThemeRegistry.morandi;
    const sl = AppThemeRegistry.slate;

    expect(sl.nodePalettes.length, wp.nodePalettes.length);
    expect(mor.nodePalettes.length, wp.nodePalettes.length);
    expect(sl.themeColors.length, wp.themeColors.length);
    expect(mor.themeColors.length, wp.themeColors.length);
  });
}
