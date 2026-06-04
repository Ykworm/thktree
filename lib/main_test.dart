import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_logger.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/router.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/data/services/settings_store.dart';

/// 测试专用入口
/// 
/// 集成测试使用的简化版入口，跳过了部分初始化逻辑
Future<Widget> createTestApp() async {
  final paths = await AppPaths.load();
  await paths.ensureCreated();

  final secureStorage = FlutterSecureStorage();
  final settingsStore = SettingsStore(secureStorage: secureStorage);
  final savedSettings = await settingsStore.load();
  final initialLocale = savedSettings.localeLanguageCode == null
      ? null
      : Locale(savedSettings.localeLanguageCode!);

  return ProviderScope(
    overrides: [
      appPathsProvider.overrideWithValue(AsyncData(paths)),
      localeProvider.overrideWith(() => LocaleNotifier(initialLocale)),
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
