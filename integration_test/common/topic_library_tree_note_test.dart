import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/data/stores/llm_config_store.dart';
import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/preset_providers.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/stores/session_store.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/thk_list_tile.dart';

import '../_support/in_memory_llm_config_store.dart';
import '../_support/llm_test_config.dart';
import '../_support/topic_library.dart';
import '../_support/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('话题库：3 主题 × 3 root chat × 3 分支（共 27 个子 chat）+ 笔记写入', (tester) async {
    const useMockLlm = bool.fromEnvironment('MOCK_LLM', defaultValue: false);
    const maxThemes = int.fromEnvironment('MAX_THEMES', defaultValue: 3);
    const maxRootsPerTheme = int.fromEnvironment('MAX_ROOTS', defaultValue: 3);
    const maxDepth = int.fromEnvironment('MAX_DEPTH', defaultValue: 2);
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
              LlmModelConfig(
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
      final baseSettings = cfg.toAppSettings();
      final presetId = 'preset_deepseek';
      final modelId = 'deepseek-chat';
      llmSettings = baseSettings.copyWith(
        titleModelProviderId: presetId,
        titleModelModelId: modelId,
        summaryModelProviderId: presetId,
        summaryModelModelId: modelId,
        chatDefaultProviderId: presetId,
        chatDefaultModelId: modelId,
      );
      llmConfigStore = cfg.toLlmConfigStore();
    }

    final app = await createTestApp(
      locale: const Locale('zh'),
      llmSettings: llmSettings,
      llmConfigStore: llmConfigStore,
      extraOverrides: [
        settingsStoreProvider.overrideWithValue(_InMemorySettingsStore(llmSettings)),
      ],
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await _switchToTab(tester, '主题');
    await tester.pumpAndSettle();

    final createdThemeTitles = <String>[];

    final themesToRun = TopicLibrary.themes.take(maxThemes).toList(growable: false);
    for (final themePlan in themesToRun) {
      final themeTitle = '${themePlan.title}_$ts';
      createdThemeTitles.add(themeTitle);

      await _createTheme(tester, themeTitle);
      await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(themeTitle));
      await tester.pumpAndSettle();

      final rootTitles = <String>[];
      final rootsToRun = themePlan.rootChats.take(maxRootsPerTheme).toList(growable: false);
      for (final rootPlan in rootsToRun) {
        final rootTitle = '${rootPlan.title}_$ts';
        rootTitles.add(rootTitle);
        await _createNode(tester, rootTitle);
        await waitForText(tester, rootTitle, timeout: const Duration(seconds: 10));
      }

      for (var r = 0; r < rootsToRun.length; r++) {
        final rootTitle = rootTitles[r];
        final rootPlan = rootsToRun[r];

        await tester.tap(find.text(rootTitle));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('chat_input')), findsOneWidget);

        // 递归创建分支链 (Root -> Child -> Grandchild)
        Future<void> createBranchChain(BranchPlan? plan, String parentTitle, int depthLeft) async {
          if (plan == null) return;
          if (depthLeft <= 0) return;

          final childTitle = '${themePlan.title}-${plan.title}_$ts';
          await _sendAndWaitForReply(tester, message: plan.prompt);
          await _selectTextInMessage(tester, plan.prompt);
          await _createBranchRawWithTitle(tester, childTitle);

          // 进入子对话后，继续递归创建下一层
          await createBranchChain(plan.child, childTitle, depthLeft - 1);

          // 递归回来后返回上一层
          await _backFromChat(tester);
          await tester.pumpAndSettle();
        }

        await createBranchChain(rootPlan.child, rootTitle, maxDepth);

        await _backFromChat(tester);
        await tester.pumpAndSettle();
      }

      await _backFromThemeDetail(tester);
      await tester.pumpAndSettle();
    }

    await _switchToTab(tester, '笔记');
    await tester.pumpAndSettle();

    for (var i = 0; i < themesToRun.length; i++) {
      final themePlan = themesToRun[i];
      final themeTitle = createdThemeTitles[i];
      final noteTitle = '${themePlan.noteSeed.title}_$ts';
      final noteBody = '${themePlan.noteSeed.body}\n\n# 来源\n- $themeTitle';

      await _createNoteInExistingTheme(tester, themeTitle, noteTitle, noteBody);
      await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(themeTitle));
      await tester.pumpAndSettle();
      await waitForText(tester, noteTitle, timeout: const Duration(seconds: 10));
      expect(find.text(noteTitle), findsOneWidget);
      await _backToNoteBrowse(tester);
      await tester.pumpAndSettle();
    }

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CupertinoApp)),
      listen: false,
    );
    final themeStore = await container.read(themeStoreProvider.future);
    final nodeStore = await container.read(nodeStoreProvider.future);
    final sessionStore = await container.read(sessionStoreProvider.future);

    final allThemes = await themeStore.listThemes();
    final createdThemes = <String, String>{};
    for (final t in allThemes) {
      if (createdThemeTitles.contains(t.title)) {
        createdThemes[t.title] = t.themeId;
      }
    }
    expect(createdThemes.length, createdThemeTitles.length);

    var totalChats = 0;
    for (final themeTitle in createdThemeTitles) {
      final themeId = createdThemes[themeTitle]!;
      final nodes = await nodeStore.listNodes(themeId: themeId);
      final rootNodes = nodes.where((n) => n.parentId == null).toList(growable: false);
      final descendantNodes = nodes.where((n) => n.parentId != null).toList(growable: false);

      expect(rootNodes.length, maxRootsPerTheme, reason: '主题 $themeTitle 根对话数量不符合预期');
      expect(
        descendantNodes.length,
        maxRootsPerTheme * maxDepth,
        reason: '主题 $themeTitle 派生对话数量不符合预期',
      );

      // 验证链条结构：每个根节点有一个子节点，每个子节点有一个孙节点
      final childCountByParent = <String, int>{};
      for (final n in nodes) {
        if (n.parentId != null) {
          childCountByParent.update(n.parentId!, (v) => v + 1, ifAbsent: () => 1);
        }
      }

      for (final root in rootNodes) {
        if (maxDepth >= 1) {
          expect(childCountByParent[root.nodeId], 1, reason: '根节点应有 1 个子节点');
          final child = nodes.firstWhere((n) => n.parentId == root.nodeId);
          if (maxDepth >= 2) {
            expect(childCountByParent[child.nodeId], 1, reason: '子节点应有 1 个孙节点');
          }
        }
      }

      // 校验 LLM 交互结果：不允许出现 error (network/timeout/auth 等)
      for (final node in nodes) {
        final doc = await sessionStore.readSession(node.nodeId);
        final err = doc.messages.where((m) => m.status == SessionMessageStatus.error).toList();
        if (err.isNotEmpty) {
          final first = err.first;
          fail('LLM 回复失败：theme="$themeTitle" node="${node.title}" errorCode=${first.errorCode ?? 'unknown'} body="${first.body}"');
        }
      }

      // 根对话一定发过至少一次消息，因此必须至少有一条 assistant done
      for (final root in rootNodes) {
        await _waitUntilRootHasAssistantDone(
          tester,
          sessionStore: sessionStore,
          nodeId: root.nodeId,
          timeout: const Duration(seconds: 90),
        );
        final doc = await sessionStore.readSession(root.nodeId);
        final assistantMsgs = doc.messages.where((m) => m.role == SessionRole.assistant).toList();
        expect(
          assistantMsgs.isNotEmpty,
          true,
          reason: '根对话 "${root.title}" 应至少产生一条 assistant 消息',
        );
        expect(
          assistantMsgs.any((m) => m.status == SessionMessageStatus.done && m.body.trim().isNotEmpty),
          true,
          reason: '根对话 "${root.title}" 的 assistant 消息应成功完成（非 error/streaming）',
        );
      }

      totalChats += nodes.length;
    }
    expect(totalChats, maxThemes * maxRootsPerTheme * (1 + maxDepth), reason: '总对话数不符合预期');
  }, timeout: const Timeout(Duration(minutes: 20)));
}

