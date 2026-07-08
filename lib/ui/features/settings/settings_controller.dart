import 'package:flutter/cupertino.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/data/services/settings_store.dart';

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final store = ref.read(settingsStoreProvider);
    return store.load();
  }

  Future<void> saveLocale(String? languageCode) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveLocale(languageCode);
    ref.read(localeProvider.notifier).updateLocale(
        languageCode == null ? null : Locale(languageCode));
    state = AsyncData(await store.load());
  }

  Future<void> saveFaceIdEnabled(bool enabled) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveFaceIdEnabled(enabled);
    state = AsyncData(await store.load());
  }

  Future<void> saveDarkMode(bool dark) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveDarkMode(dark);
    state = AsyncData(await store.load());
  }

  Future<void> saveTitleModel({String? providerId, String? modelId}) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveTitleModel(providerId: providerId, modelId: modelId);
    state = AsyncData(await store.load());
  }

  Future<void> saveSummaryModel({String? providerId, String? modelId}) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveSummaryModel(providerId: providerId, modelId: modelId);
    state = AsyncData(await store.load());
  }

  Future<void> saveChatDefaultModel({String? providerId, String? modelId}) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveChatDefaultModel(providerId: providerId, modelId: modelId);
    state = AsyncData(await store.load());
  }

  Future<void> saveLastUsedChatModel({String? providerId, String? modelId}) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveLastUsedChatModel(providerId: providerId, modelId: modelId);
    state = AsyncData(await store.load());
  }

  Future<void> clearAllDefaultModels() async {
    final store = ref.read(settingsStoreProvider);
    await store.saveTitleModel(providerId: null, modelId: null);
    await store.saveSummaryModel(providerId: null, modelId: null);
    await store.saveChatDefaultModel(providerId: null, modelId: null);
    state = AsyncData(await store.load());
  }

  Future<void> saveWebSearchEnabled(String providerType, bool enabled) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveWebSearchEnabled(providerType, enabled);
    state = AsyncData(await store.load());
  }

  Future<void> saveAutoBackupEnabled(bool enabled) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveAutoBackupEnabled(enabled);
    state = AsyncData(await store.load());
  }

  Future<void> saveBackupReminderEnabled(bool enabled) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveBackupReminderEnabled(enabled);
    state = AsyncData(await store.load());
  }

  Future<void> saveNextBackupReminderDate(DateTime? date) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveNextBackupReminderDate(date);
    state = AsyncData(await store.load());
  }

  Future<void> saveLastAutoBackupAt(DateTime? date) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveLastAutoBackupAt(date);
    state = AsyncData(await store.load());
  }

  Future<void> saveBackupReminderIntervalDays(int days) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveBackupReminderIntervalDays(days);
    state = AsyncData(await store.load());
  }

  /// Dev 调试：将下次提醒日期设为昨天，方便测试横幅显示
  Future<void> triggerBackupReminderDebug() async {
    final store = ref.read(settingsStoreProvider);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await store.saveNextBackupReminderDate(yesterday);
    state = AsyncData(await store.load());
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class LocaleNotifier extends Notifier<Locale?> {
  LocaleNotifier(this._initialLocale);

  final Locale? _initialLocale;

  @override
  Locale? build() => _initialLocale;

  void updateLocale(Locale? locale) {
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(() => LocaleNotifier(null));

final initialBrightnessProvider = Provider<Brightness>((ref) => Brightness.light);

class BrightnessNotifier extends Notifier<Brightness> {
  @override
  Brightness build() {
    return ref.watch(initialBrightnessProvider);
  }

  void setBrightness(Brightness b) {
    state = b;
  }

  void toggle() {
    state = state == Brightness.light
        ? Brightness.dark
        : Brightness.light;
  }
}

final brightnessProvider =
    NotifierProvider<BrightnessNotifier, Brightness>(BrightnessNotifier.new);
