import 'package:flutter/painting.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thk_tree/data/services/llm_provider.dart';

class AppSettings {
  AppSettings({
    required this.llmProvider,
    required this.deepSeekApiKey,
    required this.openaiApiKey,
    required this.claudeApiKey,
    required this.geminiApiKey,
    required this.minimaxApiKey,
    required this.kimiApiKey,
    required this.deepSeekModel,
    required this.openaiModel,
    required this.claudeModel,
    required this.geminiModel,
    required this.minimaxModel,
    required this.kimiModel,
    required this.localeLanguageCode,
    required this.faceIdEnabled,
    required this.darkMode,
    this.titleModelProviderId,
    this.titleModelModelId,
    this.summaryModelProviderId,
    this.summaryModelModelId,
  });

  final LlmProvider llmProvider;
  final String deepSeekApiKey;
  final String openaiApiKey;
  final String claudeApiKey;
  final String geminiApiKey;
  final String minimaxApiKey;
  final String kimiApiKey;
  final String deepSeekModel;
  final String openaiModel;
  final String claudeModel;
  final String geminiModel;
  final String minimaxModel;
  final String kimiModel;
  final String? localeLanguageCode;
  final bool faceIdEnabled;
  final bool darkMode;
  final String? titleModelProviderId;
  final String? titleModelModelId;
  final String? summaryModelProviderId;
  final String? summaryModelModelId;

  String get apiKey {
    switch (llmProvider) {
      case LlmProvider.deepseek:
        return deepSeekApiKey;
      case LlmProvider.openai:
        return openaiApiKey;
      case LlmProvider.claude:
        return claudeApiKey;
      case LlmProvider.gemini:
        return geminiApiKey;
      case LlmProvider.minimax:
        return minimaxApiKey;
      case LlmProvider.kimi:
        return kimiApiKey;
    }
  }

  String get model {
    switch (llmProvider) {
      case LlmProvider.deepseek:
        return deepSeekModel;
      case LlmProvider.openai:
        return openaiModel;
      case LlmProvider.claude:
        return claudeModel;
      case LlmProvider.gemini:
        return geminiModel;
      case LlmProvider.minimax:
        return minimaxModel;
      case LlmProvider.kimi:
        return kimiModel;
    }
  }

  AppSettings copyWith({
    LlmProvider? llmProvider,
    String? deepSeekApiKey,
    String? openaiApiKey,
    String? claudeApiKey,
    String? geminiApiKey,
    String? minimaxApiKey,
    String? kimiApiKey,
    String? deepSeekModel,
    String? openaiModel,
    String? claudeModel,
    String? geminiModel,
    String? minimaxModel,
    String? kimiModel,
    String? localeLanguageCode,
    bool? faceIdEnabled,
    bool? darkMode,
    String? titleModelProviderId,
    String? titleModelModelId,
    String? summaryModelProviderId,
    String? summaryModelModelId,
  }) {
    return AppSettings(
      llmProvider: llmProvider ?? this.llmProvider,
      deepSeekApiKey: deepSeekApiKey ?? this.deepSeekApiKey,
      openaiApiKey: openaiApiKey ?? this.openaiApiKey,
      claudeApiKey: claudeApiKey ?? this.claudeApiKey,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      minimaxApiKey: minimaxApiKey ?? this.minimaxApiKey,
      kimiApiKey: kimiApiKey ?? this.kimiApiKey,
      deepSeekModel: deepSeekModel ?? this.deepSeekModel,
      openaiModel: openaiModel ?? this.openaiModel,
      claudeModel: claudeModel ?? this.claudeModel,
      geminiModel: geminiModel ?? this.geminiModel,
      minimaxModel: minimaxModel ?? this.minimaxModel,
      kimiModel: kimiModel ?? this.kimiModel,
      localeLanguageCode: localeLanguageCode ?? this.localeLanguageCode,
      faceIdEnabled: faceIdEnabled ?? this.faceIdEnabled,
      darkMode: darkMode ?? this.darkMode,
      titleModelProviderId: titleModelProviderId ?? this.titleModelProviderId,
      titleModelModelId: titleModelModelId ?? this.titleModelModelId,
      summaryModelProviderId: summaryModelProviderId ?? this.summaryModelProviderId,
      summaryModelModelId: summaryModelModelId ?? this.summaryModelModelId,
    );
  }
}

class SettingsStore {
  SettingsStore({required this._secureStorage});

  final FlutterSecureStorage _secureStorage;

  static const _keyLocale = 'locale_language_code';
  static const _keyProvider = 'llm_provider';
  static const _keyFaceIdEnabled = 'face_id_enabled';
  static const _keyDarkMode = 'dark_mode';
  static const _keyTitleModelProviderId = 'title_model_provider_id';
  static const _keyTitleModelModelId = 'title_model_model_id';
  static const _keySummaryModelProviderId = 'summary_model_provider_id';
  static const _keySummaryModelModelId = 'summary_model_model_id';

  static String _apiKeyKey(LlmProvider p) => 'llm_api_key_${p.name}';
  static String _modelKey(LlmProvider p) => 'llm_model_${p.name}';

