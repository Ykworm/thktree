// macOS 桌面端 E2E 测试
// 已验证：PaneScaffold、tap 定位、Keychain、模型预选

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import '../../_support/llm_test_config.dart';
import '../../_support/test_helpers.dart';

class _MemStore extends FlutterSecureStorage {
  _MemStore([Map<String, String> initial = const {}]) : _s = Map.from(initial);
  final Map<String, String> _s;
  @override Future<void> write({required String key, required String? value, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, MacOsOptions? mOptions, WebOptions? webOptions, WindowsOptions? wOptions}) async { if (value != null) _s[key] = value; }
  @override Future<String?> read({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, MacOsOptions? mOptions, WebOptions? webOptions, WindowsOptions? wOptions}) async => _s[key];
  @override Future<void> delete({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, MacOsOptions? mOptions, WebOptions? webOptions, WindowsOptions? wOptions}) async { _s.remove(key); }
  @override Future<Map<String, String>> readAll({IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, MacOsOptions? mOptions, WebOptions? webOptions, WindowsOptions? wOptions}) async => Map.from(_s);
  @override Future<void> deleteAll({IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, MacOsOptions? mOptions, WebOptions? webOptions, WindowsOptions? wOptions}) async { _s.clear(); }
  @override Future<bool> containsKey({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, MacOsOptions? mOptions, WebOptions? webOptions, WindowsOptions? wOptions}) async => _s.containsKey(key);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final llmConfig = LlmTestConfig.loadFromDefine();

  testWidgets('桌面壳：主题 → 节点 → 聊天 2 round', (tester) async {
    final settings = llmConfig.toAppSettings();
    final providerId = settings.chatDefaultProviderId ?? 'preset_deepseek';
    final modelId = settings.chatDefaultModelId ?? 'deepseek-chat';
    // ignore: avoid_print
    print('[desktop_theme_chat_e2e] 厂商: ${llmConfig.activeProvider} model=$modelId');

    final app = await createTestApp(
      locale: const Locale('zh'),
      llmSettings: settings,
      llmConfigStore: llmConfig.toLlmConfigStore(),
      extraOverrides: [
        settingsStoreProvider.overrideWithValue(
          SettingsStore(secureStorage: _MemStore({
            'chat_default_provider_id': providerId,
            'chat_default_model_id': modelId,
            'last_used_chat_provider_id': providerId,
            'last_used_chat_model_id': modelId,
          })),
        ),
      ],
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final ts = DateTime.now().millisecondsSinceEpoch;
    final themeTitle = 'Desk主题_$ts';
    final nodeTitle = 'Desk讨论_$ts';

    // 切到主题分支
    await tester.tap(find.byKey(const ValueKey('sidebar_item_1')));
    await tester.pumpAndSettle();

    // 创建主题
    await _createTheme(tester, themeTitle);
    await tester.scrollUntilVisible(
      find.text(themeTitle),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    // 滚动后等动画完成再 tap
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(themeTitle), warnIfMissed: false);
    await tester.pumpAndSettle();
    await waitForWidget(tester, find.byKey(const ValueKey('add_node_button')), timeout: const Duration(seconds: 15));

    // 创建节点
    await _createNode(tester, nodeTitle);
    await tester.scrollUntilVisible(
      find.text(nodeTitle),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text(nodeTitle), findsOneWidget, reason: '新节点应出现在树中');

    // 点节点 → 进聊天
    final nodeFinder = find.text(nodeTitle);
    await tester.tap(nodeFinder.first);
    await waitForWidget(tester, find.byKey(const ValueKey('chat_input')), timeout: const Duration(seconds: 15));

    // 发消息 2 轮
    for (int r = 0; r < 2; r++) {
      final msg = r == 0 ? '请用一句话介绍你自己' : '请讲一个简短的冷笑话';
      await tester.enterText(find.byKey(const ValueKey('chat_input')), msg);
      await tester.pump();
      // 发前确认 send_button 存在
      expect(find.byKey(const ValueKey('send_button')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      // 等流式：stop_button 出现表示流式进行中，send_button 重新出现表示已完成
      // 短回复可能在 pump 间隙就完成了（stop_button 昙花一现）
      await tester.pump(const Duration(seconds: 1));
      final sw = Stopwatch()..start();
      bool sawStream = false;
      while (true) {
        final hasStop = find.byKey(const ValueKey('stop_button')).evaluate().isNotEmpty;
        final hasSend = find.byKey(const ValueKey('send_button')).evaluate().isNotEmpty;
        if (hasStop) sawStream = true;
        if (sawStream && hasSend) break; // 流式结束
        if (!sawStream && hasSend && sw.elapsed > const Duration(seconds: 3)) break; // 极短回复已完成
        if (sw.elapsed > const Duration(seconds: 180)) fail('Round $r: 流式未开始');
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump();
    }
    expect(find.text('请用一句话介绍你自己'), findsWidgets);
    expect(find.text('请讲一个简短的冷笑话'), findsWidgets);
    expect(find.byKey(const ValueKey('send_button')), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 15)));
}

Future<void> _createTheme(WidgetTester tester, String title) async {
  await tester.tap(find.byKey(const ValueKey('add_theme_button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('theme_title_input')), title);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('theme_create_button')));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _createNode(WidgetTester tester, String title) async {
  await tester.tap(find.byKey(const ValueKey('add_node_button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('node_title_input')), title);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('node_create_button')));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
}
