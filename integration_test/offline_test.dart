import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/app_services.dart';

import '_support/in_memory_llm_config_store.dart';
import 'test_helpers.dart';

/// 本地定义 llmClientProvider（已从 app_services.dart 移除）。
final llmClientProvider = FutureProvider<LlmClient>((ref) async {
  throw UnimplementedError('Tests must override llmClientProvider');
});

class _InMemorySettingsStore implements SettingsStore {
  _InMemorySettingsStore(this._settings);

  AppSettings _settings;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> saveLocale(String? languageCode) async {
    _settings = _settings.copyWith(localeLanguageCode: languageCode);
  }

  @override
  Future<void> saveFaceIdEnabled(bool enabled) async {
    _settings = _settings.copyWith(faceIdEnabled: enabled);
  }

  @override
  Future<void> saveDarkMode(bool dark) async {
    _settings = _settings.copyWith(darkMode: dark);
  }

  @override
  Future<void> saveTitleModel({String? providerId, String? modelId}) async {
    _settings = _settings.copyWith(
      titleModelProviderId: providerId,
      titleModelModelId: modelId,
    );
  }

  @override
  Future<void> saveSummaryModel({String? providerId, String? modelId}) async {
    _settings = _settings.copyWith(
      summaryModelProviderId: providerId,
      summaryModelModelId: modelId,
    );
  }

  @override
  Future<void> saveChatDefaultModel({String? providerId, String? modelId}) async {
    _settings = _settings.copyWith(
      chatDefaultProviderId: providerId,
      chatDefaultModelId: modelId,
    );
  }

  @override
  Future<void> saveTtsVoiceId(String? voiceId) async {
    _settings = _settings.copyWith(ttsVoiceId: voiceId);
  }

  @override
  Future<void> saveWebSearchEnabled(String providerType, bool enabled) async {
    // 实现联网搜索设置保存
  }

  @override
  Future<void> saveLastUsedChatModel({String? providerId, String? modelId}) async {
    _settings = _settings.copyWith(
      lastUsedChatProviderId: providerId,
      lastUsedChatModelId: modelId,
    );
  }

  @override
  Future<void> saveBackupReminderEnabled(bool enabled) async {
    _settings = _settings.copyWith(backupReminderEnabled: enabled);
  }

  @override
  Future<void> saveNextBackupReminderDate(DateTime? date) async {
    _settings = _settings.copyWith(nextBackupReminderDate: date);
  }

  @override
  Future<void> saveAutoBackupEnabled(bool enabled) async {
    _settings = _settings.copyWith(autoBackupEnabled: enabled);
  }

  @override
  Future<void> saveLastAutoBackupAt(DateTime? date) async {
    _settings = _settings.copyWith(lastAutoBackupAt: date);
  }

  @override
  Future<void> saveBackupReminderIntervalDays(int days) async {
    _settings = _settings.copyWith(backupReminderIntervalDays: days);
  }
}

class _ImmediateNetworkErrorClient extends LlmClient {
  const _ImmediateNetworkErrorClient();

  @override
  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
    bool webSearch = false,
  }) {
    final err = DioException(
      requestOptions: RequestOptions(path: '/chat/completions'),
      type: DioExceptionType.connectionError,
      error: const SocketException('network down'),
    );
    return Stream<LlmResponseDelta>.error(err);
  }
}

class _MidStreamNetworkErrorClient extends LlmClient {
  const _MidStreamNetworkErrorClient();

  @override
  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
    bool webSearch = false,
  }) async* {
    yield const LlmResponseDelta(content: 'partial');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw DioException(
      requestOptions: RequestOptions(path: '/chat/completions'),
      type: DioExceptionType.connectionError,
      error: const SocketException('network down'),
    );
  }
}

class _FlakyNetworkClient extends LlmClient {
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
    if (callCount == 1) {
      throw DioException(
        requestOptions: RequestOptions(path: '/chat/completions'),
        type: DioExceptionType.connectionError,
        error: const SocketException('network down'),
      );
    }
    yield const LlmResponseDelta(content: 'recovered');
  }
}

Future<void> _switchToTab(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  expect(labelFinder, findsWidgets);
  await tester.tap(labelFinder.first, warnIfMissed: false);
}

Future<void> _createTheme(WidgetTester tester, String title) async {
  final addBtn = find.byKey(const ValueKey('add_theme_button'));
  await waitForWidget(tester, addBtn);
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  final titleInput = find.byKey(const ValueKey('theme_title_input'));
  await waitForWidget(tester, titleInput);
  await tester.enterText(titleInput, title);
  await tester.pump();

  final createBtn = find.byKey(const ValueKey('theme_create_button'));
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}

Future<void> _createNode(WidgetTester tester, String title) async {
  final addBtn = find.byKey(const ValueKey('add_node_button'));
  await waitForWidget(tester, addBtn);
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  final titleInput = find.byKey(const ValueKey('node_title_input'));
  await waitForWidget(tester, titleInput);
  await tester.enterText(titleInput, title);
  await tester.pump();

  final createBtn = find.byKey(const ValueKey('node_create_button'));
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}

