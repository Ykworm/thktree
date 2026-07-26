import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/keyword_analysis_storage.dart';
import 'package:thk_tree/data/services/keyword_category_storage.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/services/llm_prompts.dart';

/// Prompt A 抽取结果。
///
/// [keywords]：通过合规校验的关键词条目（已映射到 catalog 中的真实 id）。
/// 当 [pendingNewCategory] 非空时，其中**部分 keyword 的 category_id 仍等于**
/// [KeywordExtractionService.newCategoryMarker]（等待调用方分配新 id 后替换）。
///
/// [pendingNewCategory]：LLM 声明的新分类（不含 id），由调用方调用
/// [KeywordCategoryStorage.addLlmCategory] 拿到新 id 后回填。
class KeywordExtractionResult {
  const KeywordExtractionResult({
    required this.keywords,
    this.pendingNewCategory,
  });

  final List<KeywordEntry> keywords;
  final PendingNewCategory? pendingNewCategory;

  bool get hasPendingNewCategory =>
      pendingNewCategory != null ||
      keywords.any(
        (k) => k.categoryId == KeywordExtractionService.newCategoryMarker,
      );
}

/// LLM 输出的 new_category 临时表示（不含 id，由程序后续分配）。
class PendingNewCategory {
  const PendingNewCategory({
    required this.name,
    required this.aliases,
  });

  final String name;
  final List<String> aliases;
}

/// Prompt A 输出不符合 100% 合规校验时抛出的异常。
///
/// 整体拒绝策略：调用方应 catch 此异常 → 保留旧 data → UI banner 提示用户重试。
class KeywordExtractionException implements Exception {
  const KeywordExtractionException(this.message);

  final String message;

  @override
  String toString() => 'KeywordExtractionException: $message';
}

/// 关键词抽取服务（Prompt A）。
///
/// 内部统一通过 [LlmClient.streamChatCompletion] 调用 LLM，stream 关闭后
/// 返回经 100% 合规校验的 [KeywordExtractionResult]。所有方法都是纯函数式，
/// 不持有任何状态；无状态使得可在 Riverpod 中按需多次调用而无需缓存管理。
///
/// **设计约束**：
/// - System Prompt 与 user prompt schema **固定**，用户不可编辑（参见设计文档 § 4.1）。
/// - 输入：[KeywordCategoryCatalogFile]（用于校验 category_id）+ chat title + chat content。
/// - 校验：keywords 1-5 个、category_id 全部在 catalog 中、
///   new_category 最多 1 个（允许 null）、marker 一致性。
/// - 整体拒绝策略：任何不合规项都抛出 [KeywordExtractionException]，由调用方降级。
class KeywordExtractionService {
  KeywordExtractionService();

  /// Prompt 中 new_category 对应 keyword 的 category_id 占位值。
  ///
  /// 当 LLM 在 keywords 中某个条目的 category_id 写此值时，表示该 keyword 引用
  /// 同一输出中的 new_category。**真实 id 由 catalog.addLlmCategory 分配**，
  /// 分配后调用方应把 marker 替换为新 id 再写入 leaf。
  static const String newCategoryMarker = '__NEW_CATEGORY__';

