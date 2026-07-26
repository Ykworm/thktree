import 'dart:async';
import 'dart:ui';

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
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_palette_tokens.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/data/services/chat_task_service.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
        debugPrint(
          '[FlutterError] Suppressing further instances of: ${key.length > 80 ? key.substring(0, 80) : key}...',
        );
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
  final initialBrightness = savedSettings.darkMode
      ? Brightness.dark
      : Brightness.light;
  final initialPalette =
      AppColorPalette.values.asNameMap()[savedSettings.colorPalette] ??
      AppColorPalette.warmPaper;

  runApp(
    ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(AsyncData(paths)),
        appLoggerProvider.overrideWithValue(AsyncData(logger)),
        localeProvider.overrideWith(() => LocaleNotifier(initialLocale)),
        initialBrightnessProvider.overrideWithValue(initialBrightness),
        initialPaletteProvider.overrideWithValue(initialPalette),
      ],
      child: const AuthGate(
        child: ChatTaskServiceInitializer(
          child: AppLifecycleObserver(child: ThkTreeApp()),
        ),
      ),
    ),
  );
}

class ChatTaskServiceInitializer extends ConsumerStatefulWidget {
  const ChatTaskServiceInitializer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChatTaskServiceInitializer> createState() =>
      _ChatTaskServiceInitializerState();
}

class _ChatTaskServiceInitializerState
    extends ConsumerState<ChatTaskServiceInitializer> {
  @override
  void initState() {
    super.initState();
    _initializeChatTaskService();
  }

  Future<void> _initializeChatTaskService() async {
    try {
      final searchService = await ref.read(searchServiceProvider.future);
      final nodeStore = await ref.read(nodeStoreProvider.future);
      await ref
          .read(chatTaskServiceProvider.notifier)
          .initializeServices(
            searchService: searchService,
            nodeStore: nodeStore,
          );
      // 冷启动后扫描一次磁盘中断（满足「杀进程 → 重启 APP」场景）
      unawaited(ref.read(chatTaskServiceProvider.notifier).resumeInterrupted());
    } catch (e) {
      // 如果初始化失败，继续运行，搜索索引功能会在后续处理
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// 监听 AppLifecycleState，resumed 时触发 [ChatTaskService.resumeInterrupted] 扫盘重发。
///
/// 集成位置：[ChatTaskServiceInitializer] 之后包一层，确保
/// [chatTaskServiceProvider] 已初始化。
class AppLifecycleObserver extends ConsumerStatefulWidget {
  const AppLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleObserver> createState() =>
      _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 切回前台：触发重发扫描（fire-and-forget，不 await）
      unawaited(ref.read(chatTaskServiceProvider.notifier).resumeInterrupted());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ThkTreeApp extends ConsumerWidget {
  const ThkTreeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final brightness = ref.watch(brightnessProvider);
    final palette = ref.watch(paletteProvider);
    AppColors.setBrightness(brightness);
    AppColors.setPalette(palette);
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
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
      builder: (context, child) {
        return GptMarkdownTheme(
          gptThemeData: GptMarkdownThemeData(
            brightness: brightness,
            h1: AppTheme.title1.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
            h2: AppTheme.headline.copyWith(fontSize: 22),
            h3: AppTheme.headline.copyWith(fontSize: 19),
            highlightColor: AppColors.surfaceMuted,
            linkColor: AppColors.accent,
            autoAddDividerLineAfterH1: false,
          ),
          child: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
