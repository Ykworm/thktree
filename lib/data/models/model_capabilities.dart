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

  // DeepSeek 推理模型（支持深度思考，2026-07 ADR-020 后走 Anthropic 兼容路径，
  // 服务端自动在响应里带 thinking_delta 事件，client 端靠 thinking 请求参数触发）。
  // 注意：DeepSeek V4 公开 API **不支持视觉/图片输入**（官方文档仅列
  // 文本/Thinking/工具/JSON/FIM；网页版 D-Chat 的识图是专属管线，非公开 API）。
  // 故此处不含 vision，避免 UI 显示图片按钮却永远发不出去。
  'deepseek-v4-pro': {ModelCapability.text, ModelCapability.deepThinking},
  'deepseek-v4-flash': {ModelCapability.text, ModelCapability.deepThinking},
  // 兼容老 ID（V4 发布前的 deepseek-reasoner = V4-Flash 思考模式）
  'deepseek-reasoner': {ModelCapability.text, ModelCapability.deepThinking},

  // KIMI (Moonshot) 多模态 + 推理模型（k2.5/k2.6 通过 thinking.type 启用/禁用 CoT，
  // 默认 enabled；响应通过 reasoning_content 流式回传，与 MiniMax-M3 同构）
  'kimi-k2.6': {ModelCapability.text, ModelCapability.vision, ModelCapability.deepThinking},
  'kimi-k2.5': {ModelCapability.text, ModelCapability.vision, ModelCapability.deepThinking},
  'moonshot-v1-8k-vision-preview': {ModelCapability.text, ModelCapability.vision},
  'moonshot-v1-32k-vision-preview': {ModelCapability.text, ModelCapability.vision},
  'moonshot-v1-128k-vision-preview': {ModelCapability.text, ModelCapability.vision},

  // Minimax 多模态 + 推理模型（M3 通过 body.thinking={type:adaptive/disabled}
  // 控制 CoT——对象格式，不是布尔值；省略时默认 adaptive on，关时须显式 disabled。
  // 响应通过 reasoning_content 流式回传）
  'minimax-m3': {ModelCapability.text, ModelCapability.vision, ModelCapability.deepThinking},

  // xAI Grok（api.x.ai OpenAI 兼容；reasoning 经 reasoning_content 回传；
  // grok-4.3 支持 reasoning_effort none/low/medium/high；图片输入见官方 Image）
  'grok-4.5': {ModelCapability.text, ModelCapability.vision, ModelCapability.deepThinking},
  'grok-4.3': {ModelCapability.text, ModelCapability.vision, ModelCapability.deepThinking},
  'grok-4': {ModelCapability.text, ModelCapability.vision, ModelCapability.deepThinking},

  // MIMO (Xiaomi) 多模态模型
  'mimo-v2.5': {ModelCapability.text, ModelCapability.vision},
  'mimo-v2-omni': {ModelCapability.text, ModelCapability.vision},

  // 腾讯 TokenHub Hy3：OpenAI 兼容；thinking.type=enabled/disabled；
  // 响应 reasoning_content。官方文档为文本/推理为主，不含 vision 声明。
  'hy3': {ModelCapability.text, ModelCapability.deepThinking},

  // 豆包 (Doubao) Seed 系列 — 深度思考 + 多模态模型
  // 服务端默认开启 thinking，用户无法关闭；聊天页用只读 chip 提示默认状态。
  // 注意：不要加 deepThinking（用户可控 toggle），应只加 alwaysThinking。
  // 2026-07-06: 移除 lite 关键词，对应 model id (`doubao-seed-2-0-lite-250528`)
  // 在用户账户上不可用，已从 `_doubaoWhitelist` 一并剔除。
  'doubao-seed-2-1-pro': {ModelCapability.text, ModelCapability.vision, ModelCapability.alwaysThinking},
  'doubao-seed-2-1-turbo': {ModelCapability.text, ModelCapability.vision, ModelCapability.alwaysThinking},
  // Seed 2.0 Pro：多模态模型
  'doubao-seed-2-0-pro': {ModelCapability.text, ModelCapability.vision},
  // 旧版/通用豆包关键词（兼容 ep-* endpoint ID）
  'doubao': {ModelCapability.text, ModelCapability.vision},
  'ep-': {ModelCapability.text, ModelCapability.vision},
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
