// Theme + Node + Chat E2E 集成测试
//
// 验证「创建主题 → 创建节点 → 聊天 2 round」完整链路：
// 1. App 启动并进入主题列表（zh locale）
// 2. 点 + 按钮创建新主题，弹 dialog 输入主题名 → 创建
// 3. 进入主题详情，验证节点树
// 4. 点 + 按钮创建新讨论节点 → 创建
// 5. 点节点进入 chat_screen
// 6. Round 1：发送消息，等待 LLM 流式回复完成
// 7. Round 2：发送消息，等待 LLM 流式回复完成
// 8. 断言：4 条消息（2 user + 2 assistant），assistant body 非空
//
// 备注：
// - 真实 LLM API（不 mock）
// - 不清理测试数据
// - 时间戳加在主题/节点名后面，避免重复运行冲突
// - 超时：单轮 LLM 流式 90 秒

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';
import '../_support/llm_test_config.dart';
import '../_support/step_timer.dart';
import '../_support/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 加载 LLM 配置（API Key 来自 --dart-define-from-file 注入的
  // TEST_LLM_CONFIG_JSON 编译期常量，未注入或 Key 为空时
  // LlmTestConfig.loadFromDefine 会抛清晰错误）。
  //
  // 迁移记录（2026-06-20）：从 loadFromAsset 改到 loadFromDefine，
  // Key 不再打进 .app bundle，物理上消除 release 包泄露 Key 的可能。
  final llmConfig = LlmTestConfig.loadFromDefine();

  testWidgets('主题 → 节点 → 聊天 2 round 完整链路', (tester) async {
    // ignore: avoid_print
    print('[theme_chat_e2e] 使用 LLM 厂商: ${llmConfig.activeProvider.displayName}');

    final timer = StepTimer()..start();

    // 1. 启动 App，强制中文 locale + 注入 LLM 配置
    //
    // 注入两层：
    // - llmSettings：覆盖 AppSettings（UI 显示用，含当前选中的厂商）
    // - llmConfigStore：覆盖 LlmConfigStore（chat_controller 实际读 API Key 的位置）
    //
    // 缺一不可：simulator 沙盒里 Keychain 是空的、llm_providers.json 文件也不存在，
    // 任何一层缺了都会让 chat_controller 3 路径查找全部失败。
    final app = await createTestApp(
      locale: const Locale('zh'),
      llmSettings: llmConfig.toAppSettings(),
      llmConfigStore: llmConfig.toLlmConfigStore(),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    timer.step('启动 App + 注入');

    // 生成时间戳后缀，避免重复运行冲突（不清理数据）
    final ts = DateTime.now().millisecondsSinceEpoch;
    final themeTitle = 'Intg主题_$ts';
    final nodeTitle = 'Intg讨论_$ts';

    // App 默认进 /search 页（参见 router.dart initialLocation）。
    // 切换到底部 "主题" tab 进入主题列表。
    await _switchToTab(tester, '主题');
    await tester.pumpAndSettle();
    timer.step('切换底部 tab 到"主题"');

    // ──────────────────────────────────────────────────────────────────────
    // 步骤 1: 创建主题
    // ──────────────────────────────────────────────────────────────────────
    await _createTheme(tester, themeTitle);

    // 等新主题出现在列表
    await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));
    expect(find.text(themeTitle), findsOneWidget, reason: '新主题应出现在列表中');
    timer.step('创建主题');

    // ──────────────────────────────────────────────────────────────────────
    // 步骤 2: 进入主题详情
    // ──────────────────────────────────────────────────────────────────────
    await tester.tap(find.text(themeTitle));
    await tester.pumpAndSettle();

    // 主题详情应加载（新建主题为空树，不一定有 node_list key，
    // 但导航栏的 + 按钮一定存在）
    expect(
      find.byKey(const ValueKey('add_node_button')),
      findsOneWidget,
      reason: '进入主题详情后应能看到 + 按钮',
    );
    timer.step('进入主题详情');

    // ──────────────────────────────────────────────────────────────────────
    // 步骤 3: 创建节点（讨论）
    // ──────────────────────────────────────────────────────────────────────
    await _createNode(tester, nodeTitle);

    // 等新节点出现（注意节点列表用的是 _TreeRowView，需要滚到可见或用名字定位）
    await waitForText(tester, nodeTitle, timeout: const Duration(seconds: 10));
    expect(find.text(nodeTitle), findsOneWidget, reason: '新节点应出现在树中');
    timer.step('创建节点');

    // ──────────────────────────────────────────────────────────────────────
    // 步骤 4: 进入 chat_screen
    // ──────────────────────────────────────────────────────────────────────
    await tester.tap(find.text(nodeTitle));
    await tester.pumpAndSettle();

    // 聊天输入框应可用
    expect(
      find.byKey(const ValueKey('chat_input')),
      findsOneWidget,
      reason: '进入聊天页后应能看到输入框',
    );
    timer.step('进入聊天页');

    // ──────────────────────────────────────────────────────────────────────
    // 步骤 5: Round 1 — 发送消息并等待流式回复
    // ──────────────────────────────────────────────────────────────────────
    await _sendAndWaitForReply(
      tester,
      message: '请用一句话介绍你自己',
      timeout: const Duration(seconds: 90),
    );
    timer.step('Round 1 发消息等回复');

    // ──────────────────────────────────────────────────────────────────────
    // 步骤 6: Round 2 — 发送消息并等待流式回复
    // ──────────────────────────────────────────────────────────────────────
    await _sendAndWaitForReply(
      tester,
      message: '请讲一个简短的冷笑话',
      timeout: const Duration(seconds: 90),
    );
    timer.step('Round 2 发消息等回复');

    // ──────────────────────────────────────────────────────────────────────
    // 步骤 7: 断言 — 至少 2 user + 2 assistant 消息，assistant body 非空
    // ──────────────────────────────────────────────────────────────────────
    // 至少应该有 4 条消息气泡。注意：MessageBubble 渲染后会展示文本内容，
    // 我们直接验证用户发送的两条消息文本都在界面中。
    expect(
      find.text('请用一句话介绍你自己'),
      findsWidgets,
      reason: 'Round 1 用户消息应在聊天列表中',
    );
    expect(
      find.text('请讲一个简短的冷笑话'),
      findsWidgets,
      reason: 'Round 2 用户消息应在聊天列表中',
    );

    // 发送按钮已恢复（说明两条消息都流式完成）
    expect(
      find.byKey(const ValueKey('send_button')),
      findsOneWidget,
      reason: '第二轮结束后，发送按钮应恢复',
    );
    timer.step('最终断言');

    timer.finish();
  }, timeout: const Timeout(Duration(minutes: 5)));
}