Future<void> _enterChatWithNewNode(WidgetTester tester) async {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final themeTitle = 'Offline主题_$ts';
  final nodeTitle = 'Offline节点_$ts';

  await _switchToTab(tester, '主题');
  await tester.pumpAndSettle();

  await _createTheme(tester, themeTitle);
  await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));
  await tester.tap(find.text(themeTitle));
  await tester.pumpAndSettle();

  await _createNode(tester, nodeTitle);
  await waitForText(tester, nodeTitle, timeout: const Duration(seconds: 10));
  await tester.tap(find.text(nodeTitle));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('chat_input')), findsOneWidget);
}

Future<void> _sendMessage(WidgetTester tester, String text) async {
  final chatInput = find.byKey(const ValueKey('chat_input'));
  await enterTextAndWait(tester, chatInput, text, waitDuration: const Duration(milliseconds: 50));

  final sendBtn = find.byKey(const ValueKey('send_button'));
  await tester.tap(sendBtn);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('断网场景（Mock LLM）', () {
    testWidgets('模拟网络错误并显示错误 UI（无需真实 API）', (tester) async {
      final settings = AppSettings(
        localeLanguageCode: 'zh',
        faceIdEnabled: false,
        darkMode: false,
        chatDefaultProviderId: 'preset_deepseek',
        chatDefaultModelId: 'deepseek-chat',
        titleModelProviderId: 'preset_deepseek',
        titleModelModelId: 'deepseek-chat',
        summaryModelProviderId: 'preset_deepseek',
        summaryModelModelId: 'deepseek-chat',
      );

      final store = _InMemorySettingsStore(settings);
      final client = const _ImmediateNetworkErrorClient();

      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: settings,
        llmConfigStore: InMemoryLlmConfigStore(providers: const [], apiKeys: const {}),
        extraOverrides: [
          settingsStoreProvider.overrideWithValue(store),
          llmClientProvider.overrideWith((ref) async => client),
        ],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await _enterChatWithNewNode(tester);
      await _sendMessage(tester, 'hello offline');

      await waitForWidget(
        tester,
        find.textContaining('错误：network'),
        timeout: const Duration(seconds: 10),
      );
      expect(find.text('重试'), findsOneWidget);
      expect(find.byKey(const ValueKey('send_button')), findsOneWidget);
    });

    testWidgets('流式中途断网仍显示错误状态', (tester) async {
      final settings = AppSettings(
        localeLanguageCode: 'zh',
        faceIdEnabled: false,
        darkMode: false,
        chatDefaultProviderId: 'preset_deepseek',
        chatDefaultModelId: 'deepseek-chat',
        titleModelProviderId: 'preset_deepseek',
        titleModelModelId: 'deepseek-chat',
        summaryModelProviderId: 'preset_deepseek',
        summaryModelModelId: 'deepseek-chat',
      );

      final store = _InMemorySettingsStore(settings);
      final client = const _MidStreamNetworkErrorClient();

      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: settings,
        llmConfigStore: InMemoryLlmConfigStore(providers: const [], apiKeys: const {}),
        extraOverrides: [
          settingsStoreProvider.overrideWithValue(store),
          llmClientProvider.overrideWith((ref) async => client),
        ],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await _enterChatWithNewNode(tester);
      await _sendMessage(tester, 'hello midstream');

      await waitForWidget(
        tester,
        find.textContaining('错误：network'),
        timeout: const Duration(seconds: 10),
      );
      expect(find.textContaining('partial'), findsWidgets);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('网络恢复后点重试成功', (tester) async {
      final settings = AppSettings(
        localeLanguageCode: 'zh',
        faceIdEnabled: false,
        darkMode: false,
        chatDefaultProviderId: 'preset_deepseek',
        chatDefaultModelId: 'deepseek-chat',
        titleModelProviderId: 'preset_deepseek',
        titleModelModelId: 'deepseek-chat',
        summaryModelProviderId: 'preset_deepseek',
        summaryModelModelId: 'deepseek-chat',
      );

      final store = _InMemorySettingsStore(settings);
      final client = _FlakyNetworkClient();

      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: settings,
        llmConfigStore: InMemoryLlmConfigStore(providers: const [], apiKeys: const {}),
        extraOverrides: [
          settingsStoreProvider.overrideWithValue(store),
          llmClientProvider.overrideWith((ref) async => client),
        ],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await _enterChatWithNewNode(tester);
      await _sendMessage(tester, 'please recover');

      await waitForWidget(
        tester,
        find.textContaining('错误：network'),
        timeout: const Duration(seconds: 10),
      );
      await tester.tap(find.text('重试'));
      await tester.pump();

      await waitForWidget(
        tester,
        find.textContaining('recovered'),
        timeout: const Duration(seconds: 10),
      );
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('send_button')),
        timeout: const Duration(seconds: 10),
      );

      expect(find.textContaining('recovered'), findsWidgets);
      expect(client.callCount, 2);
    });
  });
}
