import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';

class AppSettings {
  AppSettings({
    required this.localeLanguageCode,
    required this.faceIdEnabled,
    required this.darkMode,
    this.colorPalette,
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
    this.autoBackupEnabled = true,
    this.backupReminderEnabled = true,
    this.nextBackupReminderDate,
    this.lastAutoBackupAt,
    this.backupReminderIntervalDays = 3,
    this.llmSetupOnboardingShown = false,
  });

  final String? localeLanguageCode;
  final bool faceIdEnabled;
  final bool darkMode;
  final String? colorPalette;
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

  /// 自动备份开关（默认开启）
  final bool autoBackupEnabled;

  /// 备份提醒开关（默认开启）
  final bool backupReminderEnabled;

  /// 下次备份提醒日期
  final DateTime? nextBackupReminderDate;

  /// 上次自动备份时间（用于判断 24h 周期，与提醒日期独立）
  final DateTime? lastAutoBackupAt;

  /// 分享提醒周期（天），默认 3
  final int backupReminderIntervalDays;

  /// 是否已展示过首次 LLM 设置引导（弹窗只出现一次）
  final bool llmSetupOnboardingShown;

  AppSettings copyWith({
    String? localeLanguageCode,
    bool? faceIdEnabled,
    bool? darkMode,
    String? colorPalette,
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
    bool? autoBackupEnabled,
    bool? backupReminderEnabled,
    DateTime? nextBackupReminderDate,
    DateTime? lastAutoBackupAt,
    int? backupReminderIntervalDays,
    bool? llmSetupOnboardingShown,
  }) {
    return AppSettings(
      localeLanguageCode: localeLanguageCode ?? this.localeLanguageCode,
      faceIdEnabled: faceIdEnabled ?? this.faceIdEnabled,
      darkMode: darkMode ?? this.darkMode,
      colorPalette: colorPalette ?? this.colorPalette,
      titleModelProviderId: titleModelProviderId ?? this.titleModelProviderId,
      titleModelModelId: titleModelModelId ?? this.titleModelModelId,
      summaryModelProviderId:
          summaryModelProviderId ?? this.summaryModelProviderId,
      summaryModelModelId: summaryModelModelId ?? this.summaryModelModelId,
      chatDefaultProviderId:
          chatDefaultProviderId ?? this.chatDefaultProviderId,
      chatDefaultModelId: chatDefaultModelId ?? this.chatDefaultModelId,
      lastUsedChatProviderId:
          lastUsedChatProviderId ?? this.lastUsedChatProviderId,
      lastUsedChatModelId: lastUsedChatModelId ?? this.lastUsedChatModelId,
      ttsVoiceId: ttsVoiceId ?? this.ttsVoiceId,
      webSearchEnabledMap: webSearchEnabledMap ?? this.webSearchEnabledMap,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      backupReminderEnabled:
          backupReminderEnabled ?? this.backupReminderEnabled,
      nextBackupReminderDate:
          nextBackupReminderDate ?? this.nextBackupReminderDate,
      lastAutoBackupAt: lastAutoBackupAt ?? this.lastAutoBackupAt,
      backupReminderIntervalDays:
          backupReminderIntervalDays ?? this.backupReminderIntervalDays,
      llmSetupOnboardingShown:
          llmSetupOnboardingShown ?? this.llmSetupOnboardingShown,
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
  static const _keyColorPalette = 'color_palette';
  static const _keyTitleModelProviderId = 'title_model_provider_id';
  static const _keyTitleModelModelId = 'title_model_model_id';
  static const _keySummaryModelProviderId = 'summary_model_provider_id';
  static const _keySummaryModelModelId = 'summary_model_model_id';
  static const _keyChatDefaultProviderId = 'chat_default_provider_id';
  static const _keyChatDefaultModelId = 'chat_default_model_id';
  static const _keyLastUsedChatProviderId = 'last_used_chat_provider_id';
  static const _keyLastUsedChatModelId = 'last_used_chat_model_id';
  static const _keyTtsVoiceId = 'tts_voice_id';
  static const _keyAutoBackupEnabled = 'auto_backup_enabled';
  static const _keyBackupReminderEnabled = 'backup_reminder_enabled';
  static const _keyNextBackupReminderDate = 'next_backup_reminder_date';
  static const _keyLastAutoBackupAt = 'last_auto_backup_at';
  static const _keyBackupReminderIntervalDays = 'backup_reminder_interval_days';
  static const _keyLlmSetupOnboardingShown = 'llm_setup_onboarding_shown';
  static const _keyWebSearchPrefix = 'web_search_enabled_';
  static final _webSearchKeys = webSearchSupportMap.keys
      .map((t) => t.name)
      .toList();

  Future<AppSettings> load() async {
    final locale = await _secureStorage.read(key: _keyLocale);
    final faceIdStr = await _secureStorage.read(key: _keyFaceIdEnabled);
    // Default: false (app-lock OFF by default — avoids blocking dev/test runs)
    final faceIdEnabled = faceIdStr == null ? false : faceIdStr == 'true';

    final darkModeStr = await _secureStorage.read(key: _keyDarkMode);
    final darkMode = darkModeStr == 'true';

    final colorPalette = await _secureStorage.read(key: _keyColorPalette);

    final titleModelProviderId = await _secureStorage.read(
      key: _keyTitleModelProviderId,
    );
    final titleModelModelId = await _secureStorage.read(
      key: _keyTitleModelModelId,
    );
    final summaryModelProviderId = await _secureStorage.read(
      key: _keySummaryModelProviderId,
    );
    final summaryModelModelId = await _secureStorage.read(
      key: _keySummaryModelModelId,
    );
    final chatDefaultProviderId = await _secureStorage.read(
      key: _keyChatDefaultProviderId,
    );
    final chatDefaultModelId = await _secureStorage.read(
      key: _keyChatDefaultModelId,
    );
    final lastUsedChatProviderId = await _secureStorage.read(
      key: _keyLastUsedChatProviderId,
    );
    final lastUsedChatModelId = await _secureStorage.read(
      key: _keyLastUsedChatModelId,
    );
    final ttsVoiceId = await _secureStorage.read(key: _keyTtsVoiceId);

    final autoBackupEnabledStr = await _secureStorage.read(
      key: _keyAutoBackupEnabled,
    );
    final autoBackupEnabled = autoBackupEnabledStr == null
        ? true
        : autoBackupEnabledStr == 'true';

    final backupReminderEnabledStr = await _secureStorage.read(
      key: _keyBackupReminderEnabled,
    );
    // Default: true (backup reminder ON by default)
    final backupReminderEnabled = backupReminderEnabledStr == null
        ? true
        : backupReminderEnabledStr == 'true';

    final nextBackupReminderDateStr = await _secureStorage.read(
      key: _keyNextBackupReminderDate,
    );
    final nextBackupReminderDate = nextBackupReminderDateStr == null
        ? null
        : DateTime.tryParse(nextBackupReminderDateStr);

    final lastAutoBackupAtStr = await _secureStorage.read(
      key: _keyLastAutoBackupAt,
    );
    final lastAutoBackupAt = lastAutoBackupAtStr == null
        ? null
        : DateTime.tryParse(lastAutoBackupAtStr);

    final backupReminderIntervalDaysStr = await _secureStorage.read(
      key: _keyBackupReminderIntervalDays,
    );
    final backupReminderIntervalDays = backupReminderIntervalDaysStr == null
        ? 3
        : (int.tryParse(backupReminderIntervalDaysStr) ?? 3);

    final llmSetupOnboardingShownStr =
        await _secureStorage.read(key: _keyLlmSetupOnboardingShown);
    final llmSetupOnboardingShown = llmSetupOnboardingShownStr == 'true';

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
      colorPalette: colorPalette,
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
      autoBackupEnabled: autoBackupEnabled,
      backupReminderEnabled: backupReminderEnabled,
      nextBackupReminderDate: nextBackupReminderDate,
      lastAutoBackupAt: lastAutoBackupAt,
      backupReminderIntervalDays: backupReminderIntervalDays,
      llmSetupOnboardingShown: llmSetupOnboardingShown,
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
    await _secureStorage.write(
      key: _keyFaceIdEnabled,
      value: enabled.toString(),
    );
  }

  Future<void> saveDarkMode(bool dark) async {
    await _secureStorage.write(key: _keyDarkMode, value: dark.toString());
  }

  Future<void> saveColorPalette(String? value) async {
    if (value == null || value.isEmpty) {
      await _secureStorage.delete(key: _keyColorPalette);
    } else {
      await _secureStorage.write(key: _keyColorPalette, value: value);
    }
  }

  Future<void> saveTitleModel({String? providerId, String? modelId}) async {
    if (providerId == null || modelId == null) {
      await _secureStorage.delete(key: _keyTitleModelProviderId);
      await _secureStorage.delete(key: _keyTitleModelModelId);
    } else {
      await _secureStorage.write(
        key: _keyTitleModelProviderId,
        value: providerId,
      );
      await _secureStorage.write(key: _keyTitleModelModelId, value: modelId);
    }
  }

  Future<void> saveSummaryModel({String? providerId, String? modelId}) async {
    if (providerId == null || modelId == null) {
      await _secureStorage.delete(key: _keySummaryModelProviderId);
      await _secureStorage.delete(key: _keySummaryModelModelId);
    } else {
      await _secureStorage.write(
        key: _keySummaryModelProviderId,
        value: providerId,
      );
      await _secureStorage.write(key: _keySummaryModelModelId, value: modelId);
    }
  }

  Future<void> saveChatDefaultModel({
    String? providerId,
    String? modelId,
  }) async {
    if (providerId == null || modelId == null) {
      await _secureStorage.delete(key: _keyChatDefaultProviderId);
      await _secureStorage.delete(key: _keyChatDefaultModelId);
    } else {
      await _secureStorage.write(
        key: _keyChatDefaultProviderId,
        value: providerId,
      );
      await _secureStorage.write(key: _keyChatDefaultModelId, value: modelId);
    }
  }

  Future<void> saveLastUsedChatModel({
    String? providerId,
    String? modelId,
  }) async {
    if (providerId == null || modelId == null) {
      await _secureStorage.delete(key: _keyLastUsedChatProviderId);
      await _secureStorage.delete(key: _keyLastUsedChatModelId);
    } else {
      await _secureStorage.write(
        key: _keyLastUsedChatProviderId,
        value: providerId,
      );
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

  /// 保存自动备份开关状态
  Future<void> saveAutoBackupEnabled(bool enabled) async {
    await _secureStorage.write(
      key: _keyAutoBackupEnabled,
      value: enabled.toString(),
    );
  }

  /// 保存备份提醒开关状态
  Future<void> saveBackupReminderEnabled(bool enabled) async {
    await _secureStorage.write(
      key: _keyBackupReminderEnabled,
      value: enabled.toString(),
    );
  }

  /// 保存下次备份提醒日期
  Future<void> saveNextBackupReminderDate(DateTime? date) async {
    if (date == null) {
      await _secureStorage.delete(key: _keyNextBackupReminderDate);
    } else {
      await _secureStorage.write(
        key: _keyNextBackupReminderDate,
        value: date.toIso8601String(),
      );
    }
  }

  /// 保存上次自动备份时间
  Future<void> saveLastAutoBackupAt(DateTime? date) async {
    if (date == null) {
      await _secureStorage.delete(key: _keyLastAutoBackupAt);
    } else {
      await _secureStorage.write(
        key: _keyLastAutoBackupAt,
        value: date.toIso8601String(),
      );
    }
  }

  /// 保存分享提醒周期（天）
  Future<void> saveBackupReminderIntervalDays(int days) async {
    await _secureStorage.write(
      key: _keyBackupReminderIntervalDays,
      value: days.toString(),
    );
  }

  /// 标记首次 LLM 设置引导已展示
  Future<void> saveLlmSetupOnboardingShown(bool shown) async {
    await _secureStorage.write(
      key: _keyLlmSetupOnboardingShown,
      value: shown.toString(),
    );
  }
}
