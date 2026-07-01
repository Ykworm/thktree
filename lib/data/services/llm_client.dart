import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:thk_tree/data/models/llm_provider_config.dart';

abstract class LlmClient {
  const LlmClient();

  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
  });

  /// 根据 LlmProviderConfig 创建客户端实例。
  ///
  /// 对于 OpenAI 兼容的提供商（包括 custom），使用 [ConfigBasedOpenAiCompatibleClient]；
  /// 对于 anthropic 类型使用 [ClaudeClient]；
  /// 对于 gemini 类型使用 [GeminiClient]。
  factory LlmClient.forConfig(LlmProviderConfig config) {
    if (config.isOpenAiCompatible) {
      return ConfigBasedOpenAiCompatibleClient(
        baseUrl: config.baseUrl,
        providerName: config.name,
      );
    }
    switch (config.type) {
      case LlmProviderType.anthropic:
        return ClaudeClient.withBaseUrl(config.baseUrl);
      case LlmProviderType.gemini:
        return GeminiClient.withBaseUrl(config.baseUrl);
      default:
        // Fallback: 作为 OpenAI 兼容处理
        return ConfigBasedOpenAiCompatibleClient(
          baseUrl: config.baseUrl,
          providerName: config.name,
        );
    }
  }
}

class LlmResponseDelta {
  const LlmResponseDelta({
    this.content = '',
    this.reasoning = '',
  });

  final String content;
  final String reasoning;

  bool get isEmpty => content.isEmpty && reasoning.isEmpty;
}

/// 基于 LlmProviderConfig 的 OpenAI 兼容客户端，
/// 可支持任意 baseUrl。
class ConfigBasedOpenAiCompatibleClient extends LlmClient {
  ConfigBasedOpenAiCompatibleClient({
    required this.baseUrl,
    required this.providerName,
  });

  final String baseUrl;
  final String providerName;

  @override
  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
  }) async* {
    final dio = Dio(BaseOptions(baseUrl: baseUrl));
    final response = await dio.post<ResponseBody>(
      '/chat/completions',
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
      ),
      data: {
        'model': model,
        'stream': true,
        'messages': messages,
      },
    );

    final body = response.data;
    if (body == null) {
      throw StateError('Empty response body');
    }

    final stream = body.stream.cast<List<int>>().transform(utf8.decoder);
    final buffer = StringBuffer();

    await for (final chunk in stream) {
      buffer.write(chunk);
      while (true) {
        final text = buffer.toString();
        final idx = text.indexOf('\n\n');
        if (idx < 0) break;
        final event = text.substring(0, idx);
        final rest = text.substring(idx + 2);
        buffer
          ..clear()
          ..write(rest);

        for (final line in event.split('\n')) {
          final trimmed = line.trimRight();
          if (trimmed.isEmpty) continue;
          if (trimmed.startsWith(':')) continue;
          if (!trimmed.startsWith('data:')) continue;
          final data = trimmed.substring('data:'.length).trimLeft();
          if (data == '[DONE]') {
            return;
          }
          final delta = _extractDelta(data);
          if (delta != null && !delta.isEmpty) {
            yield delta;
          }
        }
      }
    }
  }
}

class ClaudeClient extends LlmClient {
  const ClaudeClient({this.baseUrl});

  /// 可选的自定义 baseUrl，为 null 时使用默认值
  final String? baseUrl;

  /// 带自定义 baseUrl 的构造函数
  const ClaudeClient.withBaseUrl(this.baseUrl);

  @override
  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
  }) async* {
    final dio = Dio(BaseOptions(baseUrl: baseUrl ?? 'https://api.anthropic.com/v1'));

    final systemMessages = <Map<String, Object?>>[];
    final userAssistantMessages = <Map<String, Object?>>[];

    for (final msg in messages) {
      final role = msg['role'] as String?;
      if (role == 'system') {
        systemMessages.add(msg);
      } else {
        userAssistantMessages.add(msg);
      }
    }

    final bodyData = <String, Object?>{
      'model': model,
      'stream': true,
      'max_tokens': 4096,
      'messages': userAssistantMessages,
    };

    if (systemMessages.isNotEmpty) {
      bodyData['system'] = systemMessages.map((m) => m['content']).join('\n');
    }

    final response = await dio.post<ResponseBody>(
      '/messages',
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
      ),
      data: bodyData,
    );

    final body = response.data;
    if (body == null) {
      throw StateError('Empty response body');
    }

    final stream = body.stream.cast<List<int>>().transform(utf8.decoder);
    final buffer = StringBuffer();

    await for (final chunk in stream) {
      buffer.write(chunk);
      while (true) {
        final text = buffer.toString();
        final idx = text.indexOf('\n\n');
        if (idx < 0) break;
        final event = text.substring(0, idx);
        final rest = text.substring(idx + 2);
        buffer
          ..clear()
          ..write(rest);

        for (final line in event.split('\n')) {
          if (!line.startsWith('data:')) continue;
          final data = line.substring('data:'.length).trimLeft();
          final delta = _extractClaudeDelta(data);
          if (delta != null && !delta.isEmpty) {
            yield delta;
          }
        }
      }
    }
  }
}

