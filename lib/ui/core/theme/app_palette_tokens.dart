import 'dart:ui';

/// 节点卡片配色方案（圆圈 + 标题 + 副标题）。
/// 从 app_colors.dart 迁入；app_colors.dart 以 export 保持兼容。
class NodePalette {
  const NodePalette(this.circle, this.title, this.subtitle);
  final Color circle;
  final Color title;
  final Color subtitle;
}

/// 一套皮肤的完整语义色表。全部字段 required：新皮肤缺字段 → 编译失败。
class AppPaletteTokens {
  const AppPaletteTokens({
    required this.pageBg,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textQuaternary,
    required this.border,
    required this.borderStrong,
    required this.elevationShadow,
    required this.accent,
    required this.accentLight,
    required this.accentDeep,
    required this.questionSourceTag,
    required this.paletteBlue,
    required this.paletteSage,
    required this.paletteClay,
    required this.paletteGold,
    required this.palettePlum,
    required this.matteGoldLight,
    required this.matteGoldBg,
    required this.matteGoldBorder,
    required this.textMatteGoldDark,
    required this.matteGold,
    required this.champagneGold,
    required this.warmGray,
    required this.dustyRose,
    required this.sageGray,
    required this.slateBlue,
    required this.glassFill,
    required this.glassFillOpaque,
    required this.nodePalettes,
  });

  final Color pageBg;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textQuaternary;
  final Color border;
  final Color borderStrong;
  final Color elevationShadow;
  final Color accent;
  final Color accentLight;
  final Color accentDeep;
  final Color questionSourceTag;
  final Color paletteBlue;
  final Color paletteSage;
  final Color paletteClay;
  final Color paletteGold;
  final Color palettePlum;
  final Color matteGoldLight;
  final Color matteGoldBg;
  final Color matteGoldBorder;
  final Color textMatteGoldDark;
  final Color matteGold;
  final Color champagneGold;
  final Color warmGray;
  final Color dustyRose;
  final Color sageGray;
  final Color slateBlue;
  final Color glassFill;
  final Color glassFillOpaque;
  final List<NodePalette> nodePalettes;

  List<Color> get themeColors => [
    paletteBlue,
    paletteSage,
    paletteClay,
    paletteGold,
    palettePlum,
  ];

  List<Color> get themeTileColors => themeColors;

  Color get success => paletteSage;

  Color get clay => paletteClay;

  Color get gold => paletteGold;

  Color get plum => palettePlum;
}

enum AppColorPalette { warmPaper, morandi }

/// 皮肤注册表。slate = 深色模式（不进 Settings UI，不进 AppColorPalette）。
class AppThemeRegistry {
  AppThemeRegistry._();

  static const _wpBlue = Color(0xFF4A7AB5);
  static const _wpSage = Color(0xFF5A9E7F);
  static const _wpClay = Color(0xFFC47856);
  static const _wpGold = Color(0xFFC9A24E);
  static const _wpPlum = Color(0xFF8B6AAE);
  static const _wpTitle = Color(0xFF1F2933);
  static const _wpSubtitle = Color(0xFF4A5568);

  static const _morBlue = Color(0xFF7B8FA1);
  static const _morSage = Color(0xFF8B9A82);
  static const _morClay = Color(0xFFB89585);
  static const _morGold = Color(0xFFB8A67A);
  static const _morPlum = Color(0xFF9A8A9E);
  static const _morTitle = Color(0xFF3D3A36);
  static const _morSubtitle = Color(0xFF6B6560);

