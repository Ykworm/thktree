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
// 用 main_test.dart 的 createTestApp（main.dart 不接受注入参数）。
import 'package:thk_tree/main_test.dart' as test_app;
import 'package:thk_tree/ui/core/app_logger.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/ui/core/app_services.dart';

import '_support/in_memory_llm_config_store.dart';

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
  /// [locale] 透传给 createTestApp；case 5 需要切到中文 locale 验证 i18n。
  Future<void> pumpApp(WidgetTester tester, {Locale? locale}) async {
    final widget = await test_app.createTestApp(
      llmConfigStore: InMemoryLlmConfigStore(
        providers: const [],
        apiKeys: const {},
      ),
      extraOverrides: [
        appLoggerProvider.overrideWithValue(AsyncData<AppLogger>(recordingLogger)),
        llmClientProvider.overrideWith((ref) async => mockClient),
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

    // 流式聊天：注入用户消息 → 触发 stream → 看到 LlmErrorCard compact
    await _sendUserMessage(tester, 'hello');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('llm_error_card_compact')), findsOneWidget);
    expect(find.text('Network error. Please check your connection and retry.'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  // ─────────────────────────────────────────────────────────────────────
  // Case 2：4 场景重试触发
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 2: 重试按钮触发新请求', (tester) async {
    mockClient.scenario = _ErrorScenario.network(DioExceptionType.connectionError);
    await pumpApp(tester);

    await _sendUserMessage(tester, 'hello');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(mockClient.callCount, 1);

    // 改成 success，第 2 次调用返回成功
    mockClient.scenario = _ErrorScenario.success('ok-reply');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(mockClient.callCount, 2);
  });

  // ─────────────────────────────────────────────────────────────────────
  // Case 3：日志上报链路（factory 写入 kind / hint / attrs）
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 3: LlmError.fromException 上报链路', (tester) async {
    mockClient.scenario = _ErrorScenario.network(DioExceptionType.connectionError);
    await pumpApp(tester);

    await _sendUserMessage(tester, 'hello');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 等待 async 上报 fire-and-forget 完成
    await tester.pump(const Duration(milliseconds: 500));

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

    await _sendUserMessage(tester, 'hello');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('llm_error_card_compact')), findsNothing);
    expect(recordingLogger.errorCalls, isEmpty);
  });

  // ─────────────────────────────────────────────────────────────────────
  // Case 5：i18n 文案映射（zh locale）
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 5: 中文 locale 文案正确', (tester) async {
    mockClient.scenario = _ErrorScenario.network(DioExceptionType.connectionError);
    await pumpApp(tester, locale: const Locale('zh'));

    await _sendUserMessage(tester, 'hello');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('网络连接中断，请检查后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
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
  _ErrorScenario.timeout(DioExceptionType t)
      : kind = _ErrorKindScenario.timeout,
        type = t,
        statusCode = null,
        reply = null;
  _ErrorScenario.networkWithStatus(int code)
      : kind = _ErrorKindScenario.network,
        statusCode = code,
        type = DioExceptionType.badResponse,
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
  Stream<String> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
  }) async* {
    callCount++;
    switch (scenario.kind) {
      case _ErrorKindScenario.success:
        yield scenario.reply!;
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
// 辅助：发送用户消息（参考 chat_streaming_test.dart 模式）
// ─────────────────────────────────────────────────────────────────────

Future<void> _sendUserMessage(WidgetTester tester, String text) async {
  // selector 与项目实际一致（参考 chat_streaming_test.dart:104 / test_helpers.dart:290）
  final inputFinder = find.byKey(const ValueKey('chat_input'));
  await tester.enterText(inputFinder, text);
  await tester.tap(find.byKey(const ValueKey('send_button')));
  await tester.pump();
}
