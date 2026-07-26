import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/data/stores/llm_config_store.dart';
import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/preset_providers.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/stores/session_store.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';

import '../_support/in_memory_llm_config_store.dart';
import '../_support/llm_test_config.dart';
import '../_support/topic_llm_client.dart';
import '../_support/test_helpers.dart';

/// 本地定义 llmClientProvider（已从 app_services.dart 移除）。
final llmClientProvider = FutureProvider<LlmClient>((ref) async {
  throw UnimplementedError('Tests must override llmClientProvider');
});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('笔记 → 对话：从笔记创建 chat 并自动续聊', (tester) async {
    const useMockLlm = bool.fromEnvironment('MOCK_LLM', defaultValue: false);
    final ts = DateTime.now().millisecondsSinceEpoch;

    final AppSettings llmSettings;
    final LlmConfigStore llmConfigStore;

    if (useMockLlm) {
      final preset = createPresetProviders().firstWhere((p) => p.id == 'preset_deepseek');
      llmSettings = AppSettings(
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
      llmConfigStore = InMemoryLlmConfigStore(
        providers: [
          preset.copyWith(
            models: [
              const LlmModelConfig(
                id: 'deepseek-chat',
                name: 'deepseek-chat',
                contextWindow: 65536,
              ),
            ],
            selectedModelId: 'deepseek-chat',
          ),
        ],
        apiKeys: const {'preset_deepseek': 'fake-key'},
      );
    } else {
      final cfg = LlmTestConfig.loadFromDefine();
      llmSettings = cfg.toAppSettings();
      llmConfigStore = cfg.toLlmConfigStore();
    }

    final noteTitle = '从笔记续聊_$ts';
    final noteBody = '这是一段用于测试“笔记→对话”的内容。\n\n目标：把笔记内容作为首条用户消息创建对话，并触发自动回复。';
    final followUp = '请基于上面的笔记内容，提炼 3 条要点并给出下一步行动。';
    final replies = <String, String>{
      followUp: '要点：1) 笔记信息结构化；2) 明确目标与约束；3) 定义下一步最小行动。下一步：先列清单，再选 1 个可落地任务立即执行。',
    };

    final llmOverride = useMockLlm
        ? () {
            final mockClient = TopicLibraryLlmClient(repliesByUserPrompt: replies);
            return llmClientProvider.overrideWith((ref) async => mockClient);
          }()
        : null;

    final app = await createTestApp(
      locale: const Locale('zh'),
      llmSettings: llmSettings,
      llmConfigStore: llmConfigStore,
      extraOverrides: [
        settingsStoreProvider.overrideWithValue(_InMemorySettingsStore(llmSettings)),
        if (llmOverride != null) llmOverride,
      ],
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await _switchToTab(tester, '笔记');
    await tester.pumpAndSettle();

    final themeTitle = '笔记主题_$ts';
    await _createNoteWithNewTheme(tester, themeTitle, noteTitle, noteBody);
    await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));

    await tester.tap(find.text(themeTitle));
    await tester.pumpAndSettle();
    await waitForText(tester, noteTitle, timeout: const Duration(seconds: 10));

    await tester.tap(find.text(noteTitle));
    await tester.pumpAndSettle();

    final createChatBtn = find.byIcon(AppIcons.branch);
    expect(createChatBtn, findsOneWidget);
    await tester.tap(createChatBtn);
    await tester.pumpAndSettle();

    await waitForText(tester, '选择主题', timeout: const Duration(seconds: 10));
    await tester.tap(find.text(themeTitle));
    await tester.pumpAndSettle();

    await waitForText(tester, '作为根对话', timeout: const Duration(seconds: 10));
    await tester.tap(find.text('作为根对话'));
    await tester.pumpAndSettle();

    await waitForWidget(tester, find.byKey(const ValueKey('chat_input')), timeout: const Duration(seconds: 10));
    await waitForWidget(tester, find.byKey(const ValueKey('send_button')), timeout: const Duration(seconds: 10));

    expect(find.textContaining(noteTitle), findsWidgets);
    expect(find.textContaining('笔记→对话'), findsWidgets);

    await _sendAndWaitForReply(tester, message: followUp);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CupertinoApp)),
      listen: false,
    );
    final themeStore = await container.read(themeStoreProvider.future);
    final nodeStore = await container.read(nodeStoreProvider.future);
    final sessionStore = await container.read(sessionStoreProvider.future);

    final themes = await themeStore.listThemes();
    final themeId = themes.firstWhere((t) => t.title == themeTitle).themeId;
    final nodes = await nodeStore.listNodes(themeId: themeId);
    final created = nodes.where((n) => n.title == noteTitle).toList();
    expect(created.length, 1);
    expect(created.single.sourceType, 'note');
    expect(created.single.sourceExcerpt?.contains(noteTitle), true);

    await _waitUntilNoStreaming(
      tester,
      sessionStore: sessionStore,
      nodeId: created.single.nodeId,
      timeout: const Duration(seconds: 60),
    );

    final doc = await sessionStore.readSession(created.single.nodeId);
    final assistantMsgs = doc.messages.where((m) => m.role == SessionRole.assistant).toList();
    expect(assistantMsgs.isNotEmpty, true, reason: '应至少产生一条 assistant 消息（真实 LLM 或 mock 都应如此）');

    final hasError = assistantMsgs.any((m) => m.status == SessionMessageStatus.error);
    if (hasError) {
      final err = assistantMsgs.firstWhere((m) => m.status == SessionMessageStatus.error);
      fail('LLM 回复失败：errorCode=${err.errorCode ?? 'unknown'} body="${err.body}"');
    }

    final lastAssistant = assistantMsgs.last;
    expect(lastAssistant.status, SessionMessageStatus.done);
    expect(lastAssistant.body.trim().isNotEmpty, true);

    if (useMockLlm) {
      expect(lastAssistant.body.contains('要点'), true);
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> _waitUntilNoStreaming(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required String nodeId,
  required Duration timeout,
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    final doc = await sessionStore.readSession(nodeId);
    final hasStreaming = doc.messages.any((m) => m.status == SessionMessageStatus.streaming);
    if (!hasStreaming) return;
    await tester.pump(const Duration(milliseconds: 200));
  }
  final doc = await sessionStore.readSession(nodeId);
  fail('等待 LLM 流式结束超时：nodeId=$nodeId messages=${doc.messages.length}');
}

