import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';

class AppSettings {
  AppSettings({
    required this.localeLanguageCode,
    required this.faceIdEnabled,
    required this.darkMode,
    this.titleModelProviderId,
    this.titleModelModelId,
    this.summaryModelProviderId,
    this.summaryModelModelId,
    this.chatDefaultProviderId,
    this.chatDefaultModelId,
    this.lastUsedChatProviderId,
    this.lastUsedChatModelId,
    this.ttsVoiceId,
    this.webSearchEnabledMap = const {},
  });

  final String? localeLanguageCode;
  final bool faceIdEnabled;
  final bool darkMode;
  final String? titleModelProviderId;
  final String? titleModelModelId;
  final String? summaryModelProviderId;
  final String? summaryModelModelId;
  final String? chatDefaultProviderId;
  final String? chatDefaultModelId;
  final String? lastUsedChatProviderId;
  final String? lastUsedChatModelId;
  final String? ttsVoiceId;

  /// 各提供商的联网搜索开关状态（key: providerType name, value: enabled）
  final Map<String, bool> webSearchEnabledMap;

  AppSettings copyWith({
    String? localeLanguageCode,
    bool? faceIdEnabled,
    bool? darkMode,
    String? titleModelProviderId,
    String? titleModelModelId,
    String? summaryModelProviderId,
    String? summaryModelModelId,
    String? chatDefaultProviderId,
    String? chatDefaultModelId,
    String? lastUsedChatProviderId,
    String? lastUsedChatModelId,
    String? ttsVoiceId,
    Map<String, bool>? webSearchEnabledMap,
  }) {
    return AppSettings(
      localeLanguageCode: localeLanguageCode ?? this.localeLanguageCode,
      faceIdEnabled: faceIdEnabled ?? this.faceIdEnabled,
      darkMode: darkMode ?? this.darkMode,
      titleModelProviderId: titleModelProviderId ?? this.titleModelProviderId,
      titleModelModelId: titleModelModelId ?? this.titleModelModelId,
      summaryModelProviderId: summaryModelProviderId ?? this.summaryModelProviderId,
      summaryModelModelId: summaryModelModelId ?? this.summaryModelModelId,
      chatDefaultProviderId: chatDefaultProviderId ?? this.chatDefaultProviderId,
      chatDefaultModelId: chatDefaultModelId ?? this.chatDefaultModelId,
      lastUsedChatProviderId: lastUsedChatProviderId ?? this.lastUsedChatProviderId,
      lastUsedChatModelId: lastUsedChatModelId ?? this.lastUsedChatModelId,
      ttsVoiceId: ttsVoiceId ?? this.ttsVoiceId,
      webSearchEnabledMap: webSearchEnabledMap ?? this.webSearchEnabledMap,
    );
  }

  /// 获取指定提供商的联网搜索开关状态
  ///
  /// 支持联网的提供商默认开启，不支持的默认关闭。
  /// 使用 dynamic 访问避免 hot reload 时旧实例字段为 null。
  bool isWebSearchEnabled(String providerTypeName) {
    try {
      return webSearchEnabledMap[providerTypeName] ?? true;
    } catch (_) {
      return true;
    }
  }
}

class SettingsStore {
  SettingsStore({required this._secureStorage});

  final FlutterSecureStorage _secureStorage;

  static const _keyLocale = 'locale_language_code';
  static const _keyFaceIdEnabled = 'face_id_enabled';
  static const _keyDarkMode = 'dark_mode';
  static const _keyTitleModelProviderId = 'title_model_provider_id';
  static const _keyTitleModelModelId = 'title_model_model_id';
  static const _keySummaryModelProviderId = 'summary_model_provider_id';
  static const _keySummaryModelModelId = 'summary_model_model_id';
  static const _keyChatDefaultProviderId = 'chat_default_provider_id';
  static const _keyChatDefaultModelId = 'chat_default_model_id';
  static const _keyLastUsedChatProviderId = 'last_used_chat_provider_id';
  static const _keyLastUsedChatModelId = 'last_used_chat_model_id';
  static const _keyTtsVoiceId = 'tts_voice_id';
  static const _keyWebSearchPrefix = 'web_search_enabled_';
  static final _webSearchKeys =
      webSearchSupportMap.keys.map((t) => t.name).toList();

  Future<AppSettings> load() async {
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
    final chatDefaultProviderId = await _secureStorage.read(key: _keyChatDefaultProviderId);
    final chatDefaultModelId = await _secureStorage.read(key: _keyChatDefaultModelId);
    final lastUsedChatProviderId = await _secureStorage.read(key: _keyLastUsedChatProviderId);
    final lastUsedChatModelId = await _secureStorage.read(key: _keyLastUsedChatModelId);
    final ttsVoiceId = await _secureStorage.read(key: _keyTtsVoiceId);

    final webSearchMap = <String, bool>{};
    for (final key in _webSearchKeys) {
      final val = await _secureStorage.read(key: '$_keyWebSearchPrefix$key');
      if (val != null) {
        webSearchMap[key] = val == 'true';
      }
    }

    return AppSettings(
      localeLanguageCode: locale,
      faceIdEnabled: faceIdEnabled,
      darkMode: darkMode,
      titleModelProviderId: titleModelProviderId,
      titleModelModelId: titleModelModelId,
      summaryModelProviderId: summaryModelProviderId,
      summaryModelModelId: summaryModelModelId,
      chatDefaultProviderId: chatDefaultProviderId,
      chatDefaultModelId: chatDefaultModelId,
      lastUsedChatProviderId: lastUsedChatProviderId,
      lastUsedChatModelId: lastUsedChatModelId,
      ttsVoiceId: ttsVoiceId,
      webSearchEnabledMap: webSearchMap,
    );
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

  Future<void> saveChatDefaultModel({String? providerId, String? modelId}) async {
    if (providerId == null || modelId == null) {
      await _secureStorage.delete(key: _keyChatDefaultProviderId);
      await _secureStorage.delete(key: _keyChatDefaultModelId);
    } else {
      await _secureStorage.write(key: _keyChatDefaultProviderId, value: providerId);
      await _secureStorage.write(key: _keyChatDefaultModelId, value: modelId);
    }
  }

  Future<void> saveLastUsedChatModel({String? providerId, String? modelId}) async {
    if (providerId == null || modelId == null) {
      await _secureStorage.delete(key: _keyLastUsedChatProviderId);
      await _secureStorage.delete(key: _keyLastUsedChatModelId);
    } else {
      await _secureStorage.write(key: _keyLastUsedChatProviderId, value: providerId);
      await _secureStorage.write(key: _keyLastUsedChatModelId, value: modelId);
    }
  }

  /// TTS 选中的声音 ID（null = 清除 / 用系统默认）
  Future<void> saveTtsVoiceId(String? voiceId) async {
    if (voiceId == null || voiceId.isEmpty) {
      await _secureStorage.delete(key: _keyTtsVoiceId);
    } else {
      await _secureStorage.write(key: _keyTtsVoiceId, value: voiceId);
    }
  }

  /// 保存指定提供商的联网搜索开关状态
  Future<void> saveWebSearchEnabled(String providerType, bool enabled) async {
    await _secureStorage.write(
      key: '$_keyWebSearchPrefix$providerType',
      value: enabled.toString(),
    );
  }
}