class GeminiClient extends LlmClient {
  const GeminiClient({this.baseUrl});

  /// 可选的自定义 baseUrl，为 null 时使用默认值
  final String? baseUrl;

  /// 带自定义 baseUrl 的构造函数
  const GeminiClient.withBaseUrl(this.baseUrl);

  @override
  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
  }) async* {
    final dio = Dio(BaseOptions(baseUrl: baseUrl ?? 'https://generativelanguage.googleapis.com/v1beta'));

    final contents = <Map<String, Object?>>[];
    for (final msg in messages) {
      final role = msg['role'] as String?;
      final content = msg['content'] as String? ?? '';
      final geminiRole = role == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': geminiRole,
        'parts': [
          {'text': content},
        ],
      });
    }

    final response = await dio.post<ResponseBody>(
      '/models/$model:streamGenerateContent?alt=sse&key=$apiKey',
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Content-Type': 'application/json'},
      ),
      data: {
        'contents': contents,
      },
    );

    final body = response.data;
    if (body == null) {
      throw StateError('Empty response body');
    }

    final stream = body.stream.cast<List<int>>().transform(utf8.decoder);
    final buffer = StringBuffer();

    await for (final chunk in stream) {
      buffer.write(chunk);
      while (true) {
        final text = buffer.toString();
        final idx = text.indexOf('\n\n');
        if (idx < 0) break;
        final event = text.substring(0, idx);
        final rest = text.substring(idx + 2);
        buffer
          ..clear()
          ..write(rest);

        for (final line in event.split('\n')) {
          if (!line.startsWith('data:')) continue;
          final data = line.substring('data:'.length).trimLeft();
          final delta = _extractGeminiDelta(data);
          if (delta != null && !delta.isEmpty) {
            yield delta;
          }
        }
      }
    }
  }
}

LlmResponseDelta? _extractDelta(String jsonLine) {
  try {
    final decoded = jsonDecode(jsonLine);
    if (decoded is! Map) return null;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final choice0 = choices.first;
    if (choice0 is! Map) return null;
    final delta = choice0['delta'];
    if (delta is! Map) return null;
    return LlmResponseDelta(
      content: _extractTextField(delta['content']),
      reasoning: _extractTextField(
        delta['reasoning_content'] ?? delta['reasoning'],
      ),
    );
  } catch (_) {
    return null;
  }
}

LlmResponseDelta? _extractClaudeDelta(String jsonLine) {
  try {
    final decoded = jsonDecode(jsonLine);
    if (decoded is! Map) return null;
    final type = decoded['type'] as String?;
    if (type == 'content_block_delta') {
      final delta = decoded['delta'];
      if (delta is Map) {
        final text = delta['text'] as String?;
        if (text != null && text.isNotEmpty) {
          return LlmResponseDelta(content: text);
        }
      }
    }
    if (type == 'content_block_start') {
      final block = decoded['content_block'];
      if (block is Map) {
        final text = block['text'] as String?;
        if (text != null && text.isNotEmpty) {
          return LlmResponseDelta(content: text);
        }
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}

LlmResponseDelta? _extractGeminiDelta(String jsonLine) {
  try {
    final decoded = jsonDecode(jsonLine);
    if (decoded is! Map) return null;
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final candidate = candidates.first;
    if (candidate is! Map) return null;
    final content = candidate['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;
    final part = parts.first;
    if (part is! Map) return null;
    final text = part['text'] as String?;
    if (text == null || text.isEmpty) return null;
    return LlmResponseDelta(content: text);
  } catch (_) {
    return null;
  }
}

String _extractTextField(Object? value) {
  if (value is String) return value;
  if (value is List) {
    return value
        .map((item) {
          if (item is String) return item;
          if (item is Map) {
            final text = item['text'];
            if (text is String) return text;
          }
          return '';
        })
        .join();
  }
  return '';
}
