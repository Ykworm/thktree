import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/keyword_global_storage.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/services/llm_prompts.dart';

/// Prompt B 输入：程序预计算的某个 unique keyword 的跨域统计字段。
///
/// Prompt B 不会改写这些字段，只对 [KeywordAggregationService.aggregate] 返回的
/// 输出做 100% 一致性校验，确保 LLM 把这些统计原样输出。
class ScoreAggregationInput {
  const ScoreAggregationInput({
    required this.keyword,
    required this.categoryId,
    required this.crossThemeCount,
    required this.crossLeafCount,
    required this.depthAvg,
    required this.staleRatio,
  });

  final String keyword;
  final String categoryId;
  final int crossThemeCount;
  final int crossLeafCount;
  final double depthAvg;
  final double staleRatio;

  Map<String, Object?> toJson() => <String, Object?>{
        'keyword': keyword,
        'category_id': categoryId,
        'cross_theme_count': crossThemeCount,
        'cross_leaf_count': crossLeafCount,
        'depth_avg': depthAvg,
        'stale_ratio': staleRatio,
      };
}

/// Prompt B 任意不合规项抛出的异常（整体拒绝策略，UI banner 兜底）。
class KeywordAggregationException implements Exception {
  const KeywordAggregationException(this.message);

  final String message;

  @override
  String toString() => 'KeywordAggregationException: $message';
}

/// Prompt B 聚合 + score 计算服务。
///
/// 设计文档 § 4.2 + § 4.3：
/// - 输入：unique keywords（每个含程序预计算的统计字段）+ 用户 score prompt
/// - 输出：JSON 数组，每个元素含 6 字段（含 score 0.0-1.0）
/// - 100% 合规校验：8 步骤（详见 [parseResponse]）
/// - 整体拒绝：任意不匹配都抛出 [KeywordAggregationException]，由调用方降级
///
/// service 本身无状态（注入 LLM 配置即可），因此可在 Riverpod 中注册单例。
class KeywordAggregationService {
  KeywordAggregationService();

  /// 聚合 unique keywords 并计算每个的 score。
  ///
  /// [inputs] 必填且非空；[scorePrompt] 用作 LLM 评判 score 的逻辑。
  /// 任意不合规输出都抛出 [KeywordAggregationException]，调用方应保留旧 score 并
  /// UI 提示用户重试。
  Future<List<GlobalKeywordEntry>> aggregate({
    required List<ScoreAggregationInput> inputs,
    required String scorePrompt,
    required String languageCode,
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    required int contextWindow,
    CancelToken? cancelToken,
  }) async {
    if (inputs.isEmpty) return const [];

    final client = LlmClient.forConfig(provider, model: modelId);
    final systemPrompt = LlmPrompts.keywordAggregationSystemPrefix(languageCode) +
        scorePrompt +
        LlmPrompts.keywordAggregationSystemSuffix(languageCode);
    final inputJson = jsonEncode(inputs.map((i) => i.toJson()).toList());

    final messages = <Map<String, Object?>>[
      {'role': 'system', 'content': systemPrompt},
      {
        'role': 'user',
        'content': LlmPrompts.keywordAggregationUserPrompt(
          languageCode: languageCode,
          inputJson: inputJson,
        ),
      },
    ];

    final buffer = StringBuffer();
    final stream = client.streamChatCompletion(
      apiKey: apiKey,
      model: modelId,
      messages: messages,
      cancelToken: cancelToken,
    );
    await for (final delta in stream) {
      buffer.write(delta.content);
    }
    return parseResponse(buffer.toString(), inputs);
  }

  /// 解析 Prompt B 输出并执行 100% 合规校验（8 步骤）。
  ///
  /// 步骤（与设计文档 § 4.3 完全对齐）：
  /// 1. JSON 解析（去 思考标签、markdown 代码块）
  /// 2. 必须是 JSON 数组
  /// 3. 数组非空
  /// 4. 输出数量 = 输入数量（`inputs.length`）
  /// 5. 每个元素含 6 字段（keyword / cross_theme_count / cross_leaf_count / depth_avg / stale_ratio / score）
  /// 6. keyword 非空 + 唯一 + 在输入集合中
  /// 7. 统计字段一致：cross_* 严格整数、depth_* 浮点容差 < 1e-6
  /// 8. score clamp 至 [0.0, 1.0]（超界自动修正，不抛异常）
  ///
  /// 返回值：`List<GlobalKeywordEntry>`，顺序**严格对齐 [inputs]**（按 keyword 索引对应）。
  List<GlobalKeywordEntry> parseResponse(
    String raw,
    List<ScoreAggregationInput> inputs,
  ) {
    final cleaned = _stripMarkdownCodeBlock(_stripThinkTags(raw)).trim();

    Object? decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      throw const KeywordAggregationException('输出格式错误：JSON 解析失败');
    }
    if (decoded is! List) {
      throw const KeywordAggregationException('输出格式错误：根必须是 JSON 数组');
    }
    final list = decoded;

    // 步骤 3：数组非空
    if (list.isEmpty) {
      throw const KeywordAggregationException('输出格式错误：数组为空');
    }

