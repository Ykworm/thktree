import 'package:dio/dio.dart';

import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/services/llm_prompts.dart';

/// 标题命名 / 对话总结服务。
///
/// 内部统一通过 [LlmClient.streamChatCompletion] 调用 LLM，stream 关闭后
/// 返回完整文本结果。两个方法都是纯函数式，不持有任何状态。
class TitleSuggestionService {
  TitleSuggestionService._();

  /// 估算文本的 token 数量
  ///
  /// 根据文本中的 CJK 字符占比选择不同的估算比例：
  /// - CJK 字符占比 > 30%：按 chars / 1.5 估算（中文 1-2 字 ≈ 1 token）
  /// - CJK 字符占比 < 30%：按 chars / 4 估算（英文 ~4 chars ≈ 1 token）
  /// - 混合文本：按比例加权
  static int _estimateTokens(String text) {
    if (text.isEmpty) return 0;

    // 统计 CJK 字符数量（Unicode range \u4E00-\u9FFF 及扩展区）
    int cjkCount = 0;
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      // CJK Unified Ideographs: 4E00-9FFF
      // CJK Unified Ideographs Extension A: 3400-4DBF
      // CJK Compatibility Ideographs: F900-FAFF
      if ((codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||
          (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) ||
          (codeUnit >= 0xF900 && codeUnit <= 0xFAFF)) {
        cjkCount++;
      }
    }

    final totalChars = text.length;
    final cjkRatio = cjkCount / totalChars;

    // 根据 CJK 占比选择估算比例
    if (cjkRatio > 0.3) {
      // 中文主导：chars / 1.5
      return (totalChars / 1.5).round();
    } else if (cjkRatio < 0.3) {
      // 英文主导：chars / 4
      return (totalChars / 4).round();
    } else {
      // 混合文本：按比例加权
      final cjkTokens = (cjkCount / 1.5).round();
      final nonCjkTokens = ((totalChars - cjkCount) / 4).round();
      return cjkTokens + nonCjkTokens;
    }
  }

  /// 按消息边界截断对话内容，使其不超过模型 context window 的 90%
  ///
  /// [transcript] 是完整的对话文本（Markdown 格式，包含 ## user / ## assistant 分隔符）
  /// [contextWindow] 是模型的上下文窗口大小（tokens）
  ///
  /// 策略：
  /// 1. 如果总 token 数 <= contextWindow * 0.9，不截断
  /// 2. 否则从尾部按消息边界向前裁剪，直到总 token 落在 90% 内
  /// 3. 如果裁完仍超（单条消息本身过长），直接砍掉最早 20% 的消息
  /// 4. 裁剪后在开头插入标记
  static String _truncateByMessages(
    String transcript,
    int contextWindow,
    String languageCode,
  ) {
    if (transcript.isEmpty) return transcript;

    // 如果 context window 未知（0），使用保守默认值 32K
    final effectiveContextWindow = contextWindow > 0 ? contextWindow : 32000;
    final maxTokens = (effectiveContextWindow * 0.9).round();

    final totalTokens = _estimateTokens(transcript);
    if (totalTokens <= maxTokens) {
      return transcript;
    }

    // 按消息边界分割（## user 或 ## assistant）
    final messagePattern = RegExp(r'^## (user|assistant) ·', multiLine: true);
    final messageBoundaries = <int>[];

    for (final match in messagePattern.allMatches(transcript)) {
      messageBoundaries.add(match.start);
    }

    // 如果找不到消息边界，直接截断尾部
    if (messageBoundaries.isEmpty) {
      final truncatedLength = (transcript.length * maxTokens / totalTokens).round();
      return '${transcript.substring(0, truncatedLength)}${LlmPrompts.truncatedContentSuffix(languageCode)}';
    }

    // 从尾部向前裁剪消息
    int currentEnd = transcript.length;
    int currentTokens = totalTokens;

    for (int i = messageBoundaries.length - 1; i >= 0 && currentTokens > maxTokens; i--) {
      final messageStart = messageBoundaries[i];
      final messageEnd = (i < messageBoundaries.length - 1)
          ? messageBoundaries[i + 1]
          : transcript.length;
      final messageContent = transcript.substring(messageStart, messageEnd);
      final messageTokens = _estimateTokens(messageContent);

      currentTokens -= messageTokens;
      currentEnd = messageStart;
    }

    String truncated = transcript.substring(0, currentEnd);

    // 兜底：如果还是超了（单条消息过长），砍掉最早 20% 的消息
    if (_estimateTokens(truncated) > maxTokens && messageBoundaries.length > 1) {
      final cutCount = (messageBoundaries.length * 0.2).ceil();
      if (cutCount < messageBoundaries.length) {
        truncated = transcript.substring(messageBoundaries[cutCount]);
      }
    }

    return '${LlmPrompts.truncatedTranscriptPrefix(languageCode)}$truncated';
  }

