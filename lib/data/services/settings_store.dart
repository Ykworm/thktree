import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    this.ttsVoiceId,
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
  final String? ttsVoiceId;

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
    String? ttsVoiceId,
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
      ttsVoiceId: ttsVoiceId ?? this.ttsVoiceId,
    );
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
  static const _keyTtsVoiceId = 'tts_voice_id';

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
    final ttsVoiceId = await _secureStorage.read(key: _keyTtsVoiceId);

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
      ttsVoiceId: ttsVoiceId,
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

  /// TTS 选中的声音 ID（null = 清除 / 用系统默认）
  Future<void> saveTtsVoiceId(String? voiceId) async {
    if (voiceId == null || voiceId.isEmpty) {
      await _secureStorage.delete(key: _keyTtsVoiceId);
    } else {
      await _secureStorage.write(key: _keyTtsVoiceId, value: voiceId);
    }
  }
}
