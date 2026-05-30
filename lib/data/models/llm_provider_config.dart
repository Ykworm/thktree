import 'llm_model_config.dart';

/// 提供商类型枚举
enum LlmProviderType {
  openai,
  anthropic,
  gemini,
  deepseek,
  kimi,
  minimax,
  mimo,
  custom;

  String get displayName {
    switch (this) {
      case LlmProviderType.openai:
        return 'OpenAI';
      case LlmProviderType.anthropic:
        return 'Anthropic';
      case LlmProviderType.gemini:
        return 'Google Gemini';
      case LlmProviderType.deepseek:
        return 'DeepSeek';
      case LlmProviderType.kimi:
        return 'KIMI';
      case LlmProviderType.minimax:
        return 'Minimax';
      case LlmProviderType.mimo:
        return 'MIMO';
      case LlmProviderType.custom:
        return '自定义';
    }
  }
}

/// LLM 提供商配置
class LlmProviderConfig {
  final String id; // 唯一ID (ulid)
  final LlmProviderType type; // 提供商类型
  final String name; // 显示名称（自定义时用户填写）
  final String baseUrl; // API 基础 URL（用户可修改）
  final String defaultBaseUrl; // 官方默认 URL（用于展示和复制）
  final List<LlmModelConfig> models; // 该提供商下的模型列表
  final bool isOpenAiCompatible; // 是否 OpenAI 兼容接口
  final String? selectedModelId; // 当前选中的默认模型ID

  const LlmProviderConfig({
    required this.id,
    required this.type,
    required this.name,
    required this.baseUrl,
    required this.defaultBaseUrl,
    this.models = const [],
    required this.isOpenAiCompatible,
    this.selectedModelId,
  });

  LlmProviderConfig copyWith({
    String? id,
    LlmProviderType? type,
    String? name,
    String? baseUrl,
    String? defaultBaseUrl,
    List<LlmModelConfig>? models,
    bool? isOpenAiCompatible,
    String? selectedModelId,
  }) {
    return LlmProviderConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultBaseUrl: defaultBaseUrl ?? this.defaultBaseUrl,
      models: models ?? this.models,
      isOpenAiCompatible: isOpenAiCompatible ?? this.isOpenAiCompatible,
      selectedModelId: selectedModelId ?? this.selectedModelId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'baseUrl': baseUrl,
    'defaultBaseUrl': defaultBaseUrl,
    'models': models.map((m) => m.toJson()).toList(),
    'isOpenAiCompatible': isOpenAiCompatible,
    'selectedModelId': selectedModelId,
  };

  factory LlmProviderConfig.fromJson(Map<String, dynamic> json) {
    return LlmProviderConfig(
      id: json['id'] as String,
      type: LlmProviderType.values.byName(json['type'] as String),
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      defaultBaseUrl: json['defaultBaseUrl'] as String,
      models:
          (json['models'] as List<dynamic>?)
              ?.map((m) => LlmModelConfig.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      isOpenAiCompatible: json['isOpenAiCompatible'] as bool,
      selectedModelId: json['selectedModelId'] as String?,
    );
  }
}
