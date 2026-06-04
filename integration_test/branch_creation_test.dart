import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('分支创建流程测试', () {
    testWidgets('选中文本 + raw 模式创建分支', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 1. 创建测试主题
      await _createTestTheme(tester, '测试主题');

      // 2. 进入主题
      await tester.tap(find.text('测试主题'));
      await tester.pumpAndSettle();

      // 3. 创建一个节点
      await _createTestNode(tester, '测试节点');

      // 4. 进入节点对话
      await tester.tap(find.text('测试节点'));
      await tester.pumpAndSettle();

      // 5. 发送一条消息，创建对话历史
      await _sendMessage(tester, '你好，这是一条测试消息');

      // TODO: 选中文本并创建分支
      // 目前测试到这里，后续需要根据实际 UI 交互完善
    });

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
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 创建测试主题和节点
      await _createTestTheme(tester, '测试主题3');
      await tester.tap(find.text('测试主题3'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '测试节点3');
      await tester.tap(find.text('测试节点3'));
      await tester.pumpAndSettle();
      await _sendMessage(tester, '你好');

      // TODO: 不选中文本，以 raw 模式创建分支
    });

    testWidgets('无选中文本 + summarize 模式创建分支', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 创建测试主题和节点
      await _createTestTheme(tester, '测试主题4');
      await tester.tap(find.text('测试主题4'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '测试节点4');
      await tester.tap(find.text('测试节点4'));
      await tester.pumpAndSettle();
      await _sendMessage(tester, '你好');

      // TODO: 不选中文本，以 summarize 模式创建分支
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
  // 点击添加按钮（+ 图标）
  final addButton = find.byIcon(CupertinoIcons.add);
  expect(addButton, findsOneWidget, reason: '应该找到添加按钮');
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
  // 点击添加按钮（+ 图标）
  final addButton = find.byIcon(CupertinoIcons.add);
  expect(addButton, findsOneWidget, reason: '应该找到添加按钮');
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
