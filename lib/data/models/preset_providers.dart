import 'llm_provider_config.dart';

/// 创建预置提供商配置列表。
///
/// 每个预置提供商使用固定的、确定性的 ID（`preset_` 前缀 + type name），
/// 确保迁移和初始化逻辑可以幂等执行。
/// 不含 API Key，API Key 由用户手动填写并通过 secure storage 单独存储。
List<LlmProviderConfig> createPresetProviders() {
  return const [
    LlmProviderConfig(
      id: 'preset_openai',
      type: LlmProviderType.openai,
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      defaultBaseUrl: 'https://api.openai.com/v1',
      isOpenAiCompatible: true,
    ),
    LlmProviderConfig(
      id: 'preset_anthropic',
      type: LlmProviderType.anthropic,
      name: 'Anthropic',
      baseUrl: 'https://api.anthropic.com/v1',
      defaultBaseUrl: 'https://api.anthropic.com/v1',
      isOpenAiCompatible: false,
    ),
    LlmProviderConfig(
      id: 'preset_gemini',
      type: LlmProviderType.gemini,
      name: 'Google Gemini',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      isOpenAiCompatible: false,
    ),
    LlmProviderConfig(
      id: 'preset_deepseek',
      type: LlmProviderType.deepseek,
      name: 'DeepSeek',
      // DeepSeek 全量切到 Anthropic 兼容协议（ADR-020），端点为
      // https://api.deepseek.com/anthropic/v1/messages。
      baseUrl: 'https://api.deepseek.com/anthropic/v1',
      defaultBaseUrl: 'https://api.deepseek.com/anthropic/v1',
      isOpenAiCompatible: false,
    ),
    LlmProviderConfig(
      id: 'preset_kimi',
      type: LlmProviderType.kimi,
      name: 'KIMI',
      baseUrl: 'https://api.moonshot.cn/v1',
      defaultBaseUrl: 'https://api.moonshot.cn/v1',
      isOpenAiCompatible: true,
    ),
    LlmProviderConfig(
      id: 'preset_minimax',
      type: LlmProviderType.minimax,
      name: 'Minimax',
      baseUrl: 'https://api.minimaxi.com/v1',
      defaultBaseUrl: 'https://api.minimaxi.com/v1',
      isOpenAiCompatible: true,
    ),
    LlmProviderConfig(
      id: 'preset_mimo',
      type: LlmProviderType.mimo,
      name: 'MIMO',
      // 按量计费开放平台 API
      baseUrl: 'https://api.xiaomimimo.com/v1',
      defaultBaseUrl: 'https://api.xiaomimimo.com/v1',
      isOpenAiCompatible: true,
    ),
    LlmProviderConfig(
      id: 'preset_mimo_token_plan',
      type: LlmProviderType.mimo,
      name: 'MIMO Token Plan',
      // Token Plan 中国集群（订阅套餐专属端点 + tp-xxxxx Key）
      // 文档：https://mimo.mi.com/docs/zh-CN/tokenplan/Token%20Plan/subscription
      baseUrl: 'https://token-plan-cn.xiaomimimo.com/v1',
      defaultBaseUrl: 'https://token-plan-cn.xiaomimimo.com/v1',
      isOpenAiCompatible: true,
    ),
    LlmProviderConfig(
      id: 'preset_doubao',
      type: LlmProviderType.doubao,
      name: '豆包',
      baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
      defaultBaseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
      isOpenAiCompatible: true,
    ),
    LlmProviderConfig(
      id: 'preset_xai',
      type: LlmProviderType.xai,
      name: 'xAI Grok',
      // OpenAI 兼容 Chat Completions；控制台 API Key：console.x.ai
      baseUrl: 'https://api.x.ai/v1',
      defaultBaseUrl: 'https://api.x.ai/v1',
      isOpenAiCompatible: true,
    ),
    LlmProviderConfig(
      id: 'preset_tokenhub',
      type: LlmProviderType.tokenhub,
      name: '腾讯 TokenHub',
      // OpenAI 兼容；完整 chat 端点为 …/v1/chat/completions（客户端自动拼接）
      // 文档：https://cloud.tencent.com/document/product/1823/130078
      baseUrl: 'https://tokenhub.tencentmaas.com/v1',
      defaultBaseUrl: 'https://tokenhub.tencentmaas.com/v1',
      isOpenAiCompatible: true,
    ),
  ];
}