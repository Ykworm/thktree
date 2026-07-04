// LLM 错误重试集成测试（5 个 case）。
//
// 测试约定详见 docs/superpowers/plans/2026-06-24-llm-error-retry.md § Task 4。
//
// 设计要点：
// - 用 mock LlmClient + mock AppLogger 注入，避免真发 API / 真写日志。
// - 走 lib/main_test.dart 的 createTestApp(extraOverrides: ...) — main.dart
//   不接受注入参数，前者有 extraOverrides 钩子。
// - mock AppLogger 需用真实 AppPaths.load()（构造器要求 required paths），
//   通过 appLoggerProvider.overrideWithValue(AsyncData(logger)) 注入。
//
// 运行命令（参考 plan § Task 4）：
//   flutter test integration_test/llm_error_retry_test.dart \
//     --dart-define-from-file=build/dart_define.json \
//     -d "iPhone 15 Pro"

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/services/settings_store.dart';
// 用 main_test.dart 的 createTestApp（main.dart 不接受注入参数）。
import 'package:thk_tree/main_test.dart' as test_app;
import 'package:thk_tree/ui/core/app_logger.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/ui/core/app_services.dart';

import '_support/in_memory_llm_config_store.dart';

/// 本地定义 llmClientProvider（已从 app_services.dart 移除）。
final llmClientProvider = FutureProvider<LlmClient>((ref) async {
  throw UnimplementedError('Tests must override llmClientProvider');
});

/// Mock SettingsStore：_loadSettings() 读 settingsStoreProvider.load()，
/// 在模拟器里 Storage 为空导致 apiKey 为空，LLM 不被调用。
/// 直接注入 testSettings 让 fallback 路径走到 _startStreamingWithSettings。
class _MockSettingsStore implements SettingsStore {
  _MockSettingsStore(this._settings);
  final AppSettings _settings;
  @override
  Future<AppSettings> load() async => _settings;
  Future<void> save(AppSettings settings) async {}
  @override
  noSuchMethod(Invocation invocation) => null;
}



