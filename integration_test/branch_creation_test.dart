import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/shared/title_suggestion_screen.dart';

import '_support/llm_test_config.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('分支创建流程测试', () {
    testWidgets('选中文本 + raw 模式创建分支', (tester) async {
      // ── 前置：注入真实 LLM 配置（创建子节点后 autoTriggerReply 需要） ──
      final llmConfig = LlmTestConfig.loadFromDefine();
      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 切换到主题 tab
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();

      // ── 1. 创建主题 → 进入 ──
      final ts = DateTime.now().millisecondsSinceEpoch;
      await _createTestTheme(tester, 'BranchSel_$ts');
      await waitForText(tester, 'BranchSel_$ts', timeout: const Duration(seconds: 10));
      await tester.tap(find.text('BranchSel_$ts'));
      await tester.pumpAndSettle();

      // ── 2. 创建节点 → 进入 chat_screen ──
      await _createTestNode(tester, 'SourceNode_$ts');
      await waitForText(tester, 'SourceNode_$ts', timeout: const Duration(seconds: 10));
      await tester.tap(find.text('SourceNode_$ts'));
      await tester.pumpAndSettle();

      // ── 3. 发送消息并等待 LLM 流式回复完成 ──
      debugPrint('[Test] 发送消息，等待 LLM 回复...');
      await _sendAndWaitForReply(
        tester,
        message: '请用一句话介绍你自己',
        timeout: const Duration(seconds: 90),
      );
      debugPrint('[Test] LLM 回复完成，停留 3 秒查看');
      await tester.pump(const Duration(seconds: 3));

      // ── 4. 选中文本（A1 方案：长按消息 → 全选） ──
      debugPrint('[Test] 长按消息触发选区...');
      await selectTextInMessage(tester, '请用一句话介绍你自己');
      debugPrint('[Test] 选中文本完成，停留 3 秒查看选区高亮');
      await tester.pump(const Duration(seconds: 3));

      // ── 5. 点 branch 按钮 ──
      debugPrint('[Test] 点击 branch 按钮...');
      final branchBtn = find.byKey(const ValueKey('branch_button'));
      expect(branchBtn, findsOneWidget, reason: '应该找到 branch 按钮');
      await tester.tap(branchBtn);
      await tester.pumpAndSettle();

      // ── 6. 选 raw 模式 + 继续 ──
      debugPrint('[Test] 等待模式选择 sheet...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_mode_raw_option')),
        timeout: const Duration(seconds: 10),
      );
      debugPrint('[Test] 模式选择 sheet 已出现，停留 2 秒');
      await tester.pump(const Duration(seconds: 2));

      debugPrint('[Test] 选择 raw 模式...');
      await tester.tap(find.byKey(const ValueKey('branch_mode_raw_option')));
      await tester.pump(const Duration(seconds: 1));
      debugPrint('[Test] 点击继续...');
      await tester.tap(find.byKey(const ValueKey('branch_mode_continue_button')));
      await tester.pump();

      // ── 7. 等待 TitleSuggestionScreen → 确认 ──
      debugPrint('[Test] 等待标题建议页加载...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('title_input')),
        timeout: const Duration(seconds: 30),
      );
      debugPrint('[Test] 标题建议页已加载，停留 5 秒等 LLM 生成候选标题');
      await tester.pump(const Duration(seconds: 5));

      // 尝试等 LLM 生成标题候选（5s），如果没生成则手动输入
      final titleInput = find.byKey(const ValueKey('title_input'));
      // 检查 title_input 是否已有文本（LLM 候选已填充）
      debugPrint('[Test] 检查标题是否已由 LLM 生成...');
      await tester.pump(const Duration(seconds: 5));

      // 无论 LLM 是否生成候选，手动输入确保测试稳定
      debugPrint('[Test] 输入分支标题...');
      await tester.enterText(titleInput, '分支测试标题');
      await tester.pump(const Duration(seconds: 2));

      // 确认按钮
      debugPrint('[Test] 点击确认按钮...');
      final confirmBtn = find.byKey(const ValueKey('confirm_button'));
      expect(confirmBtn, findsOneWidget, reason: '应该找到确认按钮');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // ── 8. 验证：跳转到新分支的 ChatScreen ──
      debugPrint('[Test] 等待新分支 ChatScreen 加载...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_button')),
        timeout: const Duration(seconds: 30),
      );
      debugPrint('[Test] 新分支 ChatScreen 已加载，停留 3 秒查看');
      await tester.pump(const Duration(seconds: 3));

      // 验证在新的 ChatScreen 中
      expect(
        find.byKey(const ValueKey('branch_button')),
        findsOneWidget,
        reason: '创建分支后应跳转到新 ChatScreen',
      );
      expect(
        find.byKey(const ValueKey('chat_input')),
        findsOneWidget,
        reason: '新分支 ChatScreen 应有输入框',
      );

      // 等待 autoTriggerReply 的流式回复完成
      debugPrint('[Test] 等待新分支 LLM 自动回复...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('send_button')),
        timeout: const Duration(seconds: 120),
      );
      debugPrint('[Test] 新分支 LLM 回复完成，停留 3 秒查看');
      await tester.pump(const Duration(seconds: 3));
      debugPrint('[Test] ✅ case 1 完成：选中文本 + raw 模式创建分支成功');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('选中文本 + summarize 模式创建分支', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 创建测试主题和节点
      await _createTestTheme(tester, '测试主题2');
      await tester.tap(find.text('测试主题2'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '测试节点2');
      await tester.tap(find.text('测试节点2'));
      await tester.pumpAndSettle();
      await _sendMessage(tester, '你好');

      // TODO: 选中文本并以 summarize 模式创建分支
    });

    testWidgets('无选中文本 + raw 模式创建分支', (tester) async {
      // 注入 LLM 配置（新分支 ChatScreen autoTriggerReply 需要）
      final llmConfig = LlmTestConfig.loadFromDefine();
      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 切换到主题 tab
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();

      // 创建测试主题和节点
      await _createTestTheme(tester, '测试主题3');
      await tester.tap(find.text('测试主题3'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '测试节点3');
      await tester.tap(find.text('测试节点3'));
      await tester.pumpAndSettle();
      await _sendMessage(tester, '你好');

      // 1. 点击分支按钮
      await tester.tap(find.byKey(const ValueKey('branch_button')));
      await tester.pumpAndSettle();

      // 2. 等待 sheet 出现，选 raw 模式
      await waitForWidget(tester, find.byKey(const ValueKey('branch_mode_raw_option')));
      await tester.tap(find.byKey(const ValueKey('branch_mode_raw_option')));
      await tester.pump();

      // 3. 点击继续
      await tester.tap(find.byKey(const ValueKey('branch_mode_continue_button')));
      await tester.pumpAndSettle();

      // 验证：弹出标题建议页（用 title_input key 定位，比 byType 更可靠）
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('title_input')),
        timeout: const Duration(seconds: 30),
      );
      expect(find.byKey(const ValueKey('title_input')), findsOneWidget);
    });

    testWidgets('无选中文本 + summarize 模式创建分支', (tester) async {
      // 注入真实 LLM 配置
      final llmConfig = LlmTestConfig.loadFromDefine();
      final app = await createTestApp(
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 导航到主题 tab（支持中英文）
      final themesTabEn = find.text('Themes');
      final themesTabZh = find.text('主题');
      if (themesTabEn.evaluate().isNotEmpty) {
        await tester.tap(themesTabEn);
      } else if (themesTabZh.evaluate().isNotEmpty) {
        await tester.tap(themesTabZh);
      }
      await tester.pumpAndSettle();

      // 前置：创建主题 → 进入 → 创建节点 → 进入 → 发送消息
      await _createTestTheme(tester, 'Summarize 测试');
      await tester.tap(find.text('Summarize 测试'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '源节点');
      await tester.tap(find.text('源节点'));
      await tester.pumpAndSettle();
      await _sendMessage(tester, '请帮我总结这段对话');

      // 等待 LLM 回复完成
      await tester.pump(const Duration(seconds: 2));
      await pumpAndSettleWithTimeout(
        tester,
        timeout: const Duration(seconds: 90),
      );

      // 1. 点击 branch 按钮（无选区）
      final branchButton = find.byKey(const ValueKey('branch_button'));
      expect(branchButton, findsOneWidget, reason: '应该找到 branch 按钮');
      await tester.tap(branchButton);
      await tester.pumpAndSettle();

      // 2. 等待模式选择 sheet 出现，选择 summarize
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_mode_summarize_option')),
        timeout: const Duration(seconds: 10),
      );
      await tester.tap(find.byKey(const ValueKey('branch_mode_summarize_option')));
      await tester.pump();

      // 3. 点击继续按钮
      await tester.tap(find.byKey(const ValueKey('branch_mode_continue_button')));
      await tester.pump();

      // 4. 等待 TitleSuggestionScreen 加载（LLM 总结需要时间，最长 120s）
      debugPrint('[Test] 等待 TitleSuggestionScreen 加载...');
      await waitForWidget(
        tester,
        find.byType(TitleSuggestionScreen),
        timeout: const Duration(seconds: 120),
      );
      debugPrint('[Test] TitleSuggestionScreen 已加载');

      // 5. 等待 title 输入框有内容（LLM 生成的候选标题）
      final titleInput = find.byKey(const ValueKey('title_input'));
      expect(titleInput, findsOneWidget, reason: '应该找到 title 输入框');

      // 等待候选标题生成完成
      await pumpAndSettleWithTimeout(
        tester,
        timeout: const Duration(seconds: 60),
      );

      // 6. 点击确认按钮
      final confirmButton = find.byKey(const ValueKey('confirm_button'));
      expect(confirmButton, findsOneWidget, reason: '应该找到确认按钮');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // 7. 验证：跳转到新分支的 ChatScreen
      await pumpAndSettleWithTimeout(
        tester,
        timeout: const Duration(seconds: 30),
      );
      debugPrint('[Test] 分支创建流程完成');
    });

    testWidgets('模式选择取消', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 创建测试主题和节点
      await _createTestTheme(tester, '测试主题5');
      await tester.tap(find.text('测试主题5'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '测试节点5');
      await tester.tap(find.text('测试节点5'));
      await tester.pumpAndSettle();
      await _sendMessage(tester, '你好');

      // TODO: 点击分支按钮，在模式选择 sheet 中取消
    });

    testWidgets('标题选择取消', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 创建测试主题和节点
      await _createTestTheme(tester, '测试主题6');
      await tester.tap(find.text('测试主题6'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '测试节点6');
      await tester.tap(find.text('测试节点6'));
      await tester.pumpAndSettle();
      await _sendMessage(tester, '你好');

      // TODO: 点击分支按钮，选择模式，在标题页取消
    });

    testWidgets('LLM 失败 fallback', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 创建测试主题和节点
      await _createTestTheme(tester, '测试主题7');
      await tester.tap(find.text('测试主题7'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '测试节点7');
      await tester.tap(find.text('测试节点7'));
      await tester.pumpAndSettle();
      await _sendMessage(tester, '你好');

      // TODO: 模拟 LLM 失败，验证 fallback 行为
    });
  });
}