  static const warmPaper = AppPaletteTokens(
    pageBg: Color(0xFFFAF9F6),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF2EFEA),
    textPrimary: Color(0xFF1F2933),
    textSecondary: Color(0xFF4A5568),
    textTertiary: Color(0xFF8492A6),
    textQuaternary: Color(0xFFB8C2CC),
    border: Color(0xFFE8E4DC),
    borderStrong: Color(0xFFD9D3C8),
    elevationShadow: Color(0x1A1F2933),
    accent: _wpBlue,
    accentLight: Color(0xFFEDF2F8),
    accentDeep: Color(0xFF3D6A9E),
    questionSourceTag: Color(0x804A7AB5),
    paletteBlue: _wpBlue,
    paletteSage: _wpSage,
    paletteClay: _wpClay,
    paletteGold: _wpGold,
    palettePlum: _wpPlum,
    matteGoldLight: Color(0xFFFFFDF5),
    matteGoldBg: Color(0xFFF9F7F1),
    matteGoldBorder: Color(0xFFF2EADC),
    textMatteGoldDark: Color(0xFF5C544D),
    matteGold: Color(0xFFD4A373),
    champagneGold: Color(0xFFC4A77D),
    warmGray: Color(0xFF8E8B82),
    dustyRose: Color(0xFFA89090),
    sageGray: Color(0xFF8B9080),
    slateBlue: Color(0xFF6B7B8E),
    glassFill: Color(0x8CFFFFFF),
    glassFillOpaque: Color(0xFFF3EFE8),
    nodePalettes: [
      NodePalette(_wpBlue, _wpTitle, _wpSubtitle),
      NodePalette(_wpSage, _wpTitle, _wpSubtitle),
      NodePalette(_wpClay, _wpTitle, _wpSubtitle),
      NodePalette(_wpGold, _wpTitle, _wpSubtitle),
      NodePalette(_wpPlum, _wpTitle, _wpSubtitle),
    ],
  );

  static const morandi = AppPaletteTokens(
    pageBg: Color(0xFFEBE8E3),
    surface: Color(0xFFF5F3EF),
    surfaceMuted: Color(0xFFE2DED8),
    textPrimary: _morTitle,
    textSecondary: _morSubtitle,
    textTertiary: Color(0xFF837E77),
    textQuaternary: Color(0xFFB8B2AA),
    border: Color(0xFFD5D0C8),
    borderStrong: Color(0xFFC4BEB4),
    elevationShadow: Color(0x1A3D3A36),
    accent: _morBlue,
    accentLight: Color(0xFFF2F4F6),
    accentDeep: Color(0xFF6A7E90),
    questionSourceTag: Color(0x807B8FA1),
    paletteBlue: _morBlue,
    paletteSage: _morSage,
    paletteClay: _morClay,
    paletteGold: _morGold,
    palettePlum: _morPlum,
    matteGoldLight: Color(0xFFFBFAF7),
    matteGoldBg: Color(0xFFF8F6F2),
    matteGoldBorder: Color(0xFFEDE9DE),
    textMatteGoldDark: Color(0xFF6B6353),
    matteGold: Color(0xFFB8A67A),
    champagneGold: Color(0xFFC4A77D),
    warmGray: Color(0xFF8E8B82),
    dustyRose: Color(0xFFA89090),
    sageGray: Color(0xFF8B9080),
    slateBlue: Color(0xFF6B7B8E),
    glassFill: Color(0x8CF5F3EF),
    glassFillOpaque: Color(0xFFE2DED8),
    nodePalettes: [
      NodePalette(_morBlue, _morTitle, _morSubtitle),
      NodePalette(_morSage, _morTitle, _morSubtitle),
      NodePalette(_morClay, _morTitle, _morSubtitle),
      NodePalette(_morGold, _morTitle, _morSubtitle),
      NodePalette(_morPlum, _morTitle, _morSubtitle),
    ],
  );

  static const slate = AppPaletteTokens(
    pageBg: Color(0xFF020617),
    surface: Color(0xFF0F172A),
    surfaceMuted: Color(0xFF1E293B),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textTertiary: Color(0xFF64748B),
    textQuaternary: Color(0xFF475569),
    border: Color(0xFF334155),
    borderStrong: Color(0xFF475569),
    elevationShadow: Color(0x1A1F2933),
    accent: _wpBlue,
    accentLight: Color(0xFF1E3A5F),
    accentDeep: Color(0xFF3D6A9E),
    questionSourceTag: Color(0x804A7AB5),
    paletteBlue: _wpBlue,
    paletteSage: _wpSage,
    paletteClay: _wpClay,
    paletteGold: _wpGold,
    palettePlum: _wpPlum,
    matteGoldLight: Color(0xFFFFFDF5),
    matteGoldBg: Color(0xFFF9F7F1),
    matteGoldBorder: Color(0xFFF2EADC),
    textMatteGoldDark: Color(0xFF5C544D),
    matteGold: Color(0xFFD4A373),
    champagneGold: Color(0xFFC4A77D),
    warmGray: Color(0xFF8E8B82),
    dustyRose: Color(0xFFA89090),
    sageGray: Color(0xFF8B9080),
    slateBlue: Color(0xFF6B7B8E),
    glassFill: Color(0x8CFFFFFF),
    glassFillOpaque: Color(0xFFF3EFE8),
    nodePalettes: [
      NodePalette(_wpBlue, _wpTitle, _wpSubtitle),
      NodePalette(_wpSage, _wpTitle, _wpSubtitle),
      NodePalette(_wpClay, _wpTitle, _wpSubtitle),
      NodePalette(_wpGold, _wpTitle, _wpSubtitle),
      NodePalette(_wpPlum, _wpTitle, _wpSubtitle),
    ],
  );

  static AppPaletteTokens of(AppColorPalette p) => switch (p) {
    AppColorPalette.warmPaper => warmPaper,
    AppColorPalette.morandi => morandi,
  };
}
