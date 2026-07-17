import 'package:dio/dio.dart';

import '../models/llm_model_config.dart';
import '../models/llm_provider_config.dart';
import '../models/model_capabilities.dart';

/// 默认上下文窗口大小（默认 1M tokens）
const int _defaultContextWindow = 1000000;

/// 应过滤掉的非聊天模型关键词
const List<String> _nonChatKeywords = [
  'embedding',
  'whisper',
  'tts',
  'dall-e',
];

/// 豆包（火山方舟 ARK）白名单模型
///
/// 豆包模型数量庞大，只展示经过验证支持深度思考 + 多模态的模型。
/// modelId 为火山方舟官方 Model ID（非 Endpoint ID），可直接通过
/// OpenAI 兼容接口调用。
///
/// 2026-07-06: 移除 `doubao-seed-2-0-lite-250528`——该 Lite 模型在用户账户上
/// 不可用（Ark 接口返回错误），仅保留 Pro / Turbo 两个。
const List<Map<String, dynamic>> _doubaoWhitelist = [
  {
    'id': 'doubao-seed-2-1-pro-260628',
    'name': 'Doubao-Seed-2.1-pro',
    'contextWindow': 256000,
  },
  {
    'id': 'doubao-seed-2-1-turbo-260628',
    'name': 'Doubao-Seed-2.1-turbo',
    'contextWindow': 256000,
  },
  {
    'id': 'doubao-seed-2-0-pro-260215',
    'name': 'Doubao-Seed-2.0-pro',
    'contextWindow': 256000,
  },
];

/// KIMI（Moonshot）白名单模型
///
/// KIMI 模型数量较多，只展示经过验证的多模态模型。
/// kimi-k2.6 / kimi-k2.5 均为 256K context，支持视觉。
const List<Map<String, dynamic>> _kimiWhitelist = [
  {
    'id': 'kimi-k2.6',
    'name': 'KIMI K2.6',
    'contextWindow': 262144,
  },
  {
    'id': 'kimi-k2.5',
    'name': 'KIMI K2.5',
    'contextWindow': 262144,
  },
];

/// MiniMax 白名单模型
///
/// MiniMax 模型数量较多，只展示经过验证的 M3 多模态+推理模型。
const List<Map<String, dynamic>> _minimaxWhitelist = [
  {
    'id': 'minimax-m3',
    'name': 'MiniMax-M3',
    'contextWindow': 1000000,
  },
];

/// xAI Grok 白名单模型
///
/// /models 会返回大量 alias 与 Imagine/Voice 模型；只保留常用 chat 旗舰。
/// 文档：https://docs.x.ai/docs/models
const List<Map<String, dynamic>> _xaiWhitelist = [
  {
    'id': 'grok-4.5',
    'name': 'Grok 4.5',
    'contextWindow': 500000,
  },
  {
    'id': 'grok-4.3',
    'name': 'Grok 4.3',
    'contextWindow': 1000000,
  },
];

/// DeepSeek 白名单模型
///
/// DeepSeek Anthropic 兼容 API 不提供 `/models` 列表端点，
/// 故使用白名单返回可用聊天模型（ADR-020）。
/// 两个模型均为 1M context，支持 thinking / non-thinking 模式。
///
/// 2026-07-24 起 deepseek-chat / deepseek-reasoner 将废弃
/// （分别映射为 v4-flash non-thinking / thinking），此处暂不加入。
const List<Map<String, dynamic>> _deepseekWhitelist = [
  {
    'id': 'deepseek-v4-pro',
    'name': 'DeepSeek V4 Pro',
    'contextWindow': 1000000,
  },
  {
    'id': 'deepseek-v4-flash',
    'name': 'DeepSeek V4 Flash',
    'contextWindow': 1000000,
  },
];