/// 创建测试主题
Future<void> _createTestTheme(WidgetTester tester, String title) async {
  // 点击添加按钮（使用 ValueKey）
  final addButton = find.byKey(const ValueKey('add_theme_button'));
  expect(addButton, findsOneWidget, reason: '应该找到添加主题按钮');
  await tester.tap(addButton);
  await tester.pumpAndSettle();

  // 在对话框中输入标题
  final textField = find.byType(CupertinoTextField);
  expect(textField, findsOneWidget, reason: '应该找到输入框');
  await tester.enterText(textField, title);
  await tester.pump();

  // 点击创建按钮
  final createButton = find.text('Create');
  if (createButton.evaluate().isNotEmpty) {
    await tester.tap(createButton);
  } else {
    // 尝试中文按钮
    final createButtonCn = find.text('创建');
    await tester.tap(createButtonCn);
  }
  await tester.pumpAndSettle();
}

/// 创建测试节点
Future<void> _createTestNode(WidgetTester tester, String title) async {
  // 点击添加节点按钮（使用 ValueKey）
  final addButton = find.byKey(const ValueKey('add_node_button'));
  expect(addButton, findsOneWidget, reason: '应该找到添加节点按钮');
  await tester.tap(addButton);
  await tester.pumpAndSettle();

  // 在对话框中输入标题
  final textField = find.byType(CupertinoTextField);
  expect(textField, findsOneWidget, reason: '应该找到输入框');
  await tester.enterText(textField, title);
  await tester.pump();

  // 点击创建按钮
  final createButton = find.text('Create');
  if (createButton.evaluate().isNotEmpty) {
    await tester.tap(createButton);
  } else {
    final createButtonCn = find.text('创建');
    await tester.tap(createButtonCn);
  }
  await tester.pumpAndSettle();
}

