import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:thk_tree/data/models/llm_provider_config.dart';

/// 多模态消息内容部分
class ContentPart {
  const ContentPart.text(this.text)
      : type = 'text',
        imageData = null,
        mimeType = null;

  const ContentPart.image(this.imageData, {this.mimeType = 'image/jpeg'})
      : type = 'image',
        text = null;

  final String type; // 'text' | 'image'
  final String? text;
  final Uint8List? imageData;
  final String? mimeType;
}

abstract class LlmClient {
  const LlmClient();

  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
    bool webSearch = false,
  });

  /// 构建多模态消息内容（支持文本+图片）
  ///
  /// 子类可覆盖此方法以适配不同 API 格式。
  /// 默认实现：OpenAI 兼容格式（content 为数组）。
  Object buildMultimodalContent({
    required String text,
    Uint8List? imageData,
    String? imageMimeType,
  }) {
    if (imageData == null) {
      return text;
    }

    final base64Image = base64Encode(imageData);
    final mimeType = imageMimeType ?? 'image/jpeg';

    return [
      {'type': 'text', 'text': text},
      {
        'type': 'image_url',
        'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
      },
    ];
  }

  /// 根据 LlmProviderConfig 创建客户端实例。
  ///
  /// 对于 OpenAI 兼容的提供商（包括 custom），使用 [ConfigBasedOpenAiCompatibleClient]；
  /// 对于 anthropic 类型使用 [ClaudeClient]；
  /// 对于 gemini 类型使用 [GeminiClient]。
  factory LlmClient.forConfig(
    LlmProviderConfig config, {
    bool webSearch = false,
  }) {
    dev.log(
      'LlmClient.forConfig: type=${config.type}, webSearch=$webSearch, baseUrl=${config.baseUrl}, name=${config.name}',
      name: 'llm_client',
    );
    // DeepSeek 联网搜索需要走 Anthropic 兼容接口
    if (config.type == LlmProviderType.deepseek && webSearch) {
      // 去掉可能的 /v1 后缀，再拼 /anthropic/v1
      var base = config.baseUrl;
      if (base.endsWith('/v1')) {
        base = base.substring(0, base.length - 3);
      }
      final url = '$base/anthropic/v1';
      dev.log('DeepSeek web search → ClaudeClient.withBaseUrl($url)', name: 'llm_client');
      return ClaudeClient.withBaseUrl(url);
    }
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

  /// 构建联网搜索的 tools 声明
  ///
  /// KIMI 使用 builtin_function.$web_search，其他使用 function web_search。
  List<Map<String, Object?>> _buildWebSearchTools() {
    if (providerName.toLowerCase().contains('kimi') ||
        providerName.toLowerCase().contains('moonshot')) {
      return [
        {
          'type': 'builtin_function',
          'function': {'name': r'$web_search'},
        },
      ];
    }
    return [
      {
        'type': 'function',
        'function': {
          'name': 'web_search',
          'description': 'Search the web for real-time information',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'The search query',
              },
            },
            'required': ['query'],
          },
        },
      },
    ];
  }

  @override
  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
    bool webSearch = false,
  }) async* {
    final currentMessages = List<Map<String, Object?>>.from(messages);
    final effectiveBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    dev.log(
      'streamChatCompletion: provider=$providerName, model=$model, webSearch=$webSearch, baseUrl=$effectiveBaseUrl',
      name: 'llm_client',
    );

    // 联网搜索可能触发多轮 tool_calls，最多循环 3 次
    const maxToolRounds = 3;
    for (var round = 0; round < maxToolRounds; round++) {
      final body = <String, Object?>{
        'model': model,
        'stream': true,
        'messages': currentMessages,
        if (webSearch) 'tools': _buildWebSearchTools(),
      };

      // KIMI 使用 $web_search 时必须禁用 thinking
      if (webSearch &&
          (providerName.toLowerCase().contains('kimi') ||
           providerName.toLowerCase().contains('moonshot'))) {
        body['thinking'] = {'type': 'disabled'};
      }

      dev.log(
        'Round $round: POST $effectiveBaseUrl/chat/completions, tools=${body['tools'] != null}, msgCount=${currentMessages.length}',
        name: 'llm_client',
      );

      final dio = Dio(BaseOptions(baseUrl: effectiveBaseUrl));
      final Response<ResponseBody> response;
      try {
        response = await dio.post<ResponseBody>(
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
          data: body,
        );
      } on DioException catch (e) {
        dev.log(
          'Request failed: ${e.message}, statusCode=${e.response?.statusCode}, data=${e.response?.data}',
          name: 'llm_client',
          error: e,
        );
        rethrow;
      }

      final responseBody = response.data;
      if (responseBody == null) {
        throw StateError('Empty response body');
      }

      final stream =
          responseBody.stream.cast<List<int>>().transform(utf8.decoder);
      final buffer = StringBuffer();

      // 收集 tool_calls（用于多轮交互）
      final toolCallsMap = <int, Map<String, Object?>>{};
      String? finishReason;

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
              break;
            }
            final parsed = _parseJsonSafe(data);
            if (parsed == null) continue;
            final choices = parsed['choices'] as List?;
            if (choices == null || choices.isEmpty) continue;
            final choice = choices.first as Map<String, Object?>;

            // 记录 finish_reason
            final fr = choice['finish_reason'] as String?;
            if (fr != null) finishReason = fr;

            // 收集 tool_calls 增量
            final delta = choice['delta'] as Map<String, Object?>?;
            if (delta != null) {
              final toolCalls = delta['tool_calls'] as List?;
              if (toolCalls != null) {
                for (final tc in toolCalls) {
                  final tcMap = tc as Map<String, Object?>;
                  final index = tcMap['index'] as int;
                  final existing = toolCallsMap[index] ?? {
                    'id': tcMap['id'] as String? ?? '',
                    'type': tcMap['type'] as String? ?? 'function',
                    'function': <String, Object?>{
                      'name': '',
                      'arguments': '',
                    },
                  };
                  final fn = tcMap['function'] as Map<String, Object?>?;
                  if (fn != null) {
                    final existingFn =
                        existing['function'] as Map<String, Object?>;
                    if (fn['name'] != null) {
                      existingFn['name'] = fn['name'];
                    }
                    if (fn['arguments'] != null) {
                      existingFn['arguments'] =
                          '${existingFn['arguments']}${fn['arguments']}';
                    }
                  }
                  if (tcMap['id'] != null &&
                      (tcMap['id'] as String).isNotEmpty) {
                    existing['id'] = tcMap['id'];
                  }
                  toolCallsMap[index] = existing;
                }
              }
            }

            // 提取 content/reasoning delta
            final deltaContent = _extractDeltaFromMap(delta);
            if (deltaContent != null && !deltaContent.isEmpty) {
              yield deltaContent;
            }
          }
        }
      }

      dev.log(
        'Round $round done: finishReason=$finishReason, toolCalls=${toolCallsMap.length}',
        name: 'llm_client',
      );

      // 如果没有 tool_calls，结束循环
      if (finishReason != 'tool_calls' || toolCallsMap.isEmpty) {
        return;
      }

      dev.log(
        'Processing ${toolCallsMap.length} tool_calls, building tool messages...',
        name: 'llm_client',
      );

      // 有 tool_calls：构建 tool 结果消息并继续下一轮
      final assistantToolCalls = toolCallsMap.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      // 添加 assistant 消息（含 tool_calls）
      currentMessages.add({
        'role': 'assistant',
        'tool_calls': assistantToolCalls.map((e) => e.value).toList(),
      });

      // 添加 tool 结果消息
      for (final entry in assistantToolCalls) {
        final tc = entry.value;
        final fn = tc['function'] as Map<String, Object?>;
        final name = fn['name'] as String;
        final arguments = fn['arguments'] as String;

        // 对于 KIMI $web_search，直接返回 arguments（服务端执行搜索）
        currentMessages.add({
          'role': 'tool',
          'tool_call_id': tc['id'],
          'name': name,
          'content': arguments,
        });
      }
    }
  }

  static Map<String, Object?>? _parseJsonSafe(String data) {
    try {
      final result = json.decode(data);
      return result is Map<String, Object?> ? result : null;
    } catch (_) {
      return null;
    }
  }

  static LlmResponseDelta? _extractDeltaFromMap(Map<String, Object?>? delta) {
    if (delta == null) return null;
    final content = delta['content'] as String? ?? '';
    final reasoningContent =
        delta['reasoning_content'] as String? ?? '';
    if (content.isEmpty && reasoningContent.isEmpty) return null;
    return LlmResponseDelta(
      content: content,
      reasoning: reasoningContent,
    );
  }
}

