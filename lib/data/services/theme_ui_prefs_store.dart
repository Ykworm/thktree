import 'dart:convert';
import 'dart:io';

import 'package:thk_tree/data/services/keyword_storage_utils.dart';

/// 单个主题在树页的 UI 偏好：折叠节点 + 隐藏的 root tree。
class ThemeUiPrefs {
  const ThemeUiPrefs({
    this.collapsedIds = const <String>{},
    this.hiddenRootIds = const <String>{},
  });

  /// 折叠中的节点 id（有子节点时生效）。
  final Set<String> collapsedIds;

  /// 主列表隐藏的 root node id（仅 parentId == null）。
  final Set<String> hiddenRootIds;

  ThemeUiPrefs copyWith({
    Set<String>? collapsedIds,
    Set<String>? hiddenRootIds,
  }) {
    return ThemeUiPrefs(
      collapsedIds: collapsedIds ?? this.collapsedIds,
      hiddenRootIds: hiddenRootIds ?? this.hiddenRootIds,
    );
  }

  Map<String, Object?> toJson() => {
        'collapsedIds': collapsedIds.toList()..sort(),
        'hiddenRootIds': hiddenRootIds.toList()..sort(),
      };

  factory ThemeUiPrefs.fromJson(Map<String, Object?> json) {
    return ThemeUiPrefs(
      collapsedIds: _stringSet(json['collapsedIds']),
      hiddenRootIds: _stringSet(json['hiddenRootIds']),
    );
  }

  static Set<String> _stringSet(Object? raw) {
    if (raw is! List) return <String>{};
    return raw.whereType<String>().toSet();
  }
}

class _ThemeUiPrefsFile {
  _ThemeUiPrefsFile({this.updatedAt, Map<String, ThemeUiPrefs>? themes})
      : themes = themes ?? <String, ThemeUiPrefs>{};

  static const String schema = 'theme_ui_prefs/v1';

  DateTime? updatedAt;
  final Map<String, ThemeUiPrefs> themes;

  Map<String, Object?> toJson() => {
        'schema': schema,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'themes': themes.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory _ThemeUiPrefsFile.fromJson(Map<String, Object?> json) {
    final rawThemes = json['themes'] as Map? ?? const {};
    return _ThemeUiPrefsFile(
      updatedAt: _parseDate(json['updatedAt']),
      themes: rawThemes.map(
        (k, v) => MapEntry(
          k as String,
          ThemeUiPrefs.fromJson(Map<String, Object?>.from(v as Map)),
        ),
      ),
    );
  }
}

/// 全局 `theme_ui_prefs.json`：主题详情页折叠 / root 隐藏偏好。
///
/// 路径：`<rootDir>/theme_ui_prefs.json`（与 scroll_anchors.json 同级）。
class ThemeUiPrefsStore {
  ThemeUiPrefsStore({required this.rootDir});

  final String rootDir;

  String get _filePath => '$rootDir/theme_ui_prefs.json';

  Map<String, ThemeUiPrefs>? _cache;

  Future<ThemeUiPrefs> forTheme(String themeId) async {
    final all = await _loadAll();
    return all[themeId] ?? const ThemeUiPrefs();
  }

  Future<void> setCollapsedIds(String themeId, Set<String> collapsedIds) async {
    final all = Map<String, ThemeUiPrefs>.from(await _loadAll());
    final current = all[themeId] ?? const ThemeUiPrefs();
    all[themeId] = current.copyWith(collapsedIds: Set<String>.from(collapsedIds));
    await _writeAll(all);
  }

  Future<void> setHiddenRootIds(String themeId, Set<String> hiddenRootIds) async {
    final all = Map<String, ThemeUiPrefs>.from(await _loadAll());
    final current = all[themeId] ?? const ThemeUiPrefs();
    all[themeId] =
        current.copyWith(hiddenRootIds: Set<String>.from(hiddenRootIds));
    await _writeAll(all);
  }

  Future<void> setRootHidden(
    String themeId,
    String rootNodeId, {
    required bool hidden,
  }) async {
    final prefs = await forTheme(themeId);
    final next = Set<String>.from(prefs.hiddenRootIds);
    if (hidden) {
      next.add(rootNodeId);
    } else {
      next.remove(rootNodeId);
    }
    await setHiddenRootIds(themeId, next);
  }

  Future<Map<String, ThemeUiPrefs>> _loadAll() async {
    if (_cache != null) return Map.unmodifiable(_cache!);
    _cache = await _loadFromDisk();
    return Map.unmodifiable(_cache!);
  }

  Future<void> _writeAll(Map<String, ThemeUiPrefs> themes) async {
    await _writeToDisk(themes);
    _cache = Map<String, ThemeUiPrefs>.from(themes);
  }

  Future<Map<String, ThemeUiPrefs>> _loadFromDisk() async {
    final file = File(_filePath);
    if (!await file.exists()) {
      return <String, ThemeUiPrefs>{};
    }
    try {
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return <String, ThemeUiPrefs>{};
      }
      return _ThemeUiPrefsFile.fromJson(
        Map<String, Object?>.from(decoded),
      ).themes;
    } catch (_) {
      return <String, ThemeUiPrefs>{};
    }
  }

  Future<void> _writeToDisk(Map<String, ThemeUiPrefs> themes) async {
    final file = _ThemeUiPrefsFile(
      updatedAt: DateTime.now().toUtc(),
      themes: themes,
    );
    final encoder = const JsonEncoder.withIndent('  ');
    await KeywordStorageUtils.atomicWriteString(
      _filePath,
      encoder.convert(file.toJson()),
    );
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
