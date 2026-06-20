import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:thk_tree/data/stores/llm_config_store.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/router.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/data/services/settings_store.dart';

/// 测试专用入口
///
/// 集成测试使用的简化版入口，跳过了部分初始化逻辑。
///
/// [locale]：覆盖默认 locale 解析；不传则沿用用户 Settings 里保存的设置，
/// 用户未设置时为 null（由 [ThkTreeApp.localeResolutionCallback] fallback 到 en）。
///
/// [llmSettings]：覆盖从 secure storage 读出的 [AppSettings]（LLM 厂商/Key 等）。
/// 不传则走真实 SettingsStore.load()，simulator Keychain 空时会拿到空 Key。
/// 测试 LLM 链路时必须传入，否则 LLM 调用会因缺 Key 失败。
///
/// [llmConfigStore]：直接覆盖 [LlmConfigStore] provider。Simulator 沙盒里
/// `getApplicationDocumentsDirectory()/llm_providers.json` 文件不存在且
/// Keychain 中 `llm_key_{providerId}` 为空，所以 chat_controller 的 3 路径
/// 查找 API Key 全部失败，会卡在 "[未配置 API Key]"。测试必须传入假 store。
/// 传 null 则不 override（仅当不需要触发 LLM 链路时使用）。
Future<Widget> createTestApp({
  Locale? locale,
  AppSettings? llmSettings,
  LlmConfigStore? llmConfigStore,
}) async {
  final paths = await AppPaths.load();
  await paths.ensureCreated();

  if (llmSettings == null) {
    final secureStorage = FlutterSecureStorage();
    final settingsStore = SettingsStore(secureStorage: secureStorage);
    final savedSettings = await settingsStore.load();
    // 参数优先级最高 → settings 已保存 → null
    final Locale? initialLocale = locale ??
        (savedSettings.localeLanguageCode == null
            ? null
            : Locale(savedSettings.localeLanguageCode!));
    return _buildProviderScope(
      paths: paths,
      initialLocale: initialLocale,
      llmSettings: null,
      llmConfigStore: llmConfigStore,
    );
  }

  // 传了 llmSettings：locale 优先级仍然参数 > llmSettings > null
  final Locale? initialLocale =
      locale ?? (llmSettings.localeLanguageCode == null
          ? null
          : Locale(llmSettings.localeLanguageCode!));
  return _buildProviderScope(
    paths: paths,
    initialLocale: initialLocale,
    llmSettings: llmSettings,
    llmConfigStore: llmConfigStore,
  );
}

Widget _buildProviderScope({
  required AppPaths paths,
  required Locale? initialLocale,
  required AppSettings? llmSettings,
  required LlmConfigStore? llmConfigStore,
}) {
  return ProviderScope(
    overrides: [
      appPathsProvider.overrideWithValue(AsyncData(paths)),
      localeProvider.overrideWith(() => LocaleNotifier(initialLocale)),
      if (llmSettings != null)
        appSettingsProvider.overrideWith((ref) async => llmSettings),
      if (llmConfigStore != null)
        llmConfigStoreProvider.overrideWithValue(llmConfigStore),
    ],
    child: const ThkTreeApp(),
  );
}

class ThkTreeApp extends ConsumerWidget {
  const ThkTreeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return CupertinoApp.router(
      locale: locale,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return const Locale('en');
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode) {
            return supported;
          }
        }
        return const Locale('en');
      },
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
      builder: (context, child) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
