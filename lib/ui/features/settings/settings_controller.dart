import 'package:flutter/cupertino.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/data/services/llm_provider.dart';

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final store = ref.read(settingsStoreProvider);
    return store.load();
  }

  Future<void> saveProvider(LlmProvider provider) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveProvider(provider);
    state = AsyncData(await store.load());
  }

  Future<void> saveApiKey(LlmProvider provider, String apiKey) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveApiKey(provider, apiKey);
    state = AsyncData(await store.load());
  }

  Future<void> saveModel(LlmProvider provider, String model) async {
    final store = ref.read(settingsStoreProvider);
    await store.saveModel(provider, model);
    state = AsyncData(await store.load());
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

  Future<void> clearAllDefaultModels() async {
    final store = ref.read(settingsStoreProvider);
    await store.saveTitleModel(providerId: null, modelId: null);
    await store.saveSummaryModel(providerId: null, modelId: null);
    await store.saveChatDefaultModel(providerId: null, modelId: null);
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
