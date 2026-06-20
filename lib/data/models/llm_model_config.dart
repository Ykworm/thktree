/// LLM 模型配置
class LlmModelConfig {
  final String id; // 模型标识（如 gpt-4o, deepseek-chat）
  final String name; // 显示名称（通常同 id）
  final int contextWindow; // 上下文窗口大小（tokens），0 表示未知；fromJson 默认 1M

  const LlmModelConfig({
    required this.id,
    required this.name,
    required this.contextWindow,
  });

  LlmModelConfig copyWith({
    String? id,
    String? name,
    int? contextWindow,
  }) {
    return LlmModelConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      contextWindow: contextWindow ?? this.contextWindow,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'contextWindow': contextWindow,
  };

  factory LlmModelConfig.fromJson(Map<String, dynamic> json) {
    return LlmModelConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      contextWindow: json['contextWindow'] as int? ?? 1000000,
    );
  }
}