  /// 生成 1-20 个候选 title。
  ///
  /// [content] 是用于生成标题的原始内容（选中文本 / 笔记 / 对话总结等）。
  /// [direction] 是可选的方向引导，例如"更聚焦技术实现"。
  /// [languageCode] 决定 system/user prompt 语言（`en` / `zh`）。
  /// 关闭 stream 后按行解析，filter 空行 / 超长行，上限 20 个。
  static Future<List<String>> generateTitles({
    required String content,
    String? direction,
    required String languageCode,
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    required int contextWindow,
    CancelToken? cancelToken,
  }) async {
    final client = LlmClient.forConfig(provider, model: modelId);

    // 对内容应用截断（如果超长）
    final truncatedContent = _truncateByMessages(content, contextWindow, languageCode);

    final messages = <Map<String, Object?>>[
      {'role': 'system', 'content': LlmPrompts.titleSystemPrompt(languageCode)},
      {
        'role': 'user',
        'content': LlmPrompts.titleUserPrompt(
          languageCode: languageCode,
          content: truncatedContent,
          direction: direction,
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
    return parseResponse(buffer.toString());
  }

  /// 对一段对话 transcript 做总结，返回纯文本 summary。
  ///
  /// 用于"无选中文本创建分支"场景：让 LLM 先生成一段对话总结，
  /// 后续作为 [TitleSuggestionScreen] 的 source content，并写为
  /// 新 child chat node 的首条 user 消息。
  static Future<String> summarizeContent({
    required String transcript,
    required String languageCode,
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    required int contextWindow,
    CancelToken? cancelToken,
  }) async {
    final client = LlmClient.forConfig(provider, model: modelId);

    // 对对话内容应用截断（如果超长）
    final truncatedTranscript =
        _truncateByMessages(transcript, contextWindow, languageCode);

    final messages = <Map<String, Object?>>[
      {
        'role': 'system',
        'content': LlmPrompts.conversationSummarySystemPrompt(languageCode),
      },
      {
        'role': 'user',
        'content': LlmPrompts.conversationSummaryUserPrompt(
          languageCode: languageCode,
          transcript: truncatedTranscript,
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
    return buffer.toString().trim();
  }

  /// 解析 LLM 返回的 title 文本：
  /// strip `<think>` tags → trim → 按行切 → 过滤空行 → 过滤超过 30 字符的 → 上限 20 个。
  static List<String> parseResponse(String raw) {
    // 移除 `<think>` 标签及其内容（LLM 可能在 title 生成时返回推理过程）
    var cleaned = raw.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '');

    final result = <String>[];
    for (final line in cleaned.split('\n')) {
      var trimmed = line.trim();
      // 去掉常见的列表前缀：数字加点、"-"、"•"、Markdown 引用等
      if (trimmed.isEmpty) continue;
      if (RegExp(r'^\d+[.\)、]').hasMatch(trimmed)) {
        trimmed = trimmed.replaceFirst(RegExp(r'^\d+[.\)、]\s*'), '');
      }
      if (trimmed.startsWith('-') || trimmed.startsWith('•') || trimmed.startsWith('*')) {
        trimmed = trimmed.substring(1).trim();
      }
      // 去掉包裹的引号
      if (trimmed.length >= 2 &&
          ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
              (trimmed.startsWith('「') && trimmed.endsWith('」')) ||
              (trimmed.startsWith('『') && trimmed.endsWith('』')))) {
        trimmed = trimmed.substring(1, trimmed.length - 1).trim();
      }
      if (trimmed.isEmpty) continue;
      if (trimmed.length > 30) continue;
      if (result.contains(trimmed)) continue;
      result.add(trimmed);
      if (result.length >= 20) break;
    }
    return result;
  }
}