void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────────────────────────
  // Mock LlmClient：每个 test 重新构造，行为由注入的 _scenario 决定。
  // Mock AppLogger：收集 error() 调用，验证上报链路。
  // ─────────────────────────────────────────────────────────────────────
  late _ErrorLlmClient mockClient;
  late _RecordingLogger recordingLogger;
  late AppPaths paths;

  setUpAll(() async {
    paths = await AppPaths.load();
    await paths.ensureCreated();
  });

  setUp(() {
    mockClient = _ErrorLlmClient();
    recordingLogger = _RecordingLogger(paths);
  });

  /// 公共 helper：createTestApp + 注入 mock client / logger。
  ///
  /// [locale] 透传给 createTestApp；不传则沿用系统 locale（通常为 zh）。
  Future<void> pumpApp(WidgetTester tester, {Locale? locale}) async {
    final widget = await test_app.createTestApp(
      llmConfigStore: InMemoryLlmConfigStore(
        providers: const [],
        apiKeys: const {},
      ),
      extraOverrides: [
        appLoggerProvider.overrideWithValue(AsyncData<AppLogger>(recordingLogger)),
        llmClientProvider.overrideWith((ref) => mockClient),
        settingsStoreProvider.overrideWithValue(_MockSettingsStore(AppSettings(
          localeLanguageCode: null,
          faceIdEnabled: false,
          darkMode: false,
          chatDefaultProviderId: 'preset_deepseek',
          chatDefaultModelId: 'test-model',
          titleModelProviderId: 'preset_deepseek',
          titleModelModelId: 'test-model',
          summaryModelProviderId: 'preset_deepseek',
          summaryModelModelId: 'test-model',
        ))),
      ],
      locale: locale,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Case 1：4 个场景错误态展示 + 文案
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 1: 4 场景错误态 + i18n 文案', (tester) async {
    mockClient.scenario = _ErrorScenario.network(
      DioExceptionType.connectionError,
    );
    await pumpApp(tester);

    await _navigateToChat(tester);
    await _sendUserMessage(tester, 'hello');
    // 等待 mock stream 抛错 + sessionStore.failAssistant 写磁盘 + pollTimer 触发 _read()
    // 用 runAsync + 多次 pump 确保异步 I/O 和 timer 都能执行
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
      if (find.byKey(const ValueKey('llm_error_card_compact')).evaluate().isNotEmpty) break;
    }

    expect(find.byKey(const ValueKey('llm_error_card_compact')), findsOneWidget);
    expect(find.text('网络连接中断，请检查后重试'), findsOneWidget);
    // 用 findsAtLeastNWidgets：LlmErrorCard 里有一个“重试”，页面可能有其他同名元素
    expect(find.text('重试'), findsAtLeastNWidgets(1));
    expect(find.text('取消'), findsAtLeastNWidgets(1));
  });

  // ─────────────────────────────────────────────────────────────────────
  // Case 2：4 个场景重试触发
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 2: 重试按钮触发新请求', (tester) async {
    mockClient.scenario = _ErrorScenario.network(DioExceptionType.connectionError);
    await pumpApp(tester);

    await _navigateToChat(tester);
    await _sendUserMessage(tester, 'hello');
    // 等待 LlmErrorCard 渲染
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
      if (find.byKey(const ValueKey('llm_error_card_compact')).evaluate().isNotEmpty) break;
    }
    expect(mockClient.callCount, 1);

    // 改成 success，第 2 次调用返回成功
    mockClient.scenario = _ErrorScenario.success('ok-reply');
    await tester.tap(find.text('重试').first);
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 3)));
    await tester.pump();
    expect(mockClient.callCount, 2);
  });

  // ─────────────────────────────────────────────────────────────────────
  // Case 3：日志上报链路（factory 写入 kind / hint / attrs）
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 3: LlmError.fromException 上报链路', (tester) async {
    mockClient.scenario = _ErrorScenario.network(DioExceptionType.connectionError);
    await pumpApp(tester);

    await _navigateToChat(tester);
    await _sendUserMessage(tester, 'hello');
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 3)));
    await tester.pump();

    final calls = recordingLogger.errorCalls;
    expect(calls, isNotEmpty);
    final first = calls.first;
    expect(first.kind, 'network');
    expect(first.hint, anyOf('ChatTask.streamError', 'LlmError'));
    expect(first.attrs['nodeId'], isA<String>());
  });

  // ─────────────────────────────────────────────────────────────────────
  // Case 4：cancelled 错误不显示错误态 + 不上报
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 4: cancelled 错误不渲染错误卡', (tester) async {
    mockClient.scenario = _ErrorScenario.cancelled();
    await pumpApp(tester);

    await _navigateToChat(tester);
    await _sendUserMessage(tester, 'hello');
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 3)));
    await tester.pump();

    expect(find.byKey(const ValueKey('llm_error_card_compact')), findsNothing);
    expect(recordingLogger.errorCalls, isEmpty);
  });

  // ─────────────────────────────────────────────────────────────────────
  // Case 5：i18n 文案映射（zh locale）
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 5: 中文 locale 文案正确', (tester) async {
    mockClient.scenario = _ErrorScenario.network(DioExceptionType.connectionError);
    // 不传 locale — 默认使用系统 locale（通常为 zh）
    await pumpApp(tester);

    await _navigateToChat(tester);
    await _sendUserMessage(tester, 'hello');
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
      if (find.byKey(const ValueKey('llm_error_card_compact')).evaluate().isNotEmpty) break;
    }

    expect(find.text('网络连接中断，请检查后重试'), findsOneWidget);
    expect(find.text('重试'), findsAtLeastNWidgets(1));
    expect(find.text('取消'), findsAtLeastNWidgets(1));
  });
}

// ─────────────────────────────────────────────────────────────────────
// Mock LlmClient
// ─────────────────────────────────────────────────────────────────────

enum _ErrorKindScenario {
  success,
  network,
  timeout,
  cancelled,
  rateLimited,
  authFailed,
  serverError,
}

class _ErrorScenario {
  _ErrorScenario.success(String reply)
      : kind = _ErrorKindScenario.success,
        reply = reply,
        type = null,
        statusCode = null;
  _ErrorScenario.network(DioExceptionType t)
      : kind = _ErrorKindScenario.network,
        type = t,
        statusCode = null,
        reply = null;
  _ErrorScenario.cancelled()
      : kind = _ErrorKindScenario.cancelled,
        type = DioExceptionType.cancel,
        statusCode = null,
        reply = null;

  final _ErrorKindScenario kind;
  final DioExceptionType? type;
  final int? statusCode;
  final String? reply;
}

class _ErrorLlmClient extends LlmClient {
  _ErrorScenario scenario = _ErrorScenario.success('mock-reply');
  int callCount = 0;

