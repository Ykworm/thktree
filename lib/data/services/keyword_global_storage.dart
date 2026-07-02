import 'dart:convert';
import 'dart:io';

import 'package:thk_tree/data/services/keyword_storage_utils.dart';

/// 反向索引中的一条记录：某个 keyword 在某个 leaf 中的关联。
class KeywordLeafRef {
  const KeywordLeafRef({
    required this.themeId,
    required this.leafId,
    required this.categoryId,
  });

  final String themeId;
  final String leafId;
  final String categoryId;

  Map<String, Object?> toJson() => {
        'theme_id': themeId,
        'leaf_id': leafId,
        'category_id': categoryId,
      };

  factory KeywordLeafRef.fromJson(Map<String, Object?> json) {
    return KeywordLeafRef(
      themeId: json['theme_id']! as String,
      leafId: json['leaf_id']! as String,
      categoryId: json['category_id']! as String,
    );
  }
}

/// 全局聚合后的关键词条目（含统计与 score）。
class GlobalKeywordEntry {
  GlobalKeywordEntry({
    required this.keyword,
    required this.categoryId,
    required this.crossThemeCount,
    required this.crossLeafCount,
    required this.depthAvg,
    required this.staleRatio,
    required this.score,
  });

  final String keyword;
  final String categoryId;
  int crossThemeCount;
  int crossLeafCount;
  double depthAvg;
  double staleRatio;
  double score;

  Map<String, Object?> toJson() => {
        'keyword': keyword,
        'category_id': categoryId,
        'cross_theme_count': crossThemeCount,
        'cross_leaf_count': crossLeafCount,
        'depth_avg': depthAvg,
        'stale_ratio': staleRatio,
        'score': score,
      };

  factory GlobalKeywordEntry.fromJson(Map<String, Object?> json) {
    return GlobalKeywordEntry(
      keyword: json['keyword']! as String,
      categoryId: json['category_id']! as String,
      crossThemeCount: (json['cross_theme_count'] as num).toInt(),
      crossLeafCount: (json['cross_leaf_count'] as num).toInt(),
      depthAvg: (json['depth_avg'] as num).toDouble(),
      staleRatio: (json['stale_ratio'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
    );
  }
}

/// 全局 `keyword_global.json` 文件结构。
class KeywordGlobalFile {
  KeywordGlobalFile({
    this.scorePrompt,
    this.scorePromptIsDefault = true,
    Map<String, GlobalKeywordEntry>? keywords,
    Map<String, List<KeywordLeafRef>>? keywordLeafMap,
  })  : keywords = keywords ?? <String, GlobalKeywordEntry>{},
        keywordLeafMap = keywordLeafMap ?? <String, List<KeywordLeafRef>>{};

  static const int currentVersion = 1;

  /// 默认 score 计算逻辑（用户首次编辑前的内置 sample）。
  /// 与设计文档 § 4.2 默认模板完全对齐。
  static const String defaultScorePrompt =
      '基于以下因素综合判断 0-1 分数：\n'
      '- 跨主题数 cross_theme_count：越多越重要（最高权重）\n'
      '- 总 leaf 数 cross_leaf_count：越多越重要\n'
      '- 涉及主题平均树深度 depth_avg：越深越说明用户在深度思考该主题\n'
      '- stale 占比 stale_ratio：stale 越多适当降权（说明内容频繁变化、未稳定）\n\n'
      '综合权衡，输出 0-1 浮点。';

  DateTime? updatedAt;
  String? scorePrompt;
  bool scorePromptIsDefault;
  final Map<String, GlobalKeywordEntry> keywords;

  /// 反向索引：keyword → 所有关联的 leaf（含 theme_id + leaf_id + category_id）。
  /// 聚合时全量重建；Detail 视图直接读此映射，无需遍历 theme 文件。
  final Map<String, List<KeywordLeafRef>> keywordLeafMap;

  Map<String, Object?> toJson() => {
        'version': currentVersion,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        'score_prompt': scorePrompt ?? defaultScorePrompt,
        'score_prompt_is_default': scorePromptIsDefault,
        'keywords': keywords.map((key, value) => MapEntry(key, value.toJson())),
        'keyword_leaf_map':
            keywordLeafMap.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList())),
      };