    // 步骤 4：数量匹配
    if (list.length != inputs.length) {
      throw KeywordAggregationException(
        '输出数量不匹配：期望 ${inputs.length}，得到 ${list.length}',
      );
    }

    final inputByKeyword = <String, ScoreAggregationInput>{
      for (final i in inputs) i.keyword: i,
    };
    final seenKeywords = <String>{};
    const requiredFields = <String>[
      'keyword',
      'cross_theme_count',
      'cross_leaf_count',
      'depth_avg',
      'stale_ratio',
      'score',
    ];

    final result = <GlobalKeywordEntry>[];
    for (var i = 0; i < list.length; i++) {
      final raw = list[i];
      if (raw is! Map) {
        throw KeywordAggregationException('输出格式错误：第 $i 项不是对象');
      }

      // 步骤 5：字段完整性
      for (final f in requiredFields) {
        if (!raw.containsKey(f)) {
          throw KeywordAggregationException('输出字段不完整：第 $i 项缺少 $f');
        }
      }

      // 步骤 6：keyword 非空 + 在输入集合中 + 唯一
      final keyword = raw['keyword']?.toString() ?? '';
      if (keyword.isEmpty) {
        throw const KeywordAggregationException('关键词不匹配：keyword 为空');
      }
      if (seenKeywords.contains(keyword)) {
        throw KeywordAggregationException('关键词不匹配：keyword 重复（$keyword）');
      }
      final input = inputByKeyword[keyword];
      if (input == null) {
        throw KeywordAggregationException(
          '关键词不匹配：$keyword 不在输入集合中',
        );
      }
      seenKeywords.add(keyword);

      // 步骤 7：统计字段一致性（先整数后浮点，顺序固定以便上层定位问题）
      final outCrossTheme = _readInt(raw, 'cross_theme_count');
      final outCrossLeaf = _readInt(raw, 'cross_leaf_count');
      if (outCrossTheme != input.crossThemeCount ||
          outCrossLeaf != input.crossLeafCount) {
        throw KeywordAggregationException(
          '统计字段不一致：$keyword 期望 cross_theme=${input.crossThemeCount}/'
          'cross_leaf=${input.crossLeafCount}，得到 $outCrossTheme/$outCrossLeaf',
        );
      }
      final outDepthAvg = _readDouble(raw, 'depth_avg');
      final outStaleRatio = _readDouble(raw, 'stale_ratio');
      if ((outDepthAvg - input.depthAvg).abs() > 1e-6 ||
          (outStaleRatio - input.staleRatio).abs() > 1e-6) {
        throw KeywordAggregationException(
          '统计字段不一致：$keyword depth_avg/stale_ratio 与输入不匹配 '
          '(输入=${input.depthAvg}/${input.staleRatio}, 输出=$outDepthAvg/$outStaleRatio)',
        );
      }

      // 步骤 8：score clamp（不抛异常，直接修正）
      final rawScore = _readDouble(raw, 'score');
      final clampedScore = rawScore.clamp(0.0, 1.0);

      result.add(
        GlobalKeywordEntry(
          keyword: keyword,
          categoryId: input.categoryId,
          crossThemeCount: outCrossTheme,
          crossLeafCount: outCrossLeaf,
          depthAvg: outDepthAvg,
          staleRatio: outStaleRatio,
          score: clampedScore,
        ),
      );
    }

    return result;
  }

  /// 字段读取：必须是 int 或可解析为 int 的字符串或小数（不能有小数部分）。
  int _readInt(Map<dynamic, dynamic> raw, String field) {
    final value = raw[field];
    if (value is int) return value;
    if (value is double) {
      final rounded = value.round();
      if ((value - rounded).abs() < 1e-9) return rounded;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw KeywordAggregationException('统计字段不一致：$field 不是整数（实际类型 ${value.runtimeType}）');
  }

  /// 字段读取：必须是 num 或可解析为 double 的字符串。
  double _readDouble(Map<dynamic, dynamic> raw, String field) {
    final value = raw[field];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw KeywordAggregationException('统计字段不一致：$field 不是数字（实际类型 ${value.runtimeType}）');
  }

  /// 去掉首尾的 markdown ```json ... ``` / ``` ... ``` 代码块。
  static String _stripMarkdownCodeBlock(String raw) {
    final trimmed = raw.trim();
    final pattern = RegExp(
      r'^```(?:json|JSON)?\s*\n?(.*?)\n?```\s*$',
      dotAll: true,
    );
    final match = pattern.firstMatch(trimmed);
    if (match != null) return match.group(1)!.trim();
    return trimmed;
  }

  /// 去掉 `qwen` / `deepseek` 等推理模型可能在内容前后输出的
  /// `qn...qn` 思考标签（成对或单边开 tag）。
  static String _stripThinkTags(String raw) {
    var cleaned = raw.replaceAll(
      RegExp(r'qn[\s\S]*?qn', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'qn[\s\S]*$', caseSensitive: false),
      '',
    );
    return cleaned.trim();
  }
}
