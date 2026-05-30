import 'dart:convert';

import 'package:thk_tree/domain/theme.dart';

class ThemeMetaV1 {
  ThemeMetaV1({
    required this.themeId,
    required this.title,
    required this.createdAtUtcIso8601,
    required this.updatedAtUtcIso8601,
  });

  final String themeId;
  final String title;
  final String createdAtUtcIso8601;
  final String updatedAtUtcIso8601;

  Map<String, Object?> toJson() {
    return {
      'schema': 'theme_meta/v1',
      'themeId': themeId,
      'title': title,
      'createdAt': createdAtUtcIso8601,
      'updatedAt': updatedAtUtcIso8601,
    };
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  static ThemeMetaV1 fromJson(Map<String, Object?> json) {
    return switch (json) {
      {
        'schema': 'theme_meta/v1',
        'themeId': String themeId,
        'title': String title,
        'createdAt': String createdAt,
        'updatedAt': String updatedAt,
      } =>
        ThemeMetaV1(
          themeId: themeId,
          title: title,
          createdAtUtcIso8601: createdAt,
          updatedAtUtcIso8601: updatedAt,
        ),
      {'schema': final schema} =>
        throw FormatException('Unexpected schema: $schema'),
      _ => throw const FormatException('Invalid theme meta fields'),
    };
  }

  ThemeEntity toEntity() {
    return ThemeEntity(
      themeId: themeId,
      title: title,
      createdAtUtcIso8601: createdAtUtcIso8601,
      updatedAtUtcIso8601: updatedAtUtcIso8601,
    );
  }
}

