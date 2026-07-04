import 'llm_model_config.dart';

/// 模型能力映射表
///
/// 根据模型 ID 前缀/关键词推断模型支持的能力。
/// 用于从 API 获取模型列表时自动设置 capabilities。
const Map<String, Set<ModelCapability>> _modelCapabilityMap = {
  // OpenAI 多模态模型
  'gpt-4o': {ModelCapability.text, ModelCapability.vision},
  'gpt-4o-mini': {ModelCapability.text, ModelCapability.vision},
  'gpt-4-vision': {ModelCapability.text, ModelCapability.vision},
  'gpt-4-turbo': {ModelCapability.text, ModelCapability.vision},

  // Anthropic 多模态模型
  'claude-3': {ModelCapability.text, ModelCapability.vision},
  'claude-3.5': {ModelCapability.text, ModelCapability.vision},

  // Gemini 多模态模型
  'gemini': {ModelCapability.text, ModelCapability.vision},

  // DeepSeek 多模态模型
  'deepseek-vl': {ModelCapability.text, ModelCapability.vision},

  // KIMI (Moonshot) 多模态模型
  'kimi-k2.6': {ModelCapability.text, ModelCapability.vision},
  'kimi-k2.5': {ModelCapability.text, ModelCapability.vision},
  'moonshot-v1-8k-vision-preview': {ModelCapability.text, ModelCapability.vision},
  'moonshot-v1-32k-vision-preview': {ModelCapability.text, ModelCapability.vision},
  'moonshot-v1-128k-vision-preview': {ModelCapability.text, ModelCapability.vision},

  // Minimax 多模态模型
  'minimax-m3': {ModelCapability.text, ModelCapability.vision},

  // MIMO (Xiaomi) 多模态模型
  'mimo-v2.5': {ModelCapability.text, ModelCapability.vision},
  'mimo-v2-omni': {ModelCapability.text, ModelCapability.vision},
};

/// 根据模型 ID 推断模型能力
///
/// 遍历映射表，检查模型 ID 是否包含关键词。
/// 如果匹配，返回对应的能力集合；否则返回默认的 {text}。
Set<ModelCapability> inferCapabilities(String modelId) {
  final lower = modelId.toLowerCase();

  for (final entry in _modelCapabilityMap.entries) {
    if (lower.contains(entry.key.toLowerCase())) {
      return entry.value;
    }
  }

  return {ModelCapability.text};
}