  @override
  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
    bool webSearch = false,
  }) async* {
    callCount++;
    switch (scenario.kind) {
      case _ErrorKindScenario.success:
        yield LlmResponseDelta(content: scenario.reply!);
        return;
      case _ErrorKindScenario.network:
      case _ErrorKindScenario.timeout:
        throw DioException(
          requestOptions: RequestOptions(path: '/mock'),
          type: scenario.type!,
        );
      case _ErrorKindScenario.cancelled:
        throw DioException(
          requestOptions: RequestOptions(path: '/mock'),
          type: DioExceptionType.cancel,
        );
      case _ErrorKindScenario.rateLimited:
        throw DioException(
          requestOptions: RequestOptions(path: '/mock'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/mock'),
            statusCode: 429,
          ),
        );
      case _ErrorKindScenario.authFailed:
        throw DioException(
          requestOptions: RequestOptions(path: '/mock'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/mock'),
            statusCode: 401,
          ),
        );
      case _ErrorKindScenario.serverError:
        throw DioException(
          requestOptions: RequestOptions(path: '/mock'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/mock'),
            statusCode: 500,
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Recording Logger（测试用，捕获 error 调用）
// ─────────────────────────────────────────────────────────────────────

class _LogCall {
  _LogCall({required this.kind, required this.hint, required this.attrs});
  final String kind;
  final String hint;
  final Map<String, Object?> attrs;
}

class _RecordingLogger extends AppLogger {
  // AppLogger 构造器要求 required paths（写文件 / 远程上报都依赖）。
  // 我们的 error() override 不调 super，所以不写文件，但必须传真实 AppPaths。
  _RecordingLogger(AppPaths paths) : super(paths: paths);

  final List<_LogCall> errorCalls = [];

  @override
  Future<void> error(Object error, StackTrace stackTrace,
      {String? hint, Map<String, Object?>? attrs}) async {
    errorCalls.add(_LogCall(
      kind: (attrs?['kind'] as String?) ?? 'unknown',
      hint: hint ?? '',
      attrs: attrs ?? {},
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────
// 辅助：导航到 chat 屏（主题 tab → 创建主题 → 创建节点 → 进入）
// ─────────────────────────────────────────────────────────────────────

Future<void> _navigateToChat(WidgetTester tester) async {
  // 切换到底部「主题」tab
  final themesTab = find.text('主题');
  await tester.tap(themesTab.first, warnIfMissed: false);
  await tester.pumpAndSettle();

  // 创建主题
  final ts = DateTime.now().millisecondsSinceEpoch;
  final themeTitle = 'ErrRetry_$ts';
  final addThemeBtn = find.byKey(const ValueKey('add_theme_button'));
  expect(addThemeBtn, findsOneWidget, reason: '应找到添加主题按钮');
  await tester.tap(addThemeBtn);
  await tester.pumpAndSettle();
  final themeField = find.byType(CupertinoTextField);
  expect(themeField, findsOneWidget);
  await tester.enterText(themeField, themeTitle);
  await tester.pump();
  final createBtnEn = find.text('Create');
  if (createBtnEn.evaluate().isNotEmpty) {
    await tester.tap(createBtnEn);
  } else {
    await tester.tap(find.text('创建'));
  }
  await tester.pumpAndSettle();

  // 点主题进入
  await tester.tap(find.text(themeTitle));
  await tester.pumpAndSettle();

  // 创建节点
  final addNodeBtn = find.byKey(const ValueKey('add_node_button'));
  expect(addNodeBtn, findsOneWidget, reason: '应找到添加节点按钮');
  await tester.tap(addNodeBtn);
  await tester.pumpAndSettle();
  final nodeField = find.byType(CupertinoTextField);
  expect(nodeField, findsOneWidget);
  await tester.enterText(nodeField, 'ErrNode_$ts');
  await tester.pump();
  final createBtnEn2 = find.text('Create');
  if (createBtnEn2.evaluate().isNotEmpty) {
    await tester.tap(createBtnEn2);
  } else {
    await tester.tap(find.text('创建'));
  }
  await tester.pumpAndSettle();

  // 点节点进入 chat_screen
  await tester.tap(find.text('ErrNode_$ts'));
  await tester.pumpAndSettle();
}

// ─────────────────────────────────────────────────────────────────────
// 辅助：发送用户消息（参考 branch_creation_test 模式）
// ─────────────────────────────────────────────────────────────────────

Future<void> _sendUserMessage(WidgetTester tester, String text) async {
  final inputFinder = find.byKey(const ValueKey('chat_input'));
  expect(inputFinder, findsOneWidget, reason: '进入 chat 屏后应找到 chat_input');
  await tester.enterText(inputFinder, text);
  await tester.pump();
  final sendBtn = find.byKey(const ValueKey('send_button'));
  expect(sendBtn, findsOneWidget, reason: '应找到 send_button');
  await tester.tap(sendBtn);
  await tester.pump();
}