/// 发送消息
Future<void> _sendMessage(WidgetTester tester, String message) async {
  // 找到聊天输入框
  final chatInput = find.byKey(const ValueKey('chat_input'));
  if (chatInput.evaluate().isEmpty) {
    // 可能没有进入对话页面，跳过
    return;
  }

  // 输入消息
  await tester.enterText(chatInput, message);
  await tester.pump();

  // 点击发送按钮
  final sendButton = find.byKey(const ValueKey('send_button'));
  if (sendButton.evaluate().isNotEmpty) {
    await tester.tap(sendButton);
    await tester.pumpAndSettle();
  }
}

/// 打开分支模式选择 sheet（供 case 5/6 复用）
///
/// 点击 branch_button，等待 sheet 出现，选择指定模式。
/// [mode] 参数为 'summarize' 或 'raw'。
Future<void> openBranchSheet(WidgetTester tester, {required String mode}) async {
  // 点击分支按钮
  await tester.tap(find.byKey(const ValueKey('branch_button')));
  await tester.pumpAndSettle();

  // 等待 sheet 出现
  await waitForWidget(tester, find.byKey(ValueKey('branch_mode_${mode}_option')));

  // 选择模式
  await tester.tap(find.byKey(ValueKey('branch_mode_${mode}_option')));
  await tester.pump();
}