Future<void> _sendAndWaitForReply(
  WidgetTester tester, {
  required String message,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final chatInput = find.byKey(const ValueKey('chat_input'));
  await waitForWidget(tester, chatInput, timeout: const Duration(seconds: 10));
  await tester.enterText(chatInput, message);
  await tester.pump();

  final sendBtn = find.byKey(const ValueKey('send_button'));
  await waitForWidget(tester, sendBtn, timeout: const Duration(seconds: 10));
  await tester.tap(sendBtn);
  await tester.pump();

  await waitForWidget(tester, find.byKey(const ValueKey('send_button')), timeout: timeout);
  await tester.pump();
}

Future<void> _switchToTab(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  expect(labelFinder, findsWidgets);
  await tester.tap(labelFinder.first, warnIfMissed: false);
}

Future<void> _createNoteWithNewTheme(
  WidgetTester tester,
  String themeTitle,
  String noteTitle,
  String content,
) async {
  final addBtn = find.byKey(const ValueKey('add_note_button'));
  await waitForWidget(tester, addBtn, timeout: const Duration(seconds: 10));
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  final addThemeBtns = find.byIcon(AppIcons.add);
  await waitForWidget(tester, addThemeBtns.last, timeout: const Duration(seconds: 10));
  await tester.tap(addThemeBtns.last);
  await tester.pumpAndSettle();

  final themeTitleInput = find.byType(CupertinoTextField);
  await waitForWidget(tester, themeTitleInput.last, timeout: const Duration(seconds: 10));
  await tester.enterText(themeTitleInput.last, themeTitle);
  await tester.pump();

  await waitForText(tester, '创建', timeout: const Duration(seconds: 10));
  await tester.tap(find.text('创建'));
  await tester.pumpAndSettle();

  final titleInput = find.byKey(const ValueKey('note_title_input'));
  await waitForWidget(tester, titleInput, timeout: const Duration(seconds: 10));
  await tester.enterText(titleInput, noteTitle);
  await tester.pump();

  final bodyInput = find.byKey(const ValueKey('note_body_input'));
  await waitForWidget(tester, bodyInput, timeout: const Duration(seconds: 10));
  await tester.enterText(bodyInput, content);
  await tester.pump();

  await tester.pump(const Duration(milliseconds: 600));

  final checkBtn = find.byIcon(AppIcons.check);
  await waitForWidget(tester, checkBtn, timeout: const Duration(seconds: 10));
  await tester.tap(checkBtn);
  await tester.pumpAndSettle();
}

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
  Future<void> saveLastUsedChatModel({String? providerId, String? modelId}) async {
    _settings = _settings.copyWith(
      lastUsedChatProviderId: providerId,
      lastUsedChatModelId: modelId,
    );
  }

  @override
  Future<void> saveWebSearchEnabled(String providerType, bool enabled) async {}

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

  @override
  Future<void> saveLlmSetupOnboardingShown(bool shown) async {
    _settings = _settings.copyWith(llmSetupOnboardingShown: shown);
  }
}