  Future<AppSettings> load() async {
    final providerName = await _secureStorage.read(key: _keyProvider) ?? 'deepseek';
    final provider = LlmProvider.values.firstWhere(
      (p) => p.name == providerName,
      orElse: () => LlmProvider.deepseek,
    );

    final deepSeekApiKey = await _secureStorage.read(key: _apiKeyKey(LlmProvider.deepseek)) ?? '';
    final openaiApiKey = await _secureStorage.read(key: _apiKeyKey(LlmProvider.openai)) ?? '';
    final claudeApiKey = await _secureStorage.read(key: _apiKeyKey(LlmProvider.claude)) ?? '';
    final geminiApiKey = await _secureStorage.read(key: _apiKeyKey(LlmProvider.gemini)) ?? '';
    final minimaxApiKey = await _secureStorage.read(key: _apiKeyKey(LlmProvider.minimax)) ?? '';
    final kimiApiKey = await _secureStorage.read(key: _apiKeyKey(LlmProvider.kimi)) ?? '';

    final deepSeekModel = await _secureStorage.read(key: _modelKey(LlmProvider.deepseek)) ?? LlmProvider.deepseek.defaultModel;
    final openaiModel = await _secureStorage.read(key: _modelKey(LlmProvider.openai)) ?? LlmProvider.openai.defaultModel;
    final claudeModel = await _secureStorage.read(key: _modelKey(LlmProvider.claude)) ?? LlmProvider.claude.defaultModel;
    final geminiModel = await _secureStorage.read(key: _modelKey(LlmProvider.gemini)) ?? LlmProvider.gemini.defaultModel;
    final minimaxModel = await _secureStorage.read(key: _modelKey(LlmProvider.minimax)) ?? LlmProvider.minimax.defaultModel;
    final kimiModel = await _secureStorage.read(key: _modelKey(LlmProvider.kimi)) ?? LlmProvider.kimi.defaultModel;

    final locale = await _secureStorage.read(key: _keyLocale);
    final faceIdStr = await _secureStorage.read(key: _keyFaceIdEnabled);
    // Default: true (Face ID ON by default)
    final faceIdEnabled = faceIdStr == null ? true : faceIdStr == 'true';

    final darkModeStr = await _secureStorage.read(key: _keyDarkMode);
    final darkMode = darkModeStr == 'true';

    final titleModelProviderId = await _secureStorage.read(key: _keyTitleModelProviderId);
    final titleModelModelId = await _secureStorage.read(key: _keyTitleModelModelId);
    final summaryModelProviderId = await _secureStorage.read(key: _keySummaryModelProviderId);
    final summaryModelModelId = await _secureStorage.read(key: _keySummaryModelModelId);

    return AppSettings(
      llmProvider: provider,
      deepSeekApiKey: deepSeekApiKey,
      openaiApiKey: openaiApiKey,
      claudeApiKey: claudeApiKey,
      geminiApiKey: geminiApiKey,
      minimaxApiKey: minimaxApiKey,
      kimiApiKey: kimiApiKey,
      deepSeekModel: deepSeekModel,
      openaiModel: openaiModel,
      claudeModel: claudeModel,
      geminiModel: geminiModel,
      minimaxModel: minimaxModel,
      kimiModel: kimiModel,
      localeLanguageCode: locale,
      faceIdEnabled: faceIdEnabled,
      darkMode: darkMode,
      titleModelProviderId: titleModelProviderId,
      titleModelModelId: titleModelModelId,
      summaryModelProviderId: summaryModelProviderId,
      summaryModelModelId: summaryModelModelId,
    );
  }

  Future<void> saveProvider(LlmProvider provider) async {
    await _secureStorage.write(key: _keyProvider, value: provider.name);
  }

  Future<void> saveApiKey(LlmProvider provider, String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await _secureStorage.delete(key: _apiKeyKey(provider));
      return;
    }
    await _secureStorage.write(key: _apiKeyKey(provider), value: trimmed);
  }

  Future<void> saveModel(LlmProvider provider, String model) async {
    final trimmed = model.trim();
    if (trimmed.isEmpty) return;
    await _secureStorage.write(key: _modelKey(provider), value: trimmed);
  }

  Future<void> saveLocale(String? languageCode) async {
    if (languageCode == null || languageCode.isEmpty) {
      await _secureStorage.delete(key: _keyLocale);
    } else {
      await _secureStorage.write(key: _keyLocale, value: languageCode);
    }
  }

  Future<void> saveFaceIdEnabled(bool enabled) async {
    await _secureStorage.write(key: _keyFaceIdEnabled, value: enabled.toString());
  }

  Future<void> saveDarkMode(bool dark) async {
    await _secureStorage.write(key: _keyDarkMode, value: dark.toString());
  }

  Future<void> saveTitleModel({String? providerId, String? modelId}) async {
    if (providerId == null || modelId == null) {
      await _secureStorage.delete(key: _keyTitleModelProviderId);
      await _secureStorage.delete(key: _keyTitleModelModelId);
    } else {
      await _secureStorage.write(key: _keyTitleModelProviderId, value: providerId);
      await _secureStorage.write(key: _keyTitleModelModelId, value: modelId);
    }
  }

  Future<void> saveSummaryModel({String? providerId, String? modelId}) async {
    if (providerId == null || modelId == null) {
      await _secureStorage.delete(key: _keySummaryModelProviderId);
      await _secureStorage.delete(key: _keySummaryModelModelId);
    } else {
      await _secureStorage.write(key: _keySummaryModelProviderId, value: providerId);
      await _secureStorage.write(key: _keySummaryModelModelId, value: modelId);
    }
  }
}