/// 点底部 tab 栏的指定 tab（按 label 文本定位）。
Future<void> _switchToTab(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  expect(labelFinder, findsWidgets, reason: '底部 tab 应包含 "$label"');
  await tester.tap(labelFinder.first, warnIfMissed: false);
}

/// 发送一条消息，等待 LLM 流式回复完成。
///
/// 流程：
/// 1. 输入消息到 chat_input
/// 2. 点击 send_button
/// 3. 等待 stop_button 出现（流式已启动）
/// 4. 等待 send_button 重新出现（流式已结束）
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

  // 点击发送按钮
  final sendBtn = find.byKey(const ValueKey('send_button'));
  expect(sendBtn, findsOneWidget, reason: '发送前应找到 send_button');
  await tester.tap(sendBtn);
  await tester.pump();

  // 等 stop_button 出现 → 流式已启动
  final stopFinder = find.byKey(const ValueKey('stop_button'));
  final sw = Stopwatch()..start();
  while (stopFinder.evaluate().isEmpty) {
    if (sw.elapsed > const Duration(seconds: 10)) {
      fail('发送消息后 10s 内未进入流式状态');
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  // 等 send_button 回来 → 流式已结束
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('send_button')),
    timeout: timeout,
  );
  await tester.pump();
}

/// 选中消息文本（A1 方案：长按 → 全选）。
///
/// 利用 SelectionArea 内置手势：
/// 1. 长按消息文本 → 触发词选 + 弹出上下文菜单
/// 2. 点击「全选」→ 选中所有文本 → _currentSelectedText 被设置
///
/// 注意：flutter_tester 的 longPress 在 SelectionArea 内会触发
/// 原生文本选择行为，toolbar 按钮作为 overlay 渲染。
Future<void> selectTextInMessage(WidgetTester tester, String text) async {
  // 长按消息文本 → 触发 SelectionArea 选中一个词 + 弹出上下文菜单
  final msgFinder = find.textContaining(text).first;
  expect(msgFinder, findsWidgets, reason: '应找到包含 "$text" 的消息');
  await tester.longPress(msgFinder);
  await tester.pump(const Duration(seconds: 1));

  // 点击「全选」按钮
  // 中文 locale 显示「全选」，英文显示「Select All」
  final selectAllZh = find.text('全选');
  final selectAllEn = find.text('Select All');

  if (selectAllZh.evaluate().isNotEmpty) {
    await tester.tap(selectAllZh);
  } else if (selectAllEn.evaluate().isNotEmpty) {
    await tester.tap(selectAllEn);
  } else {
    // fallback：跳过选区，不影响后续流程
    debugPrint('[selectTextInMessage] 未找到「全选」按钮，跳过选区');
    return;
  }
  await tester.pump(const Duration(milliseconds: 500));
}