/// 从 LLM 提供商 API 获取可用模型列表
class ModelFetcher {
  ModelFetcher({Dio? dio})
      : _dio =
            dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ));

  final Dio _dio;

  /// 获取指定提供商的可用模型列表
  ///
  /// [baseUrl] 提供商的 API 基础 URL
  /// [apiKey] API Key
  /// [type] 提供商类型
  ///
  /// 根据 [type] 分发到对应的 API 解析逻辑：
  /// - Anthropic → `_fetchAnthropicModels`
  /// - Gemini → `_fetchGeminiModels`
  /// - 其余 → `_fetchOpenAiCompatibleModels`（OpenAI 兼容接口）
  Future<List<LlmModelConfig>> fetchModels({
    required String baseUrl,
    required String apiKey,
    required LlmProviderType type,
  }) async {
    switch (type) {
      case LlmProviderType.anthropic:
        return _fetchAnthropicModels(baseUrl, apiKey);
      case LlmProviderType.deepseek:
        // DeepSeek Anthropic 兼容 API 不提供 /models 列表端点，
        // 使用白名单返回可用聊天模型（ADR-020）。
        return _fetchDeepseekModels();
      case LlmProviderType.gemini:
        return _fetchGeminiModels(baseUrl, apiKey);
      case LlmProviderType.doubao:
        return _fetchDoubaoModels(baseUrl, apiKey);
      case LlmProviderType.kimi:
        return _fetchKimiModels();
      case LlmProviderType.minimax:
        return _fetchMinimaxModels();
      case LlmProviderType.xai:
        return _fetchXaiModels();
      default:
        // OpenAI 兼容（openai, mimo, custom 等）
        return _fetchOpenAiCompatibleModels(baseUrl, apiKey);
    }
  }

  // ─── 豆包（火山方舟 ARK）白名单 ──────────────────────────────────────

  /// 豆包使用白名单模型列表，不从 /models API 获取。
  ///
  /// 2026-07-07: 同时调用真实 API 并打印全量模型（debug 用）。
  List<LlmModelConfig> _fetchDoubaoModels(
    String baseUrl,
    String apiKey,
  ) {
    // ignore: avoid_print
    print('[DOUBAO-FETCH] calling GET $baseUrl/models ...');
    _sendRequest(
      url: '$baseUrl/models',
      headers: {'Authorization': 'Bearer $apiKey'},
    ).then((response) {
      final data = response['data'] as List<dynamic>? ?? [];
      // ignore: avoid_print
      print('[DOUBAO-FETCH] API returned ${data.length} models (raw, unfiltered):');
      for (final item in data) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String? ?? '';
        final ownedBy = map['owned_by'] as String? ?? '';
        // ignore: avoid_print
        print('  id=$id  owned_by=$ownedBy');
      }
    }).catchError((e) {
      // ignore: avoid_print
      print('[DOUBAO-FETCH] API call failed: $e');
    });

    // 同时返回白名单（UI 正常显示不受影响）
    return _doubaoWhitelist.map((m) {
      final id = m['id'] as String;
      return LlmModelConfig(
        id: id,
        name: m['name'] as String,
        contextWindow: m['contextWindow'] as int,
        capabilities: inferCapabilities(id),
      );
    }).toList();
  }

  // ─── DeepSeek（Anthropic 兼容，白名单） ──────────────────────────

  /// DeepSeek 使用白名单模型列表。
  ///
  /// DeepSeek 的 Anthropic 兼容 API 不提供 `/models` 列表端点，
  /// 故采用白名单方式返回可用聊天模型（与豆包同理）。
  List<LlmModelConfig> _fetchDeepseekModels() {
    return _deepseekWhitelist.map((m) {
      final id = m['id'] as String;
      return LlmModelConfig(
        id: id,
        name: m['name'] as String,
        contextWindow: m['contextWindow'] as int,
        capabilities: inferCapabilities(id),
      );
    }).toList();
  }

  // ─── KIMI（Moonshot，白名单）─────────────────────────────────────

  /// KIMI 使用白名单模型列表（只保留 k2.6 / k2.5）。
  List<LlmModelConfig> _fetchKimiModels() {
    return _kimiWhitelist.map((m) {
      final id = m['id'] as String;
      return LlmModelConfig(
        id: id,
        name: m['name'] as String,
        contextWindow: m['contextWindow'] as int,
        capabilities: inferCapabilities(id),
      );
    }).toList();
  }

  // ─── MiniMax（白名单）──────────────────────────────────────────

  /// MiniMax 使用白名单模型列表（只保留 M3）。
  List<LlmModelConfig> _fetchMinimaxModels() {
    return _minimaxWhitelist.map((m) {
      final id = m['id'] as String;
      return LlmModelConfig(
        id: id,
        name: m['name'] as String,
        contextWindow: m['contextWindow'] as int,
        capabilities: inferCapabilities(id),
      );
    }).toList();
  }

  // ─── xAI Grok（白名单）──────────────────────────────────────────

  /// xAI 使用白名单模型列表（只保留 Grok 4.5 / 4.3 chat）。
  List<LlmModelConfig> _fetchXaiModels() {
    return _xaiWhitelist.map((m) {
      final id = m['id'] as String;
      return LlmModelConfig(
        id: id,
        name: m['name'] as String,
        contextWindow: m['contextWindow'] as int,
        capabilities: inferCapabilities(id),
      );
    }).toList();
  }

  // ─── OpenAI 兼容接口 ────────────────────────────────────────────────

  /// 从 OpenAI 兼容 API 获取模型列表
  ///
  /// 请求: GET {baseUrl}/models
  /// 认证: Authorization: Bearer {apiKey}
  /// 响应: { "data": [{ "id": "gpt-4o", ... }] }
  Future<List<LlmModelConfig>> _fetchOpenAiCompatibleModels(
    String baseUrl,
    String apiKey,
  ) async {
    final response = await _sendRequest(
      url: '$baseUrl/models',
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    try {
      final data = response['data'] as List<dynamic>? ?? [];
      final models = <LlmModelConfig>[];

      for (final item in data) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String? ?? '';
        if (id.isEmpty) continue;

        // 过滤掉非聊天模型
        if (_isNonChatModel(id)) continue;

        // 尝试解析 context window（不同提供商字段名可能不同）
        final contextWindow =
            map['context_window'] as int? ??
            map['context_length'] as int? ??
            _defaultContextWindow;

        models.add(LlmModelConfig(
          id: id,
          name: id, // OpenAI 兼容接口通常不提供 display_name，用 id 作为 name
          contextWindow: contextWindow,
          capabilities: inferCapabilities(id),
        ));
      }

      return models;
    } catch (_) {
      // 解析错误时容错返回空列表
      return [];
    }
  }

  // ─── Anthropic 接口 ─────────────────────────────────────────────────

  /// 从 Anthropic API 获取模型列表
  ///
  /// 请求: GET {baseUrl}/models
  /// 认证: x-api-key + anthropic-version header
  /// 响应: { "data": [{ "id": "claude-sonnet-4-20250514", "display_name": "Claude Sonnet 4", ... }] }
  Future<List<LlmModelConfig>> _fetchAnthropicModels(
    String baseUrl,
    String apiKey,
  ) async {
    final response = await _sendRequest(
      url: '$baseUrl/models',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
    );

    try {
      final data = response['data'] as List<dynamic>? ?? [];
      final models = <LlmModelConfig>[];

      for (final item in data) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String? ?? '';
        if (id.isEmpty) continue;

        // Anthropic 可能返回 display_name，优先使用；否则用 id
        final name = map['display_name'] as String? ?? id;

        // Anthropic API 不返回 context window，设为 0（未知）
        final contextWindow = _defaultContextWindow;

        models.add(LlmModelConfig(
          id: id,
          name: name,
          contextWindow: contextWindow,
          capabilities: inferCapabilities(id),
        ));
      }

      return models;
    } catch (_) {
      return [];
    }
  }

  // ─── Gemini 接口 ────────────────────────────────────────────────────

  /// 从 Google Gemini API 获取模型列表
  ///
  /// 请求: GET {baseUrl}/models?key={apiKey}
  /// 响应: { "models": [{ "name": "models/gemini-2.5-flash", "displayName": "Gemini 2.5 Flash",
  ///          "inputTokenLimit": 1048576, "supportedGenerationMethods": [...], ... }] }
  Future<List<LlmModelConfig>> _fetchGeminiModels(
    String baseUrl,
    String apiKey,
  ) async {
    final response = await _sendRequest(
      url: '$baseUrl/models?key=$apiKey',
    );

    try {
      final modelList = response['models'] as List<dynamic>? ?? [];
      final models = <LlmModelConfig>[];

      for (final item in modelList) {
        final map = item as Map<String, dynamic>;

        // 只保留支持 generateContent 的模型
        final methods =
            (map['supportedGenerationMethods'] as List<dynamic>? ?? [])
                .cast<String>();
        if (!methods.contains('generateContent')) continue;

        // name 格式为 "models/gemini-2.5-flash"，去掉 "models/" 前缀
        final rawName = map['name'] as String? ?? '';
        final id = rawName.replaceFirst(RegExp(r'^models/'), '');
        if (id.isEmpty) continue;

        final displayName = map['displayName'] as String? ?? id;
        final contextWindow =
            map['inputTokenLimit'] as int? ?? _defaultContextWindow;

        models.add(LlmModelConfig(
          id: id,
          name: displayName,
          contextWindow: contextWindow,
          capabilities: inferCapabilities(id),
        ));
      }

      return models;
    } catch (_) {
      return [];
    }
  }

  // ─── 通用辅助方法 ───────────────────────────────────────────────────

  /// 发送 HTTP GET 请求并返回解析后的 JSON 数据
  ///
  /// 统一处理网络错误和 HTTP 状态码错误：
  /// - 401/403 → 抛出 "API Key 无效或已过期"
  /// - 其他 HTTP 错误 → 抛出包含状态码的异常
  /// - 网络/超时错误 → 抛出带有明确消息的异常
  Future<Map<String, dynamic>> _sendRequest({
    required String url,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        options: Options(headers: headers),
      );
      return response.data ?? {};
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        throw Exception('API Key 无效或已过期');
      }
      if (e.response != null) {
        throw Exception('HTTP 错误: $statusCode');
      }
      // 网络超时、连接失败等
      throw Exception('网络请求失败: ${e.message}');
    }
  }

  /// 判断模型 ID 是否属于非聊天模型
  ///
  /// 过滤包含 embedding、whisper、tts、dall-e 等关键词的模型
  static bool _isNonChatModel(String modelId) {
    final lower = modelId.toLowerCase();
    return _nonChatKeywords.any((keyword) => lower.contains(keyword));
  }
}
