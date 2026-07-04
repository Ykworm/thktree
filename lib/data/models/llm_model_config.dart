import 'model_capabilities.dart';

/// 模型能力枚举
enum ModelCapability {
  text, // 纯文本
  vision, // 支持图片
  audio, // 支持音频（未来）
}

/// LLM 模型配置
class LlmModelConfig {
  final String id; // 模型标识（如 gpt-4o, deepseek-chat）
  final String name; // 显示名称（通常同 id）
  final int contextWindow; // 上下文窗口大小（tokens），0 表示未知；fromJson 默认 1M
  final Set<ModelCapability> capabilities; // 模型支持的能力

  const LlmModelConfig({
    required this.id,
    required this.name,
    required this.contextWindow,
    this.capabilities = const {ModelCapability.text},
  });

  /// 是否支持多模态（图片）
  bool get supportsVision => capabilities.contains(ModelCapability.vision);

  LlmModelConfig copyWith({
    String? id,
    String? name,
    int? contextWindow,
    Set<ModelCapability>? capabilities,
  }) {
    return LlmModelConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      contextWindow: contextWindow ?? this.contextWindow,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'contextWindow': contextWindow,
    'capabilities': capabilities.map((c) => c.name).toList(),
  };

  factory LlmModelConfig.fromJson(Map<String, dynamic> json) {
    final capsList = json['capabilities'] as List<dynamic>?;
    Set<ModelCapability> caps;
    if (capsList != null) {
      caps = capsList.map((c) => ModelCapability.values.byName(c as String)).toSet();
    } else {
      // 如果没有 capabilities 字段，根据模型 ID 自动推断
      caps = inferCapabilities(json['id'] as String);
    }
    return LlmModelConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      contextWindow: json['contextWindow'] as int? ?? 1000000,
      capabilities: caps,
    );
  }
}
