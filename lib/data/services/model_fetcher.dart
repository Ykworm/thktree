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
      case LlmProviderType.gemini:
        return _fetchGeminiModels(baseUrl, apiKey);
      default:
        // OpenAI 兼容（openai, deepseek, kimi, minimax, mimo, custom）
        return _fetchOpenAiCompatibleModels(baseUrl, apiKey);
    }
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
