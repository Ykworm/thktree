import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/model_capabilities.dart';

/// SSE 规范 §7.1：将 \r\n 和孤立 \r 统一替换为 \n。
/// 解析 SSE 流之前必须做的行结束符规范化，否则使用 CRLF 的服务端
/// （如豆包/火山方舟 ARK）会导致事件边界匹配失败、content 中的换行被 \r 污染。
String _normalizeNewlines(String text) {
  return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}

/// 豆包（火山方舟）的 reasoning_content 字段每个 token 后面都带一个 `\n`，
/// 导致累积后每个字独占一行。去掉尾部多余的换行。
String _stripTrailingNewlines(String text) {
  if (!text.endsWith('\n')) return text;
  var end = text.length;
  while (end > 0 && text.codeUnitAt(end - 1) == 0x0A) {
    end--;
  }
  return text.substring(0, end);
}

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
    bool deepThinking = false,
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
    // 如果文本为空，使用默认提示
    final effectiveText = text.isEmpty ? '描述这张图片' : text;

    return [
      {'type': 'text', 'text': effectiveText},
      {
        'type': 'image_url',
        'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
      },
    ];
  }

  /// 判断豆包模型是否支持 Responses API。
  ///
  /// 火山方舟 Responses API 要求模型版本为 250615 及之后。
  /// 模型 ID 格式示例：
  /// - `doubao-seed-2-1-pro-260628` → 支持（有日期后缀 260628）
  /// - `doubao-seed-2-0-pro` → 不支持（无日期后缀）
  static bool _doubaoSupportsResponsesApi(String modelId) {
    // 匹配末尾的 6 位日期后缀（如 260628、250615）
    final datePattern = RegExp(r'-\d{6}$');
    if (!datePattern.hasMatch(modelId)) return false;
    final dateStr = datePattern.firstMatch(modelId)!.group(0)!.substring(1);
    // 日期 >= 250615 表示支持 Responses API
    return dateStr.compareTo('250615') >= 0;
  }

  /// 根据 LlmProviderConfig 创建客户端实例。
  ///
  /// 对于 OpenAI 兼容的提供商（包括 custom），使用 [ConfigBasedOpenAiCompatibleClient]；
  /// 对于 anthropic / deepseek 类型使用 [ClaudeClient]；
  /// 对于 gemini 类型使用 [GeminiClient]。
  ///
  /// DeepSeek 自 2026-07 起全量切到 Anthropic 兼容协议（ADR-020），
  /// preset 的 baseUrl 直接是 Anthropic 端点，不再在工厂里拼接路径。
  ///
  /// 豆包（火山方舟 ARK）根据模型版本选择协议：
  /// - 新模型（250615 及之后）→ Responses API
  /// - 旧模型 → Chat Completions API（OpenAI 兼容）
  factory LlmClient.forConfig(
    LlmProviderConfig config, {
    bool webSearch = false,
    String? model,
  }) {
    dev.log(
      'LlmClient.forConfig: type=${config.type}, webSearch=$webSearch, baseUrl=${config.baseUrl}, name=${config.name}, model=$model',
      name: 'llm_client',
    );
    // DeepSeek 全量走 Anthropic 兼容协议（preset baseUrl 已是 Anthropic 端点）。
    // 注：DeepSeek V4 公开 API 不支持视觉/图片输入（仅文本/Thinking/工具/JSON/FIM），
    // 故无需为图片走 OpenAI 端点；图片发送在 capability 层即被拦截。
    if (config.type == LlmProviderType.deepseek) {
      return ClaudeClient.withBaseUrl(config.baseUrl, config.type);
    }
    // 豆包（火山方舟 ARK）：根据模型版本选择协议
    if (config.type == LlmProviderType.doubao) {
      if (model != null && _doubaoSupportsResponsesApi(model)) {
        dev.log(
          'Doubao model $model supports Responses API',
          name: 'llm_client',
        );
        return DoubaoResponsesClient(baseUrl: config.baseUrl);
      }
      dev.log(
        'Doubao model ${model ?? "unknown"} uses Chat Completions API (legacy)',
        name: 'llm_client',
      );
      return ConfigBasedOpenAiCompatibleClient(
        baseUrl: config.baseUrl,
        providerName: config.name,
      );
    }
    if (config.isOpenAiCompatible) {
      return ConfigBasedOpenAiCompatibleClient(
        baseUrl: config.baseUrl,
        providerName: config.name,
      );
    }
    switch (config.type) {
      case LlmProviderType.anthropic:
        return ClaudeClient.withBaseUrl(config.baseUrl, config.type);
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

  /// MiniMax-M3 等模型在 content 里嵌入 `<think>...</think>` 标签输出思维链，
  /// 用状态机跨 delta 追踪：true 表示当前处于 think 块内。
  bool _thinkOpen = false;

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

  /// 检测消息列表是否包含图片内容块（OpenAI 的 `image_url` 或 Anthropic 的 `image`）。
  ///
  /// 用于判断本次请求是否为多模态（带图），以便对「思考 + 图片」互斥的
  /// 模型（MiniMax-M3 / KIMI）跳过 thinking 参数，避免 4xx 报错。
  static bool _messagesContainImage(List<Map<String, Object?>> messages) {
    for (final msg in messages) {
      final content = msg['content'];
      if (content is List) {
        for (final part in content) {
          if (part is Map &&
              (part['type'] == 'image_url' || part['type'] == 'image')) {
            return true;
          }
        }
      }
    }
    return false;
  }

  @override
  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
    bool webSearch = false,
    bool deepThinking = false,
  }) async* {
    _thinkOpen = false; // 每次新对话重置 think 标签状态机
    final currentMessages = List<Map<String, Object?>>.from(messages);
    final effectiveBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    dev.log(
      'streamChatCompletion: provider=$providerName, model=$model, webSearch=$webSearch, deepThinking=$deepThinking, baseUrl=$effectiveBaseUrl',
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

      // 检测本次请求是否含图片（多模态）
      final hasImage = _messagesContainImage(currentMessages);

      // KIMI 使用 $web_search 时必须禁用 thinking（且不能与图片同请求）
      if (webSearch &&
          !hasImage &&
          (providerName.toLowerCase().contains('kimi') ||
           providerName.toLowerCase().contains('moonshot'))) {
        body['thinking'] = {'type': 'disabled'};
      }

      // 深度思考（OpenAI 兼容协议）：
      // - MiniMax-M3: `thinking: true`（布尔值）
      // - KIMI k2.5/k2.6: `thinking: {type: "enabled"/"disabled"}`（对象格式，
      //   与 DeepSeek Anthropic 兼容路径同构；注意 KIMI 默认也是 enabled！
      //   关时必须显式 disabled，否则开关「关不掉」——跟 DeepSeek 同款 bug）
      // - 豆包（火山方舟）：服务端默认开启，无法关闭，不发参数；
      // - Claude/Anthropic 官方：走 ClaudeClient 不进这里。
      // 上游 chat_controller 已用 `inferCapabilities()` 二次校验 deepThinking
      // cap，未在白名单的模型根本不会传 true 进来。
      // ⚠️ MiniMax-M3 / KIMI 推理模型**不支持「思考 + 图片」同请求**：
      // 带图时开启 thinking 会 4xx 报错。故含图片时跳过 thinking 参数，
      // 图片请求走非思考模式（图片识别正常），避免报错。
      if (deepThinking && !hasImage) {
        if (providerName.toLowerCase().contains('minimax')) {
          body['thinking'] = true;
        } else if (providerName.toLowerCase().contains('kimi') ||
            providerName.toLowerCase().contains('moonshot')) {
          body['thinking'] = {'type': 'enabled'};
        }
      } else if (!webSearch && !hasImage &&
          (providerName.toLowerCase().contains('kimi') ||
           providerName.toLowerCase().contains('moonshot'))) {
        // KIMI 推理模型（k2.5/k2.6）默认开启思考；用户关掉开关时显式 disabled。
        // （webSearch 场景已在上方单独处理：强制 disabled + 禁止同时 reasoning_effort）
        // 含图片时不进入此分支（避免 disabled + image 组合报错）。
        final caps = inferCapabilities(model);
        if (caps.contains(ModelCapability.deepThinking)) {
          body['thinking'] = {'type': 'disabled'};
        }
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

      // DEBUG: 累积每次 SSE 事件的 data 字符串（JSON.parse 之前），
      // 用于排查 LLM 是否在 content 里发 newline。stream 结束后一次性 log。
      final rawDataLog = <String>[];

      // 收集 tool_calls（用于多轮交互）
      final toolCallsMap = <int, Map<String, Object?>>{};
      String? finishReason;
      bool doneReceived = false;
      final pendingDeltas = <LlmResponseDelta>[];

      // SSE 解析循环（提取为局部函数，chunk 到达时和流结束时都可调用）
      // SSE 规范 §7.1：必须在写入 buffer 前将 \r\n 和单个 \r 统一为 \n。
      // 这里由调用方在 buffer.write 前做 _normalizeNewlines，解析时只需以 \n 为分隔符即可。
      void parseBuffer() {
        while (!doneReceived) {
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
              doneReceived = true;
              finishReason = finishReason ?? 'stop';
              return;
            }
            rawDataLog.add(data);
            final parsed = _parseJsonSafe(data);
            if (parsed == null) continue;
            final choices = parsed['choices'] as List?;
            if (choices == null || choices.isEmpty) continue;
            final choice = choices.first as Map<String, Object?>;

            final fr = choice['finish_reason'] as String?;
            if (fr != null) finishReason = fr;

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
                    if (fn['name'] != null) existingFn['name'] = fn['name'];
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

            // delta 已在 chunk 写入 buffer 前做过 \r→\n 规范化，这里无需重复处理
            final deltaContent = _extractDeltaFromMap(delta);
            if (deltaContent != null && !deltaContent.isEmpty) {
              pendingDeltas.add(deltaContent);
            }
          }
        }
      }

      await for (final chunk in stream) {
        // SSE 规范：写入 buffer 前统一行结束符（\r\n → \n，剩余 \r → \n）
        buffer.write(_normalizeNewlines(chunk));
        parseBuffer();
        for (final d in pendingDeltas) {
          yield d;
        }
        pendingDeltas.clear();
      }
      // 流结束后 flush buffer 中可能残留的最后一个事件
      parseBuffer();
      for (final d in pendingDeltas) {
        yield d;
      }
      pendingDeltas.clear();

      dev.log(
        'Round $round done: finishReason=$finishReason, toolCalls=${toolCallsMap.length}',
        name: 'llm_client',
      );

      // DEBUG: stream 结束（这一轮 LLM 输出完），一次性 log 累积的 raw data
      // ignore: avoid_print
      print(
        '[RAW-DATA-OAI round=$round] event_count=${rawDataLog.length}\n'
        '${rawDataLog.map((d) => d.length > 300 ? '${d.substring(0, 300)}...' : d).join("\n---\n")}',
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

  /// 从 OpenAI 兼容 delta JSON 中提取 content + reasoning。
  ///
  /// - 先处理 `reasoning_content` 字段（豆包/ARK、MiniMax-M3 原生字段）
  /// - 如果原生字段为空但 content 中有 `<think>...</think>`（MiniMax-M3 部分端点），
  ///   用状态机跨 delta 提取：`<think>` 进入 thinking，`</think>` 回到 content。
  ///   流式输出中标签可能跨 100+ 个 delta，`_thinkOpen` 跨调用保持状态。
  /// - 对 content 和 reasoning 内部做 \r\n → \n 规范化（豆包 ARK 用 CRLF）。
  LlmResponseDelta? _extractDeltaFromMap(Map<String, Object?>? delta) {
    if (delta == null) return null;
    final rawContent = _normalizeNewlines(delta['content'] as String? ?? '');
    final nativeReasoning =
        _normalizeNewlines(delta['reasoning_content'] as String? ?? '');

    // 原生 reasoning 字段有值（豆包/ARK），直接用，不走 think 标签解析
    if (nativeReasoning.isNotEmpty) {
      if (rawContent.isEmpty && nativeReasoning.isEmpty) return null;
      return LlmResponseDelta(
        content: rawContent,
        reasoning: _stripTrailingNewlines(nativeReasoning),
      );
    }

    // 走 think 标签状态机（MiniMax-M3 等）
    if (rawContent.isEmpty) return null;
    final reasoningBuf = StringBuffer();
    final contentBuf = StringBuffer();
    var i = 0;
    while (i < rawContent.length) {
      if (_thinkOpen) {
        // 在 think 块内，找 </think>
        final endIdx = rawContent.indexOf('</think>', i);
        if (endIdx < 0) {
          // 没找到闭合标签，整个剩余都是 thinking
          reasoningBuf.write(rawContent.substring(i));
          i = rawContent.length;
        } else {
          reasoningBuf.write(rawContent.substring(i, endIdx));
          _thinkOpen = false;
          i = endIdx + 8; // 跳过 </think>
        }
      } else {
        // 在 content 中，找 <think>
        final startIdx = rawContent.indexOf('<think>', i);
        if (startIdx < 0) {
          // 没有开标签，整个剩余都是 content
          contentBuf.write(rawContent.substring(i));
          i = rawContent.length;
        } else {
          contentBuf.write(rawContent.substring(i, startIdx));
          _thinkOpen = true;
          i = startIdx + 7; // 跳过 <think>
        }
      }
    }
    final content = contentBuf.toString();
    final reasoning = reasoningBuf.toString();
    if (content.isEmpty && reasoning.isEmpty) return null;
    return LlmResponseDelta(
      content: content,
      reasoning: _stripTrailingNewlines(reasoning),
    );
  }
}

class ClaudeClient extends LlmClient {
  const ClaudeClient({this.baseUrl, this.providerType});

  /// 可选的自定义 baseUrl，为 null 时使用默认值
  final String? baseUrl;

  /// 关联的提供商类型。
  /// 用于判断 DeepSeek 推理模型「默认开思考」、关时需显式发 disabled；
  /// 为 null 时退化为「不发送 thinking 字段」（真·Anthropic 默认不开思考）。
  final LlmProviderType? providerType;

  /// 带自定义 baseUrl 的构造函数
  const ClaudeClient.withBaseUrl(this.baseUrl, [this.providerType]);

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
    bool deepThinking = false,
  }) async* {
    final effectiveBaseUrl = baseUrl ?? 'https://api.anthropic.com/v1';
    final dio = Dio(BaseOptions(baseUrl: effectiveBaseUrl));

    dev.log(
      'ClaudeClient.streamChatCompletion: baseUrl=$effectiveBaseUrl, model=$model, webSearch=$webSearch, deepThinking=$deepThinking',
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

    // 深度思考（Anthropic 兼容协议，DeepSeek / Claude 共用 ClaudeClient）：
    // - deepThinking=true  → thinking: enabled（开启推理；DeepSeek 忽略 budget_tokens，
    //   当前 hardcoded max_tokens=4096 够用）
    // - deepThinking=false 且 DeepSeek 推理模型（默认开思考）→ 显式 disabled 关掉，
    //   否则 DeepSeek 走模型默认 enabled，开关「关不掉」（官方：thinking 默认 enabled）
    // - deepThinking=false 且真·Anthropic（默认不开思考）→ 不发送 thinking 字段
    if (deepThinking) {
      bodyData['thinking'] = {'type': 'enabled'};
    } else if (providerType == LlmProviderType.deepseek &&
        inferCapabilities(model).contains(ModelCapability.deepThinking)) {
      bodyData['thinking'] = {'type': 'disabled'};
    }

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

    // DEBUG: 累积每次 SSE 事件的 data 字符串（JSON.parse 之前），
    // 用于排查 LLM 是否在 content 里发 newline。stream 结束后一次性 log。
    final rawDataLog = <String>[];
    final pendingDeltas = <LlmResponseDelta>[];

    void parseClaudeBuffer() {
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
          rawDataLog.add(data);
          final delta = _extractClaudeDelta(data);
          if (delta != null && !delta.isEmpty) {
            pendingDeltas.add(LlmResponseDelta(
              content: _normalizeNewlines(delta.content),
              reasoning: _stripTrailingNewlines(
                  _normalizeNewlines(delta.reasoning)),
            ));
          }
        }
      }
    }

    await for (final chunk in stream) {
      buffer.write(_normalizeNewlines(chunk));
      parseClaudeBuffer();
      for (final d in pendingDeltas) {
        yield d;
      }
      pendingDeltas.clear();
    }
    // 流结束后 flush buffer
    parseClaudeBuffer();
    for (final d in pendingDeltas) {
      yield d;
    }
    pendingDeltas.clear();

    // DEBUG: stream 结束（LLM 输出完），一次性 log 累积的 raw data
    // ignore: avoid_print
    print(
      '[RAW-DATA-CLAUDE] event_count=${rawDataLog.length}\n'
      '${rawDataLog.map((d) => d.length > 300 ? '${d.substring(0, 300)}...' : d).join("\n---\n")}',
    );
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
    bool deepThinking = false,
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

    // DEBUG: 累积每次 SSE 事件的 data 字符串（JSON.parse 之前），
    // 用于排查 LLM 是否在 content 里发 newline。stream 结束后一次性 log。
    final rawDataLog = <String>[];
    final pendingDeltas = <LlmResponseDelta>[];

    void parseGeminiBuffer() {
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
          rawDataLog.add(data);
          final delta = _extractGeminiDelta(data);
          if (delta != null && !delta.isEmpty) {
            pendingDeltas.add(LlmResponseDelta(
              content: _normalizeNewlines(delta.content),
              reasoning: _stripTrailingNewlines(
                  _normalizeNewlines(delta.reasoning)),
            ));
          }
        }
      }
    }

    await for (final chunk in stream) {
      buffer.write(_normalizeNewlines(chunk));
      parseGeminiBuffer();
      for (final d in pendingDeltas) {
        yield d;
      }
      pendingDeltas.clear();
    }
    // 流结束后 flush buffer
    parseGeminiBuffer();
    for (final d in pendingDeltas) {
      yield d;
    }
    pendingDeltas.clear();

    // DEBUG: stream 结束（LLM 输出完），一次性 log 累积的 raw data
    // ignore: avoid_print
    print(
      '[RAW-DATA-GEMINI] event_count=${rawDataLog.length}\n'
      '${rawDataLog.map((d) => d.length > 300 ? '${d.substring(0, 300)}...' : d).join("\n---\n")}',
    );
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
        final deltaType = delta['type'] as String?;
        // Anthropic 兼容协议（DeepSeek / Claude）的思维链事件：
        //   delta.type == 'thinking_delta'，字段是 delta.thinking
        if (deltaType == 'thinking_delta') {
          final thinking = delta['thinking'] as String?;
          if (thinking != null && thinking.isNotEmpty) {
            return LlmResponseDelta(reasoning: thinking);
          }
        } else if (deltaType == null || deltaType == 'text_delta') {
          // delta.type 缺省（旧实现兼容）或显式 text_delta
          final text = delta['text'] as String?;
          if (text != null && text.isNotEmpty) {
            return LlmResponseDelta(content: text);
          }
        }
        // 其他 delta 类型（input_json_delta 等）不产出
      }
    }
    if (type == 'content_block_start') {
      final block = decoded['content_block'];
      if (block is Map) {
        // 思维链块的初始 thinking 字段（通常为空，少数实现会预填首段）
        if (block['type'] == 'thinking') {
          final thinking = block['thinking'] as String?;
          if (thinking != null && thinking.isNotEmpty) {
            return LlmResponseDelta(reasoning: thinking);
          }
        } else {
          final text = block['text'] as String?;
          if (text != null && text.isNotEmpty) {
            return LlmResponseDelta(content: text);
          }
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

// ─── 豆包（火山方舟）Responses API 客户端 ───────────────────────────

/// 豆包（火山方舟 ARK）Responses API 客户端。
///
/// 豆包的所有请求统一走 Responses API（`/responses` 端点），不再使用
/// Chat Completions API（`/chat/completions`）。Responses API 原生支持
/// 联网搜索（`web_search` 工具）和深度思考（`reasoning_summary` 事件）。
///
/// 流式 SSE 事件格式（兼容 OpenAI Responses API 规范）：
/// - `response.output_text.delta` → 文本增量（delta 字段）
/// - `response.reasoning_summary_text.delta` → 推理增量（delta 字段）
/// - `response.web_search_call.*` → 联网搜索状态
/// - `response.completed` → 流结束
///
/// Volcengine 可能使用两种 SSE 格式：
/// 1. 标准格式：`event: xxx\ndata: {...}`
/// 2. 简化格式：`data: {...}`（event type 在 JSON 的 type 字段中）
/// 本解析器兼容两种格式。
class DoubaoResponsesClient extends LlmClient {
  const DoubaoResponsesClient({required this.baseUrl});

  final String baseUrl;

  @override
  Object buildMultimodalContent({
    required String text,
    Uint8List? imageData,
    String? imageMimeType,
  }) {
    if (imageData == null) return text;
    final base64Image = base64Encode(imageData);
    final mimeType = imageMimeType ?? 'image/jpeg';
    // Responses API 使用 input_image 类型，image_url 直接是字符串
    // 参考：https://www.volcengine.com/docs/82379/1362931
    // 如果文本为空，使用默认提示
    final effectiveText = text.isEmpty ? '描述这张图片' : text;
    return [
      {'type': 'input_text', 'text': effectiveText},
      {
        'type': 'input_image',
        'image_url': 'data:$mimeType;base64,$base64Image',
      },
    ];
  }

  /// 将 Chat Completions messages 格式转换为 Responses API input 格式。
  ///
  /// 主要区别：`messages` → `input`，其余字段基本兼容。
  List<Map<String, Object?>> _convertToInput(
    List<Map<String, Object?>> messages,
  ) {
    return messages.map((msg) {
      final role = msg['role'] as String?;
      final content = msg['content'];
      return {
        'role': role,
        'content': content,
      };
    }).toList();
  }

  /// 构建豆包联网搜索 tools。
  ///
  /// Responses API 使用 `web_search` 类型（不同于 Chat API 的 function 格式）。
  List<Map<String, Object?>> _buildWebSearchTools({int maxKeyword = 5}) {
    return [
      {
        'type': 'web_search',
        'max_keyword': maxKeyword,
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
    bool deepThinking = false,
  }) async* {
    final effectiveBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    // ── 构建请求体 ──
    final body = <String, Object?>{
      'model': model,
      'input': _convertToInput(messages),
      'stream': true,
      if (webSearch) 'tools': _buildWebSearchTools(),
    };

    dev.log(
      'DoubaoResponses POST $effectiveBaseUrl/responses, '
      'model=$model, webSearch=$webSearch, deepThinking=$deepThinking, '
      'msgCount=${messages.length}',
      name: 'llm_client',
    );

    // ── 发送请求 ──
    final dio = Dio(BaseOptions(baseUrl: effectiveBaseUrl));
    final Response<ResponseBody> response;
    try {
      response = await dio.post<ResponseBody>(
        '/responses',
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
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      // ignore: avoid_print
      print('[DOUBAO-ERROR] DioException: ${e.message}');
      // ignore: avoid_print
      print('[DOUBAO-ERROR] statusCode=$statusCode');
      // ignore: avoid_print
      print('[DOUBAO-ERROR] response.data=$responseData');
      dev.log(
        'DoubaoResponses request failed: ${e.message}, '
        'statusCode=$statusCode, data=$responseData',
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
    final rawDataLog = <String>[];
    final pendingDeltas = <LlmResponseDelta>[];
    var completed = false;

    // ── SSE 解析 ──
    void parseBuffer() {
      while (!completed) {
        final text = buffer.toString();
        final idx = text.indexOf('\n\n');
        if (idx < 0) break;
        final block = text.substring(0, idx);
        final rest = text.substring(idx + 2);
        buffer
          ..clear()
          ..write(rest);

        String eventType = '';
        String eventData = '';

        for (final line in block.split('\n')) {
          final trimmed = line.trimRight();
          if (trimmed.startsWith('event:')) {
            eventType = trimmed.substring('event:'.length).trimLeft();
          } else if (trimmed.startsWith('data:')) {
            eventData = trimmed.substring('data:'.length).trimLeft();
          }
        }

        if (eventData.isEmpty) continue;
        rawDataLog.add(eventData);

        // 标准格式：event type 在 event: 行；
        // 简化格式：event type 在 JSON type 字段中。
        if (eventType.isEmpty) {
          final parsed = _parseJsonSafe(eventData);
          eventType = parsed?['type'] as String? ?? '';
        }

        if (eventType.isEmpty) continue;

        // 流结束事件：在 parseBuffer 中设置 completed，
        // 因为 _handleEvent 无法访问 streamChatCompletion 的局部变量。
        if (eventType == 'response.completed' ||
            eventType == 'response.incomplete' ||
            eventType == 'response.failed' ||
            eventType == 'error') {
          completed = true;
        }

        final delta = _handleEvent(eventType, eventData);
        if (delta != null && !delta.isEmpty) {
          pendingDeltas.add(delta);
        }
      }
    }

    await for (final chunk in stream) {
      buffer.write(_normalizeNewlines(chunk));
      parseBuffer();
      for (final d in pendingDeltas) {
        yield d;
      }
      pendingDeltas.clear();
    }
    parseBuffer();
    for (final d in pendingDeltas) {
      yield d;
    }
    pendingDeltas.clear();

    dev.log(
      'DoubaoResponses done: eventCount=${rawDataLog.length}',
      name: 'llm_client',
    );
  }

  /// 根据 SSE event type 分发处理。
  LlmResponseDelta? _handleEvent(String eventType, String data) {
    final parsed = _parseJsonSafe(data);
    if (parsed == null) return null;

    switch (eventType) {
      // ── 文本增量 ──
      case 'response.output_text.delta':
        final delta = parsed['delta'] as String? ?? '';
        if (delta.isEmpty) return null;
        return LlmResponseDelta(
          content: _normalizeNewlines(delta),
        );

      // ── 推理增量（reasoning_summary） ──
      case 'response.reasoning_summary_text.delta':
        final delta = parsed['delta'] as String? ?? '';
        if (delta.isEmpty) return null;
        return LlmResponseDelta(
          reasoning: _stripTrailingNewlines(_normalizeNewlines(delta)),
        );

      // ── 推理增量（reasoning_text，部分模型） ──
      case 'response.reasoning_text.delta':
        final delta = parsed['delta'] as String? ?? '';
        if (delta.isEmpty) return null;
        return LlmResponseDelta(
          reasoning: _stripTrailingNewlines(_normalizeNewlines(delta)),
        );

      // ── 联网搜索状态（仅 log，不产出 delta） ──
      case 'response.web_search_call.in_progress':
        dev.log('Web search: in_progress', name: 'llm_client');
        return null;
      case 'response.web_search_call.searching':
        dev.log('Web search: searching', name: 'llm_client');
        return null;
      case 'response.web_search_call.completed':
        dev.log('Web search: completed', name: 'llm_client');
        return null;

      // ── 流结束 ──
      case 'response.completed':
        return null;
      case 'response.incomplete':
        final reason =
            parsed['incomplete_details'] is Map
                ? (parsed['incomplete_details'] as Map)['reason']
                  as String? ?? 'unknown'
                : 'unknown';
        // ignore: avoid_print
        print('[DOUBAO-ERROR] response.incomplete: $reason');
        dev.log(
          'DoubaoResponses incomplete: $reason',
          name: 'llm_client',
        );
        return null;
      case 'response.failed':
        final error = parsed['error'];
        // ignore: avoid_print
        print('[DOUBAO-ERROR] response.failed: $error');
        dev.log(
          'DoubaoResponses failed: $error',
          name: 'llm_client',
        );
        return null;
      case 'error':
        final errorMsg = parsed['message'];
        // ignore: avoid_print
        print('[DOUBAO-ERROR] stream error: $errorMsg');
        dev.log(
          'DoubaoResponses stream error: $errorMsg',
          name: 'llm_client',
        );
        return null;

      // ── 其他事件（忽略） ──
      default:
        // 包含 text 的事件（兼容不同实现）
        if (eventType.contains('text') &&
            eventType.contains('delta')) {
          final text = _findTextInMap(parsed);
          if (text != null && text.isNotEmpty) {
            return LlmResponseDelta(
              content: _normalizeNewlines(text),
            );
          }
        }
        return null;
    }
  }

  /// 在 JSON 对象中递归查找 text 类型字段。
  static String? _findTextInMap(Map<String, Object?> map) {
    if (map.containsKey('text')) return map['text'] as String?;
    if (map.containsKey('delta')) return map['delta'] as String?;
    for (final value in map.values) {
      if (value is Map<String, Object?>) {
        final result = _findTextInMap(value);
        if (result != null) return result;
      }
    }
    return null;
  }

  static Map<String, Object?>? _parseJsonSafe(String data) {
    try {
      final result = json.decode(data);
      return result is Map<String, Object?> ? result : null;
    } catch (_) {
      return null;
    }
  }
}