Future<void> _waitUntilRootHasAssistantDone(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required String nodeId,
  required Duration timeout,
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    final doc = await sessionStore.readSession(nodeId);
    final assistantMsgs = doc.messages.where((m) => m.role == SessionRole.assistant).toList();
    if (assistantMsgs.any((m) => m.status == SessionMessageStatus.done && m.body.trim().isNotEmpty)) {
      return;
    }
    final err = assistantMsgs.where((m) => m.status == SessionMessageStatus.error).toList();
    if (err.isNotEmpty) {
      final first = err.first;
      fail('LLM 回复失败：nodeId=$nodeId errorCode=${first.errorCode ?? 'unknown'} body="${first.body}"');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  final doc = await sessionStore.readSession(nodeId);
  fail('等待根对话 LLM 回复完成超时：nodeId=$nodeId messages=${doc.messages.length}');
}

Future<void> _switchToTab(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  expect(labelFinder, findsWidgets);
  await tester.tap(labelFinder.first, warnIfMissed: false);
}

Future<void> _createTheme(WidgetTester tester, String title) async {
  final addBtn = find.byKey(const ValueKey('add_theme_button'));
  await waitForWidget(tester, addBtn, timeout: const Duration(seconds: 10));
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  final titleInput = find.byKey(const ValueKey('theme_title_input'));
  await waitForWidget(tester, titleInput, timeout: const Duration(seconds: 10));
  await tester.enterText(titleInput, title);
  await tester.pump();

  final createBtn = find.byKey(const ValueKey('theme_create_button'));
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}

Future<void> _createNode(WidgetTester tester, String title) async {
  final addBtn = find.byKey(const ValueKey('add_node_button'));
  await waitForWidget(tester, addBtn, timeout: const Duration(seconds: 10));
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  final titleInput = find.byKey(const ValueKey('node_title_input'));
  await waitForWidget(tester, titleInput, timeout: const Duration(seconds: 10));
  await tester.enterText(titleInput, title);
  await tester.pump();

  final createBtn = find.byKey(const ValueKey('node_create_button'));
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}

Future<void> _sendAndWaitForReply(
  WidgetTester tester, {
  required String message,
  Duration timeout = const Duration(seconds: 60),
}) async {
  // 如果刚进入某个对话且正在自动流式生成，先等它结束（否则 send_button 不在树上）
  final stopBtn = find.byKey(const ValueKey('stop_button'));
  if (stopBtn.evaluate().isNotEmpty) {
    await waitForWidget(tester, find.byKey(const ValueKey('send_button')), timeout: timeout);
    await tester.pumpAndSettle();
  }

  final chatInput = find.byKey(const ValueKey('chat_input'));
  await waitForWidget(tester, chatInput, timeout: const Duration(seconds: 10));
  await tester.enterText(chatInput, message);
  await tester.pump();

  final sendBtn = find.byKey(const ValueKey('send_button'));
  await waitForWidget(tester, sendBtn, timeout: timeout);
  await tester.tap(sendBtn);
  await tester.pump();

  final sw = Stopwatch()..start();
  while (stopBtn.evaluate().isEmpty && sw.elapsed < const Duration(seconds: 2)) {
    await tester.pump(const Duration(milliseconds: 50));
  }

  await waitForWidget(tester, find.byKey(const ValueKey('send_button')), timeout: timeout);
  await tester.pump();
}

Future<void> _selectTextInMessage(WidgetTester tester, String text) async {
  final msgFinder = find.textContaining(text).first;
  expect(msgFinder, findsWidgets);
  await tester.ensureVisible(msgFinder);
  await tester.pumpAndSettle();
  await tester.longPress(msgFinder);
  await tester.pump(const Duration(milliseconds: 800));

  final selectAllZh = find.text('全选');
  final selectAllEn = find.text('Select All');

  if (selectAllZh.evaluate().isNotEmpty) {
    await tester.tap(selectAllZh);
    await tester.pump(const Duration(milliseconds: 300));
    return;
  }
  if (selectAllEn.evaluate().isNotEmpty) {
    await tester.tap(selectAllEn);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _createBranchRawWithTitle(WidgetTester tester, String title) async {
  final branchBtn = find.byKey(const ValueKey('branch_button'));
  await waitForWidget(tester, branchBtn, timeout: const Duration(seconds: 10));
  await tester.tap(branchBtn);
  await tester.pumpAndSettle();

  final rawOption = find.byKey(const ValueKey('branch_mode_raw_option'));
  await waitForWidget(tester, rawOption, timeout: const Duration(seconds: 10));
  await tester.tap(rawOption);
  await tester.pump();

  final continueBtn = find.byKey(const ValueKey('branch_mode_continue_button'));
  await tester.tap(continueBtn);
  await tester.pumpAndSettle();

  // 进入 TitleSuggestionScreen 后，点击“生成标题”，等待候选列表出现，再选择一个候选。
  final generateBtn = find.text('生成标题');
  await waitForWidget(tester, generateBtn, timeout: const Duration(seconds: 10));
  await tester.tap(generateBtn);
  await tester.pump();

  // 如果没配置默认 title model，会弹出 model selector action sheet。
  final modelAction = find.byWidgetPredicate(
    (w) {
      final key = w.key;
      if (key is ValueKey<String>) {
        return key.value.startsWith('model_sheet_');
      }
      return false;
    },
    description: 'model selector action',
  );
  if (modelAction.evaluate().isNotEmpty) {
    await tester.tap(modelAction.first);
    await tester.pumpAndSettle();
  }

  // 候选列表是 ThkListTile（无固定文本），出现后选第一个即可。
  final candidates = find.byType(ThkListTile);
  await waitForWidget(tester, candidates, timeout: const Duration(seconds: 90));
  await tester.tap(candidates.first);
  await tester.pumpAndSettle();

  final confirmBtn = find.byKey(const ValueKey('confirm_button'));
  await waitForWidget(tester, confirmBtn, timeout: const Duration(seconds: 10));
  final sw = Stopwatch()..start();
  while (sw.elapsed < const Duration(seconds: 2)) {
    final btn = tester.widget<CupertinoButton>(confirmBtn);
    if (btn.onPressed != null) break;
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.tap(confirmBtn, warnIfMissed: false);
  await tester.pumpAndSettle();

  await waitForWidget(tester, find.byKey(const ValueKey('chat_input')), timeout: const Duration(seconds: 10));
}

Future<void> _backFromChat(WidgetTester tester) async {
  final backBtn = find.byIcon(AppIcons.back);
  if (backBtn.evaluate().isEmpty) {
    final iosBack = find.byIcon(CupertinoIcons.back);
    if (iosBack.evaluate().isNotEmpty) {
      await tester.tap(iosBack.first);
      return;
    }
    fail('back button not found');
  }
  await tester.tap(backBtn.first);
}

Future<void> _backFromThemeDetail(WidgetTester tester) async {
  await _backFromChat(tester);
}

Future<void> _createNoteInExistingTheme(
  WidgetTester tester,
  String themeTitle,
  String noteTitle,
  String body,
) async {
  final addBtn = find.byKey(const ValueKey('add_note_button'));
  await waitForWidget(tester, addBtn, timeout: const Duration(seconds: 10));
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  await waitForWidget(tester, find.text('选择主题'), timeout: const Duration(seconds: 10));
  await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));
  await tester.tap(find.text(themeTitle).last);
  await tester.pumpAndSettle();

  final titleInput = find.byKey(const ValueKey('note_title_input'));
  await waitForWidget(tester, titleInput, timeout: const Duration(seconds: 10));
  await tester.enterText(titleInput, noteTitle);
  await tester.pump();

  final bodyInput = find.byKey(const ValueKey('note_body_input'));
  await waitForWidget(tester, bodyInput, timeout: const Duration(seconds: 10));
  await tester.enterText(bodyInput, body);
  await tester.pump();

  await tester.pump(const Duration(milliseconds: 600));

  final checkBtn = find.byIcon(AppIcons.check);
  await waitForWidget(tester, checkBtn, timeout: const Duration(seconds: 10));
  await tester.tap(checkBtn);
  await tester.pumpAndSettle();
}

Future<void> _backToNoteBrowse(WidgetTester tester) async {
  final backBtn = find.byIcon(AppIcons.back);
  if (backBtn.evaluate().isNotEmpty) {
    await tester.tap(backBtn.first);
    return;
  }
  final iosBack = find.byIcon(CupertinoIcons.back);
  if (iosBack.evaluate().isNotEmpty) {
    await tester.tap(iosBack.first);
    return;
  }
  await tester.pageBack();
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
  Future<void> saveLastUsedChatModel({String? providerId, String? modelId}) async {
    _settings = _settings.copyWith(
      lastUsedChatProviderId: providerId,
      lastUsedChatModelId: modelId,
    );
  }

  @override
  Future<void> saveTtsVoiceId(String? voiceId) async {
    _settings = _settings.copyWith(ttsVoiceId: voiceId);
  }

  @override
  Future<void> saveWebSearchEnabled(String providerType, bool enabled) async {
    // No-op for in-memory store
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