  /// 抽取关键词（Prompt A 入口）。
  ///
  /// [chatTitle]：chat 节点标题，作为上下文辅助。
  /// [chatContent]：chat 完整 markdown 内容（建议先做长度截断）。
  /// [catalog]：当前全局 catalog，用于校验 category_id 是否在集合内。
  /// [provider] / [modelId] / [apiKey] / [contextWindow]：LLM 调用参数，与 TitleSuggestionService 一致。
  ///
  /// 返回通过 100% 合规校验的 [KeywordExtractionResult]。
  /// 任何不合规（JSON 解析、字段缺失、category_id 不在 catalog 中、new_category 数量不一致等）
  /// 都抛出 [KeywordExtractionException]，调用方应整体拒绝并保留旧 data。
  Future<KeywordExtractionResult> extract({
    required String chatTitle,
    required String chatContent,
    required KeywordCategoryCatalogFile catalog,
    required String languageCode,
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    required int contextWindow,
    CancelToken? cancelToken,
  }) async {
    final client = LlmClient.forConfig(provider, model: modelId);
    final catalogJson = jsonEncode(_buildCatalogJson(catalog));

    final messages = <Map<String, Object?>>[
      {
        'role': 'system',
        'content': LlmPrompts.keywordExtractionSystemPrompt(languageCode),
      },
      {
        'role': 'user',
        'content': LlmPrompts.keywordExtractionUserPrompt(
          languageCode: languageCode,
          catalogJson: catalogJson,
          chatTitle: chatTitle,
          chatContent: chatContent,
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
    return parseResponse(buffer.toString(), catalog);
  }

  /// 把 catalog 转成 LLM 友好的精简 JSON：只暴露 id / name / aliases。
  ///
  /// 不暴露 source / added_at 等内部字段，避免给 LLM 增加噪声。
  static List<Map<String, Object?>> _buildCatalogJson(
    KeywordCategoryCatalogFile catalog,
  ) {
    return catalog.categories.values
        .map((c) => <String, Object?>{
              'id': c.id,
              'name': c.name,
              'aliases': c.aliases,
            })
        .toList(growable: false);
  }

  /// 把 catalog 转成 LLM 友好的精简 JSON：只暴露 id / name / aliases。
  ///
  /// 清洗顺序：
  /// 1. 去除首尾空白
  /// 2. 去除 markdown ```json ... ``` 代码块包裹
  /// 3. 去除 思考标签（`qwen` 等模型会在输出前放推理过程）
  /// 4. JSON 解析
  ///
  /// 校验项：
  /// - 根必须是 JSON 对象（`{"keywords": [...], "new_category": ...}`）
  /// - `keywords` 存在、是数组、长度 ∈ [1, 5]
  /// - 每个 keyword 是对象、`keyword` 非空、`category_id` 非空
  /// - `category_id` ∈ catalog ids **或** 等于 [newCategoryMarker]
  /// - `new_category` 是 null 或对象，且至多 1 个
  /// - **marker 一致性**：如果存在 marker，new_category 必须非空且是 1 个；
  ///   反之声明了 new_category，至少要有 1 个 marker。
  KeywordExtractionResult parseResponse(
    String raw,
    KeywordCategoryCatalogFile catalog,
  ) {
    final cleaned = _stripMarkdownCodeBlock(
      _stripThinkTags(raw),
    ).trim();

    Object? decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      throw const KeywordExtractionException('输出格式错误：JSON 解析失败');
    }
    if (decoded is! Map) {
      throw const KeywordExtractionException('输出格式错误：根必须是 JSON 对象');
    }
    final obj = decoded;

    final keywordsRaw = obj['keywords'];
    if (keywordsRaw is! List) {
      throw const KeywordExtractionException('输出格式错误：keywords 必须是列表');
    }

    // 校验：keywords 数量 1-5
    if (keywordsRaw.isEmpty || keywordsRaw.length > 5) {
      throw KeywordExtractionException(
        '输出格式错误：keywords 数量 ${keywordsRaw.length} 不在 1-5 范围',
      );
    }

    // 校验：每个 keyword 字段完整性 + category_id 在 catalog 中
    final validIds = catalog.categories.keys.toSet();
    final keywords = <KeywordEntry>[];
    var markerCount = 0;
    for (final item in keywordsRaw) {
      if (item is! Map) {
        throw const KeywordExtractionException('输出格式错误：keyword 必须是对象');
      }
      final keywordText = (item['keyword'] as Object?)?.toString().trim() ?? '';
      final categoryIdRaw = (item['category_id'] as Object?)?.toString().trim() ?? '';
      if (keywordText.isEmpty) {
        throw const KeywordExtractionException('输出格式错误：keyword 不能为空');
      }
      if (categoryIdRaw.isEmpty) {
        throw const KeywordExtractionException('输出格式错误：category_id 不能为空');
      }
      if (categoryIdRaw == newCategoryMarker) {
        markerCount++;
      } else if (!validIds.contains(categoryIdRaw)) {
        throw KeywordExtractionException(
          '输出格式错误：category_id=$categoryIdRaw 不在 catalog 中',
        );
      }
      keywords.add(KeywordEntry(keyword: keywordText, categoryId: categoryIdRaw));
    }

    // 校验：new_category 至多 1 个 + marker 一致性
    final newCategoryRaw = obj['new_category'];
    PendingNewCategory? pendingNewCategory;
    if (newCategoryRaw == null) {
      if (markerCount > 0) {
        throw const KeywordExtractionException(
          '输出格式错误：keyword 引用了新分类但未声明 new_category',
        );
      }
    } else if (newCategoryRaw is Map) {
      if (markerCount == 0) {
        throw const KeywordExtractionException(
          '输出格式错误：声明了 new_category 但 keyword 都没引用',
        );
      }
      final name = (newCategoryRaw['name'] as Object?)?.toString().trim() ?? '';
      final aliasesRaw = newCategoryRaw['aliases'];
      final aliases = aliasesRaw is List
          ? aliasesRaw
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList(growable: false)
          : const <String>[];
      if (name.isEmpty) {
        throw const KeywordExtractionException('输出格式错误：new_category.name 不能为空');
      }
      pendingNewCategory = PendingNewCategory(name: name, aliases: aliases);
    } else {
      throw const KeywordExtractionException(
        '输出格式错误：new_category 必须是对象或 null',
      );
    }

    return KeywordExtractionResult(
      keywords: keywords,
      pendingNewCategory: pendingNewCategory,
    );
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