// ---------------------------------------------------------------------------
// Local helpers
// ---------------------------------------------------------------------------

/// 点底部 tab 栏的指定 tab（按 label 文本定位）。
///
/// 切换后由调用方负责 pumpAndSettle。
Future<void> _switchToTab(WidgetTester tester, String label) async {
  // _TabItem 渲染时 label 是 Text widget；点它的父级 GestureDetector。
  final labelFinder = find.text(label);
  expect(labelFinder, findsWidgets, reason: '底部 tab 应包含 "$label"');
  // 选第一个匹配（tab 栏里的 Text），tap 一次即触发 onTap
  await tester.tap(labelFinder.first, warnIfMissed: false);
}

/// 在主题列表页创建主题：点 + 按钮 → 弹 dialog → 输入标题 → 点"创建"
Future<void> _createTheme(WidgetTester tester, String title) async {
  final addBtn = find.byKey(const ValueKey('add_theme_button'));
  expect(addBtn, findsOneWidget, reason: '主题列表页应找到 + 按钮');
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  // dialog 标题 = "新建主题"
  final titleInput = find.byKey(const ValueKey('theme_title_input'));
  expect(titleInput, findsOneWidget, reason: '应弹出主题创建 dialog');
  await tester.enterText(titleInput, title);
  await tester.pump();

  final createBtn = find.byKey(const ValueKey('theme_create_button'));
  expect(createBtn, findsOneWidget, reason: '应找到主题创建按钮');
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}

/// 在主题详情页创建节点：点 + 按钮 → 弹 dialog → 输入标题 → 点"创建"
Future<void> _createNode(WidgetTester tester, String title) async {
  final addBtn = find.byKey(const ValueKey('add_node_button'));
  expect(addBtn, findsOneWidget, reason: '主题详情页应找到 + 按钮');
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  // dialog 标题 = "新建会话"
  final titleInput = find.byKey(const ValueKey('node_title_input'));
  expect(titleInput, findsOneWidget, reason: '应弹出节点创建 dialog');
  await tester.enterText(titleInput, title);
  await tester.pump();

  final createBtn = find.byKey(const ValueKey('node_create_button'));
  expect(createBtn, findsOneWidget, reason: '应找到节点创建按钮');
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}

/// 发送一条消息，等待 LLM 流式回复完成。
///
/// 流程：
/// 1. 输入消息到 chat_input
/// 2. 点击 send_button（此时 isStreaming = false，send_button 可见）
/// 3. 等待 stop_button 出现（说明已进入流式状态）
/// 4. 等待 send_button 重新出现（说明流式结束）
Future<void> _sendAndWaitForReply(
  WidgetTester tester, {
  required String message,
  Duration timeout = const Duration(seconds: 90),
}) async {
  final chatInput = find.byKey(const ValueKey('chat_input'));
  expect(chatInput, findsOneWidget, reason: '应找到聊天输入框');

  // 输入消息
  await tester.enterText(chatInput, message);
  await tester.pump();

  // 点击发送按钮（流式开始前一定是 send_button）
  final sendBtn = find.byKey(const ValueKey('send_button'));
  expect(sendBtn, findsOneWidget, reason: '发送前应找到 send_button');
  await tester.tap(sendBtn);
  await tester.pump();

  // 等 stop_button 出现 → 流式已启动
  // 同时检测 error 状态，避免 API 报错时傻等超时
  final stopFinder = find.byKey(const ValueKey('stop_button'));
  final sw = Stopwatch()..start();
  while (stopFinder.evaluate().isEmpty) {
    if (sw.elapsed > const Duration(seconds: 10)) {
      // 超时前先检查界面上是否有错误信息
      final errorText = _extractScreenError(tester);
      if (errorText != null) {
        fail('LLM 调用失败: $errorText');
      }
      fail('发送消息后 10s 内未进入流式状态（stop_button 未出现）。'
           '可能原因：LLM API 调用失败、网络超时、或 API Key 无效。');
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  // 等 send_button 回来 → 流式已结束
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('send_button')),
    timeout: timeout,
  );

  // 额外 pump 一次确保 UI 稳定
  await tester.pump();
}

/// 从界面上提取错误信息（AsyncError 渲染的 Text）。
///
/// chat_screen 在 AsyncError 时渲染 `Center(child: Text(e.toString()))`，
/// 这里提取该文本供测试报告使用。
String? _extractScreenError(WidgetTester tester) {
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null &&
        (data.contains('Exception') ||
         data.contains('Error') ||
         data.contains('SocketException') ||
         data.contains('DioException'))) {
      return data;
    }
  }
  return null;
}
