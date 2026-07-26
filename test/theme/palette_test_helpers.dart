import 'dart:ui' show Brightness;

import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_palette_tokens.dart';

/// 捕获所有随皮肤/亮度变化的语义色 getter，供 round-trip 与回归测试使用。
Map<String, int> captureAllSemanticColors() {
  final out = <String, int>{};

  void put(String key, int argb) => out[key] = argb;

  put('pageBg', AppColors.pageBg.toARGB32());
  put('surface', AppColors.surface.toARGB32());
  put('surfaceMuted', AppColors.surfaceMuted.toARGB32());
  put('textPrimary', AppColors.textPrimary.toARGB32());
  put('textSecondary', AppColors.textSecondary.toARGB32());
  put('textTertiary', AppColors.textTertiary.toARGB32());
  put('textQuaternary', AppColors.textQuaternary.toARGB32());
  put('border', AppColors.border.toARGB32());
  put('borderStrong', AppColors.borderStrong.toARGB32());
  put('elevationShadow', AppColors.elevationShadow.toARGB32());
  put('accent', AppColors.accent.toARGB32());
  put('accentLight', AppColors.accentLight.toARGB32());
  put('accentDeep', AppColors.accentDeep.toARGB32());
  put('questionSourceTag', AppColors.questionSourceTag.toARGB32());
  put('paletteBlue', AppColors.paletteBlue.toARGB32());
  put('paletteSage', AppColors.paletteSage.toARGB32());
  put('paletteClay', AppColors.paletteClay.toARGB32());
  put('paletteGold', AppColors.paletteGold.toARGB32());
  put('palettePlum', AppColors.palettePlum.toARGB32());
  put('matteGoldLight', AppColors.matteGoldLight.toARGB32());
  put('matteGoldBg', AppColors.matteGoldBg.toARGB32());
  put('matteGoldBorder', AppColors.matteGoldBorder.toARGB32());
  put('textMatteGoldDark', AppColors.textMatteGoldDark.toARGB32());
  put('matteGold', AppColors.matteGold.toARGB32());
  put('champagneGold', AppColors.champagneGold.toARGB32());
  put('warmGray', AppColors.warmGray.toARGB32());
  put('dustyRose', AppColors.dustyRose.toARGB32());
  put('sageGray', AppColors.sageGray.toARGB32());
  put('slateBlue', AppColors.slateBlue.toARGB32());
  put('glassFill', AppColors.glassFill.toARGB32());
  put('glassFillOpaque', AppColors.glassFillOpaque.toARGB32());
  put('success', AppColors.success.toARGB32());
  put('clay', AppColors.clay.toARGB32());
  put('gold', AppColors.gold.toARGB32());
  put('plum', AppColors.plum.toARGB32());
  put('thinkingBg', AppColors.thinkingBg.toARGB32());
  put('markdownCodeBg', AppColors.markdownCodeBg.toARGB32());
  put('userBubbleBg', AppColors.userBubbleBg.toARGB32());
  put('assistantBubbleBg', AppColors.assistantBubbleBg.toARGB32());
  put('assistantBubbleBorder', AppColors.assistantBubbleBorder.toARGB32());

  for (var i = 0; i < AppColors.themeColors.length; i++) {
    put('themeColors_$i', AppColors.themeColors[i].toARGB32());
  }
  for (var i = 0; i < AppColors.themeTileColors.length; i++) {
    put('themeTileColors_$i', AppColors.themeTileColors[i].toARGB32());
  }
  for (var i = 0; i < AppColors.nodePalettes.length; i++) {
    final p = AppColors.nodePalettes[i];
    put('nodePalettes_${i}_circle', p.circle.toARGB32());
    put('nodePalettes_${i}_title', p.title.toARGB32());
    put('nodePalettes_${i}_subtitle', p.subtitle.toARGB32());
  }

  return out;
}

/// 测试 setUp/tearDown 复位 AppColors 静态全局状态。
void resetAppColorsForTest() {
  AppColors.setBrightness(Brightness.light);
  AppColors.setPalette(AppColorPalette.warmPaper);
}
