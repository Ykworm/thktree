import 'dart:convert';

enum ExportScope { full }

class ExportManifest {
  ExportManifest({
    required this.schema,
    required this.appVersion,
    required this.exportedAt,
    required this.scope,
    required this.themes,
  });

  final String schema;
  final String appVersion;
  final DateTime exportedAt;
  final ExportScope scope;
  final List<ThemeExport> themes;

  Map<String, Object?> toJson() {
    return {
      'schema': schema,
      'appVersion': appVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'scope': scope.name,
      'themes': themes.map((t) => t.toJson()).toList(),
    };
  }

  static ExportManifest fromJson(Map<String, Object?> json) {
    return switch (json) {
      {
        'schema': String schema,
        'appVersion': String appVersion,
        'exportedAt': String exportedAt,
        'scope': String scope,
        'themes': List<dynamic> themes,
      } =>
        ExportManifest(
          schema: schema,
          appVersion: appVersion,
          exportedAt: DateTime.parse(exportedAt),
          scope: ExportScope.values.byName(scope),
          themes: themes
              .map((t) => ThemeExport.fromJson(t as Map<String, Object?>))
              .toList(),
        ),
      _ => throw const FormatException('Invalid manifest format'),
    };
  }

  String toJsonString() =>
      const JsonEncoder.withIndent('  ').convert(toJson());
}

class ThemeExport {
  ThemeExport({
    required this.themeId,
    required this.title,
    required this.nodeCount,
    required this.noteCount,
  });

  final String themeId;
  final String title;
  final int nodeCount;
  final int noteCount;

  Map<String, Object?> toJson() {
    return {
      'themeId': themeId,
      'title': title,
      'nodeCount': nodeCount,
      'noteCount': noteCount,
    };
  }

  static ThemeExport fromJson(Map<String, Object?> json) {
    return switch (json) {
      {
        'themeId': String themeId,
        'title': String title,
        'nodeCount': int nodeCount,
        'noteCount': int noteCount,
      } =>
        ThemeExport(
          themeId: themeId,
          title: title,
          nodeCount: nodeCount,
          noteCount: noteCount,
        ),
      _ => throw const FormatException('Invalid theme export format'),
    };
  }
}