  factory KeywordGlobalFile.fromJson(Map<String, Object?> json) {
    final scorePromptRaw = json['score_prompt'];
    final scorePrompt = scorePromptRaw is String && scorePromptRaw.isNotEmpty
        ? scorePromptRaw
        : KeywordGlobalFile.defaultScorePrompt;
    final scorePromptIsDefault = json['score_prompt_is_default'] as bool? ?? true;

    final keywordsRaw = json['keywords'] as List? ?? const [];
    final keywords = <String, GlobalKeywordEntry>{};
    for (final raw in keywordsRaw) {
      final m = Map<String, Object?>.from(raw as Map);
      final entry = GlobalKeywordEntry.fromJson(m);
      keywords[entry.keyword] = entry;
    }

    final mapRaw = json['keyword_leaf_map'] as Map? ?? const {};
    final keywordLeafMap = <String, List<KeywordLeafRef>>{};
    for (final entry in mapRaw.entries) {
      final refs = (entry.value as List)
          .map((e) => KeywordLeafRef.fromJson(Map<String, Object?>.from(e as Map)))
          .toList(growable: true);
      keywordLeafMap[entry.key as String] = refs;
    }

    return KeywordGlobalFile(
      scorePrompt: scorePrompt,
      scorePromptIsDefault: scorePromptIsDefault,
      keywords: keywords,
      keywordLeafMap: keywordLeafMap,
    )..updatedAt = _parseDate(json['updated_at']);
  }
}

/// 全局 `keyword_global.json` 文件读写器。
///
/// 文件路径：`<rootDir>/keyword_global.json`
/// - [rootDir] 是 ThkTree 根目录（如 `~/Documents/thktree/`）。
class KeywordGlobalStorage {
  KeywordGlobalStorage({required this.rootDir});

  final String rootDir;

  String get _filePath => '$rootDir/keyword_global.json';

  /// 读取或初始化文件。
  /// 文件不存在时写入空骨架（默认 score_prompt）。
  Future<KeywordGlobalFile> loadOrInit() async {
    final file = File(_filePath);
    if (!await file.exists()) {
      final empty = KeywordGlobalFile(scorePrompt: KeywordGlobalFile.defaultScorePrompt);
      await _write(empty);
      return empty;
    }
    return read();
  }

  /// 读取文件。文件不存在或解析失败时抛出异常。
  Future<KeywordGlobalFile> read() async {
    final file = File(_filePath);
    final text = await file.readAsString();
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('keyword_global.json is not an object');
    }
    return KeywordGlobalFile.fromJson(Map<String, Object?>.from(decoded));
  }

  /// 原子写入文件。
  Future<void> _write(KeywordGlobalFile data) async {
    data.updatedAt = DateTime.now().toUtc();
    final encoder = const JsonEncoder.withIndent('  ');
    await KeywordStorageUtils.atomicWriteString(
      _filePath,
      encoder.convert(data.toJson()),
    );
  }

  /// 读 → 修改 → 写（原子）。
  Future<KeywordGlobalFile> updateAsync(
    KeywordGlobalFile Function(KeywordGlobalFile current) mutator,
  ) async {
    final current = await loadOrInit();
    final updated = mutator(current);
    await _write(updated);
    return updated;
  }

  /// 删除指定 theme 的所有反向索引引用（theme 删除时调用）。
  ///
  /// 注意：keywords 聚合条目不在此处删除，由调用方按需聚合重建。
  Future<KeywordGlobalFile> removeThemeRefs(String themeId) async {
    return updateAsync((current) {
      current.keywordLeafMap.removeWhere((keyword, refs) {
        refs.removeWhere((r) => r.themeId == themeId);
        return refs.isEmpty;
      });
      return current;
    });
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}