class ClaudeClient extends LlmClient {
  const ClaudeClient({this.baseUrl});

  /// 可选的自定义 baseUrl，为 null 时使用默认值
  final String? baseUrl;

  /// 带自定义 baseUrl 的构造函数
  const ClaudeClient.withBaseUrl(this.baseUrl);

  /// Claude 多模态消息格式
  @override
  Object buildMultimodalContent({
    required String text,
    Uint8List? imageData,
    String? imageMimeType,
  }) {
    if (imageData == null) {
      return text;
    }

    final base64Image = base64Encode(imageData);
    final mimeType = imageMimeType ?? 'image/jpeg';

    return [
      {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': mimeType,
          'data': base64Image,
        },
      },
      {'type': 'text', 'text': text},
    ];
  }

  @override
  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
    bool webSearch = false,
  }) async* {
    final effectiveBaseUrl = baseUrl ?? 'https://api.anthropic.com/v1';
    final dio = Dio(BaseOptions(baseUrl: effectiveBaseUrl));

    dev.log(
      'ClaudeClient.streamChatCompletion: baseUrl=$effectiveBaseUrl, model=$model, webSearch=$webSearch',
      name: 'llm_client',
    );

    final systemMessages = <Map<String, Object?>>[];
    final userAssistantMessages = <Map<String, Object?>>[];

    for (final msg in messages) {
      final role = msg['role'] as String?;
      if (role == 'system') {
        systemMessages.add(msg);
      } else {
        // 处理多模态消息（content 为数组）
        final content = msg['content'];
        if (content is List) {
          // 已经是多模态格式，直接使用
          userAssistantMessages.add(msg);
        } else {
          // 纯文本消息，转换为 Claude 的 content 数组格式
          final text = content as String? ?? '';
          userAssistantMessages.add({
            'role': role,
            'content': [
              {'type': 'text', 'text': text},
            ],
          });
        }
      }
    }

    final bodyData = <String, Object?>{
      'model': model,
      'stream': true,
      'max_tokens': 4096,
      'messages': userAssistantMessages,
      if (webSearch)
        'tools': [
          {
            'type': 'web_search_20260209',
            'name': 'web_search',
            'max_uses': 3,
          },
        ],
    };

    if (systemMessages.isNotEmpty) {
      bodyData['system'] = systemMessages.map((m) => m['content']).join('\n');
    }

    dev.log(
      'ClaudeClient POST $effectiveBaseUrl/messages, bodyKeys=${bodyData.keys.toList()}',
      name: 'llm_client',
    );

    final Response<ResponseBody> response;
    try {
      response = await dio.post<ResponseBody>(
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
    } on DioException catch (e) {
      dev.log(
        'ClaudeClient request failed: ${e.message}, statusCode=${e.response?.statusCode}, data=${e.response?.data}',
        name: 'llm_client',
        error: e,
      );
      rethrow;
    }

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

  /// Gemini 多模态消息格式（返回 parts 数组）
  @override
  Object buildMultimodalContent({
    required String text,
    Uint8List? imageData,
    String? imageMimeType,
  }) {
    if (imageData == null) {
      return [
        {'text': text},
      ];
    }

    final base64Image = base64Encode(imageData);
    final mimeType = imageMimeType ?? 'image/jpeg';

    return [
      {'text': text},
      {
        'inlineData': {
          'mimeType': mimeType,
          'data': base64Image,
        },
      },
    ];
  }

  @override
  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
    bool webSearch = false,
  }) async* {
    final dio = Dio(BaseOptions(baseUrl: baseUrl ?? 'https://generativelanguage.googleapis.com/v1beta'));

    final contents = <Map<String, Object?>>[];
    for (final msg in messages) {
      final role = msg['role'] as String?;
      final content = msg['content'];
      final geminiRole = role == 'assistant' ? 'model' : 'user';

      // 处理多模态消息（content 为数组）
      if (content is List) {
        final parts = <Map<String, Object?>>[];
        for (final part in content) {
          if (part is Map) {
            final type = part['type'] as String?;
            if (type == 'text') {
              parts.add({'text': part['text'] as String? ?? ''});
            } else if (type == 'image_url') {
              final imageUrl = part['image_url'] as Map<String, Object?>?;
              final url = imageUrl?['url'] as String?;
              if (url != null && url.startsWith('data:')) {
                // 解析 data URI: data:image/jpeg;base64,...
                final commaIndex = url.indexOf(',');
                if (commaIndex > 0) {
                  final header = url.substring(0, commaIndex);
                  final base64Data = url.substring(commaIndex + 1);
                  final mimeType = header.split(';')[0].replaceFirst('data:', '');
                  parts.add({
                    'inlineData': {
                      'mimeType': mimeType,
                      'data': base64Data,
                    },
                  });
                }
              }
            }
          }
        }
        if (parts.isNotEmpty) {
          contents.add({
            'role': geminiRole,
            'parts': parts,
          });
        }
      } else {
        // 纯文本消息
        final text = content as String? ?? '';
        contents.add({
          'role': geminiRole,
          'parts': [
            {'text': text},
          ],
        });
      }
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
