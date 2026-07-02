import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:thk_tree/data/services/keyword_storage_utils.dart';

/// leaf（chat 节点）的状态机。
///
/// - [pending]：新建且从未分析
/// - [fresh]：已分析，内容未变化
/// - [stale]：已分析，但用户后续发送了新消息
enum LeafStatus { pending, fresh, stale }

/// 单个 leaf 的关键词条目。
class KeywordEntry {
  const KeywordEntry({required this.keyword, required this.categoryId});

  final String keyword;
  final String categoryId;

  Map<String, Object?> toJson() => {
        'keyword': keyword,
        'category_id': categoryId,
      };

  factory KeywordEntry.fromJson(Map<String, Object?> json) {
    return KeywordEntry(
      keyword: json['keyword']! as String,
      categoryId: json['category_id']! as String,
    );
  }
}

/// 单个 leaf 的分析记录。
class LeafAnalysisRecord {
  LeafAnalysisRecord({
    required this.leafId,
    required this.status,
    this.lastAnalyzedAt,
    this.lastUserMessageAt,
    this.keywords = const [],
  });

  final String leafId;
  LeafStatus status;
  DateTime? lastAnalyzedAt;
  DateTime? lastUserMessageAt;
  List<KeywordEntry> keywords;

  Map<String, Object?> toJson() => {
        'leaf_id': leafId,
        'status': status.name,
        if (lastAnalyzedAt != null) 'last_analyzed_at': lastAnalyzedAt!.toIso8601String(),
        if (lastUserMessageAt != null)
          'last_user_message_at': lastUserMessageAt!.toIso8601String(),
        'keywords': keywords.map((e) => e.toJson()).toList(),
      };

  factory LeafAnalysisRecord.fromJson(String leafId, Map<String, Object?> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    final status = LeafStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => LeafStatus.pending,
    );
    final keywords = (json['keywords'] as List? ?? const [])
        .map((e) => KeywordEntry.fromJson(Map<String, Object?>.from(e as Map)))
        .toList(growable: true);
    return LeafAnalysisRecord(
      leafId: leafId,
      status: status,
      lastAnalyzedAt: _parseDate(json['last_analyzed_at']),
      lastUserMessageAt: _parseDate(json['last_user_message_at']),
      keywords: keywords,
    );
  }
}

/// 整个 theme 的 keyword_analysis.json 文件结构。
class KeywordAnalysisFile {
  KeywordAnalysisFile({
    required this.themeId,
    this.updatedAt,
    Map<String, LeafAnalysisRecord>? leaves,
  }) : leaves = leaves ?? <String, LeafAnalysisRecord>{};

  static const int currentVersion = 1;

  String themeId;
  DateTime? updatedAt;
  final Map<String, LeafAnalysisRecord> leaves;

  Map<String, Object?> toJson() => {
        'version': currentVersion,
        'theme_id': themeId,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        'leaves': leaves.map((key, value) => MapEntry(key, value.toJson())),
      };

  factory KeywordAnalysisFile.fromJson(Map<String, Object?> json) {
    final themeId = json['theme_id']! as String;
    final leavesRaw = json['leaves'] as Map? ?? const {};
    final leaves = <String, LeafAnalysisRecord>{};
    for (final entry in leavesRaw.entries) {
      final leafMap = Map<String, Object?>.from(entry.value as Map);
      leaves[entry.key as String] = LeafAnalysisRecord.fromJson(
        entry.key as String,
        leafMap,
      );
    }
    return KeywordAnalysisFile(
      themeId: themeId,
      updatedAt: _parseDate(json['updated_at']),
      leaves: leaves,
    );
  }
}

/// 单个 theme 的 keyword_analysis.json 文件读写器。
///
/// 文件路径：`<themePath>/keyword_analysis.json`
/// - [themePath] 是 theme 的目录（如 `<rootDir>/themes/<theme_id>`）
class KeywordAnalysisStorage {
  KeywordAnalysisStorage({required this.themePath});

  final String themePath;

  String get _filePath => p.join(themePath, 'keyword_analysis.json');

  /// 读取或初始化文件。
  /// 如果文件不存在，写入一个空骨架（theme_id 来自 [themePath]）。
  Future<KeywordAnalysisFile> loadOrInit() async {
    final file = File(_filePath);
    if (!await file.exists()) {
      final themeId = p.basename(themePath);
      final empty = KeywordAnalysisFile(themeId: themeId);
      await _write(empty);
      return empty;
    }
    return read();
  }

  /// 读取文件。文件不存在或解析失败时抛出异常。
  Future<KeywordAnalysisFile> read() async {
    final file = File(_filePath);
    final text = await file.readAsString();
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('keyword_analysis.json is not an object');
    }
    return KeywordAnalysisFile.fromJson(Map<String, Object?>.from(decoded));
  }

  /// 原子写入文件。
  Future<void> _write(KeywordAnalysisFile data) async {
    data.updatedAt = DateTime.now().toUtc();
    final encoder = const JsonEncoder.withIndent('  ');
    await KeywordStorageUtils.atomicWriteString(
      _filePath,
      encoder.convert(data.toJson()),
    );
  }

  /// 读 → 修改 → 写（原子）。
  /// [mutator] 是同步函数，在文件读取后调用，返回修改后的文件。
  Future<KeywordAnalysisFile> updateAsync(
    KeywordAnalysisFile Function(KeywordAnalysisFile current) mutator,
  ) async {
    final current = await loadOrInit();
    final updated = mutator(current);
    await _write(updated);
    return updated;
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}