import 'dart:ui';

import 'package:alibabacloud_rum_flutter_plugin/alibabacloud_rum_flutter_plugin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_logger.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/auth_gate.dart';
import 'package:thk_tree/ui/core/router.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/data/services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化阿里云 RUM SDK（不自动 runApp）
  await AlibabaCloudRUM().initialize();

  final paths = await AppPaths.load();
  await paths.ensureCreated();

  final remoteLogUrl = const String.fromEnvironment('THKTREE_LOG_URL');
  final logger = AppLogger(paths: paths, remoteLogUrl: remoteLogUrl);
  await logger.init();
  await logger.info(
    'app.started',
    attrs: {
      'remoteLogging': logger.hasRemoteLogging,
      'remoteLogUrl': logger.remoteLogUrl,
    },
  );

  final errorCounts = <String, int>{};
  const maxSameError = 10;

  FlutterError.onError = (details) {
    logger.flutterError(details.exception, details.stack ?? StackTrace.current);
    final key = details.exceptionAsString();
    final count = (errorCounts[key] ?? 0) + 1;
    errorCounts[key] = count;
    if (count <= maxSameError) {
      FlutterError.presentError(details);
      if (count == maxSameError) {
        debugPrint('[FlutterError] Suppressing further instances of: ${key.length > 80 ? key.substring(0, 80) : key}...');
      }
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error(error, stack, hint: 'PlatformDispatcher');
    return true;
  };

  final secureStorage = FlutterSecureStorage();
  final settingsStore = SettingsStore(secureStorage: secureStorage);
  final savedSettings = await settingsStore.load();
  final initialLocale = savedSettings.localeLanguageCode == null
      ? null
      : Locale(savedSettings.localeLanguageCode!);

  runApp(
    ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(AsyncData(paths)),
        appLoggerProvider.overrideWithValue(AsyncData(logger)),
        localeProvider.overrideWith(() => LocaleNotifier(initialLocale)),
      ],
      child: AlibabaCloudActionCapture(
        child: const AuthGate(
          child: ThkTreeApp(),
        ),
      ),
    ),
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
