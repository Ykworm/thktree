import 'package:dio/dio.dart';

import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/llm_client.dart';

/// 标题命名 / 对话总结服务。
///
/// 内部统一通过 [LlmClient.streamChatCompletion] 调用 LLM，stream 关闭后
/// 返回完整文本结果。两个方法都是纯函数式，不持有任何状态。
class TitleSuggestionService {
  TitleSuggestionService._();

  static const _titleSystemPrompt = '''
你是一个标题命名助手。根据用户给定的内容（含可选方向引导），生成适合作为新对话标题的候选列表。

要求：
1. 候选数量由你根据内容复杂度自行判断（1~20 个），内容越丰富/分支越多可以多给几个。
2. 每个标题必须控制在 30 个字符以内（中文按字数、英文按字符数）。
3. 标题要简洁、聚焦、信息密度高，能让用户一眼看出新对话的主题或切入角度。
4. 严格按"每行一个标题"输出，不要带编号、不要带引号、不要带任何额外说明文字。
5. 输出语言与用户给定的内容保持一致。''';

  static const _summarySystemPrompt = '''
你是一个对话总结助手。给定一段用户与助手的完整对话，请生成一段简洁的总结，
作为新对话的上下文起点。要求：
1. 保留对话中讨论的关键事实、结论、术语、决定。
2. 控制在合理篇幅（一般 300~800 字），语言简洁清晰，不要冗长。
3. 不要添加原对话中没有的信息，不要替用户做判断。
4. 使用与对话相同的语言输出。''';

  /// 生成 1-20 个候选 title。
  ///
  /// [content] 是用于生成标题的原始内容（选中文本 / 笔记 / 对话总结等）。
  /// [direction] 是可选的方向引导，例如"更聚焦技术实现"。
  /// 关闭 stream 后按行解析，filter 空行 / 超长行，上限 20 个。
  static Future<List<String>> generateTitles({
    required String content,
    String? direction,
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    CancelToken? cancelToken,
  }) async {
    final client = LlmClient.forConfig(provider);
    final messages = <Map<String, Object?>>[
      {'role': 'system', 'content': _titleSystemPrompt},
      {
        'role': 'user',
        'content': _buildTitleUserPrompt(content: content, direction: direction),
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
      buffer.write(delta);
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
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    CancelToken? cancelToken,
  }) async {
    final client = LlmClient.forConfig(provider);
    final messages = <Map<String, Object?>>[
      {'role': 'system', 'content': _summarySystemPrompt},
      {
        'role': 'user',
        'content': '请总结以下对话：\n\n---\n$transcript',
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
      buffer.write(delta);
    }
    return buffer.toString().trim();
  }

  /// 解析 LLM 返回的 title 文本：
  /// trim → 按行切 → 过滤空行 → 过滤超过 30 字符的 → 上限 20 个。
  static List<String> parseResponse(String raw) {
    final result = <String>[];
    for (final line in raw.split('\n')) {
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

  static String _buildTitleUserPrompt({
    required String content,
    String? direction,
  }) {
    final buf = StringBuffer();
    buf.writeln('请基于以下内容生成候选标题：');
    buf.writeln();
    buf.writeln('---');
    buf.writeln(content);
    buf.writeln('---');
    if (direction != null && direction.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('方向引导：${direction.trim()}');
    }
    return buf.toString();
  }
}
