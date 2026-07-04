import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:thk_tree/data/services/keyword_storage_utils.dart';

/// 用户输入总结的缓存数据。
class UserInputSummaryCache {
  UserInputSummaryCache({
    required this.days,
    this.reportMarkdown,
    this.generatedAt,
    this.inputCount = 0,
  });

  /// 缓存对应的天数范围。
  final int days;

  /// LLM 生成的 Markdown 报告内容。
  String? reportMarkdown;

  /// 报告生成时间。
  DateTime? generatedAt;

  /// 分析的 user input 总条数。
  int inputCount;

  Map<String, Object?> toJson() => {
        'days': days,
        if (reportMarkdown != null) 'report_markdown': reportMarkdown,
        if (generatedAt != null) 'generated_at': generatedAt!.toIso8601String(),
        'input_count': inputCount,
      };

  factory UserInputSummaryCache.fromJson(Map<String, Object?> json) {
    return UserInputSummaryCache(
      days: json['days'] as int? ?? 30,
      reportMarkdown: json['report_markdown'] as String?,
      generatedAt: _parseDate(json['generated_at']),
      inputCount: (json['input_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// 缓存是否仍然有效（已生成报告，且生成时间不超过 1 小时）。
  bool get isValid {
    if (reportMarkdown == null || generatedAt == null) return false;
    return DateTime.now().toUtc().difference(generatedAt!) <
        const Duration(hours: 1);
  }
}

/// 用户输入总结的持久化存储。
///
/// 文件路径：`<rootDir>/user_input_summary.json`
class UserInputSummaryStorage {
  UserInputSummaryStorage({required this.rootDir});

  final String rootDir;

  String get _filePath => p.join(rootDir, 'user_input_summary.json');

  /// 读取指定天数的缓存。文件不存在或解析失败时返回空缓存。
  Future<UserInputSummaryCache> read(int days) async {
    final file = File(_filePath);
    if (!await file.exists()) {
      return UserInputSummaryCache(days: days);
    }
    try {
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return UserInputSummaryCache(days: days);
      }
      final cache =
          UserInputSummaryCache.fromJson(Map<String, Object?>.from(decoded));
      // 只返回同天数的缓存
      if (cache.days != days) {
        return UserInputSummaryCache(days: days);
      }
      return cache;
    } catch (_) {
      return UserInputSummaryCache(days: days);
    }
  }

  /// 写入缓存（原子写入）。
  Future<void> write(UserInputSummaryCache cache) async {
    cache.generatedAt = DateTime.now().toUtc();
    final encoder = const JsonEncoder.withIndent('  ');
    await KeywordStorageUtils.atomicWriteString(
      _filePath,
      encoder.convert(cache.toJson()),
    );
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
