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
  doubao,
  /// xAI Grok（SuperGrok / 控制台 API Key；OpenAI 兼容 `api.x.ai/v1`）
  xai,
  /// 腾讯 TokenHub（Hy3 等；OpenAI 兼容 `tokenhub.tencentmaas.com/v1`）
  tokenhub,
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
      case LlmProviderType.doubao:
        return '豆包';
      case LlmProviderType.xai:
        return 'xAI Grok';
      case LlmProviderType.tokenhub:
        return '腾讯 TokenHub';
      case LlmProviderType.custom:
        return '自定义';
    }
  }
}

/// 联网搜索支持状态
enum WebSearchSupport {
  /// 官方原生支持
  supported,

  /// 官方不支持
  unsupported,
}

/// APP 当前支持在设置页面显示的提供商类型
const Set<LlmProviderType> visibleProviderTypes = {
  LlmProviderType.kimi,
  LlmProviderType.minimax,
  LlmProviderType.mimo,
  LlmProviderType.deepseek,
  LlmProviderType.doubao,
  LlmProviderType.xai,
  LlmProviderType.tokenhub,
};

/// 各提供商的联网搜索支持状态
///
/// 新模型接入时更新此映射（APP update 更新）。
///
/// MiniMax：官方联网是 Anthropic Messages 的服务端工具
/// `web_search_20250305`（见 platform.minimaxi.com Server Tools），
/// 当前客户端仍走 OpenAI 兼容 Chat Completions + 假 function `web_search`，
/// 无真实搜索执行。暂标 unsupported，避免 UI 误导；真实现前勿改回 supported。
const Map<LlmProviderType, WebSearchSupport> webSearchSupportMap = {
  LlmProviderType.kimi: WebSearchSupport.supported,
  LlmProviderType.minimax: WebSearchSupport.unsupported,
  LlmProviderType.mimo: WebSearchSupport.supported,
  LlmProviderType.deepseek: WebSearchSupport.supported,
  LlmProviderType.doubao: WebSearchSupport.supported,
  // xAI：Chat Completions 用 search_parameters.mode（服务端搜索），非 function tools
  LlmProviderType.xai: WebSearchSupport.supported,
  // TokenHub：平台支持 tools/function calling，无独立原生联网搜索协议映射
  LlmProviderType.tokenhub: WebSearchSupport.unsupported,
};

/// 某些具体模型虽属于「支持联网」的提供商，但该模型自身走 legacy 路径，
/// 实际无法联网搜索。在 UI 可见性与发送侧统一排除，避免显示无效按钮。
///
/// 例：豆包 Seed-2.0-pro（旧版，无日期后缀）走 legacy Chat Completions API，
/// 火山方舟联网搜索需 250615+ 版本，故不可联网。
bool isModelWebSearchUnsupported(String modelId) {
  final lower = modelId.toLowerCase();
  if (!lower.contains('doubao-seed-2-0-pro')) return false;
  // 如果有日期后缀（如 -260215），则支持网络搜索
  final datePattern = RegExp(r'-\d{6}$');
  return !datePattern.hasMatch(lower);
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
