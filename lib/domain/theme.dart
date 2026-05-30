class ThemeEntity {
  ThemeEntity({
    required this.themeId,
    required this.title,
    required this.createdAtUtcIso8601,
    required this.updatedAtUtcIso8601,
  });

  final String themeId;
  final String title;
  final String createdAtUtcIso8601;
  final String updatedAtUtcIso8601;
}

