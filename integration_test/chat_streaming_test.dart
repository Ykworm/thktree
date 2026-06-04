import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('对话发送与流式回复测试', () {
    testWidgets('发送消息并等待流式回复', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // TODO: 导航到对话页面
      // 这里需要根据实际的应用导航流程来实现
      // 例如：点击主题列表 -> 进入某个主题 -> 点击某个节点 -> 进入对话页面

      // 测试场景：
      // 1. 进入一个对话页面
      // 2. 在输入框输入 "你好"
      // 3. 点击发送按钮
      // 4. 等待 LLM 开始回复（看到文字开始出现）
      // 5. 点击停止按钮
      // 6. 再次输入 "今天天气怎么样"
      // 7. 点击发送

      // 验证点：
      // - 步骤 3 后：用户消息 "你好" 立即显示在聊天列表中
      // - 步骤 3 后：发送按钮立即变成停止按钮
      // - 步骤 4 后：LLM 开始流式回复
      // - 步骤 5 后：流立即停止，停止按钮变回发送按钮
      // - 步骤 7 后：第二条用户消息立即显示，LLM 能正常回复

      // 示例测试步骤（需要根据实际 UI 调整）：

      // 1. 找到聊天输入框
      final chatInput = find.byKey(const ValueKey('chat_input'));
      expect(chatInput, findsOneWidget, reason: '应该找到聊天输入框');

      // 2. 输入消息
      await enterTextAndWait(tester, chatInput, '你好');

      // 3. 找到发送按钮并点击
      final sendButton = find.byKey(const ValueKey('send_button'));
      expect(sendButton, findsOneWidget, reason: '应该找到发送按钮');
      await tester.tap(sendButton);
      await tester.pump();

      // 4. 验证用户消息显示
      // 注意：用户消息应该立即显示在聊天列表中
      // 这里需要根据实际的 UI 结构来验证

      // 5. 验证按钮变为停止按钮
      // 注意：发送按钮应该立即变为停止按钮
      // 这可能需要等待一小段时间让 UI 更新

      // 6. 等待 LLM 开始流式回复
      // 注意：这里需要检测流式状态
      // 可能需要使用 waitForLLMResponse 或类似的方法

      // 7. 点击停止按钮
      // 注意：这里需要确保停止按钮出现后再点击
      // 可能需要等待一段时间

      // 8. 验证流停止
      // 注意：停止后，停止按钮应该变回发送按钮

      // 9. 再次输入消息并发送
      await enterTextAndWait(tester, chatInput, '今天天气怎么样');
      await tester.tap(sendButton);
      await tester.pump();

      // 10. 验证第二条消息显示
      // 注意：第二条用户消息应该立即显示

      // 11. 验证 LLM 能正常回复
      // 注意：这里需要等待 LLM 回复
      // 可能需要使用 waitForLLMResponse 或类似的方法
    });

    testWidgets('发送空消息', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // TODO: 导航到对话页面

      // 测试场景：
      // 1. 在输入框输入空字符串（或只包含空格）
      // 2. 点击发送按钮

      // 验证点：
      // - 空消息不应该被发送
      // - 输入框应该清空或保持原样
      // - 没有新消息添加到列表

      // 示例测试步骤：

      // 1. 找到聊天输入框
      final chatInput = find.byKey(const ValueKey('chat_input'));

      // 2. 输入空字符串
      await enterTextAndWait(tester, chatInput, '');

      // 3. 找到发送按钮并点击
      final sendButton = find.byKey(const ValueKey('send_button'));
      await tester.tap(sendButton);
      await tester.pump();

      // 4. 验证没有新消息
      // 注意：这里需要检查消息列表是否没有变化

      // 5. 输入只有空格的字符串
      await enterTextAndWait(tester, chatInput, '   ');

      // 6. 再次点击发送
      await tester.tap(sendButton);
      await tester.pump();

      // 7. 验证仍然没有新消息
    });

    testWidgets('快速连续发送消息', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // TODO: 导航到对话页面

      // 测试场景：
      // 1. 快速发送多条消息
      // 2. 验证消息顺序和 LLM 回复

      // 验证点：
      // - 消息按发送顺序显示
      // - LLM 能正确处理快速连续请求
      // - 不会出现消息丢失或乱序

      // 示例测试步骤：

      // 1. 找到聊天输入框和发送按钮
      final chatInput = find.byKey(const ValueKey('chat_input'));
      final sendButton = find.byKey(const ValueKey('send_button'));

      // 2. 快速发送第一条消息
      await enterTextAndWait(tester, chatInput, '第一条消息');
      await tester.tap(sendButton);
      await tester.pump();

      // 3. 快速发送第二条消息
      await enterTextAndWait(tester, chatInput, '第二条消息');
      await tester.tap(sendButton);
      await tester.pump();

      // 4. 快速发送第三条消息
      await enterTextAndWait(tester, chatInput, '第三条消息');
      await tester.tap(sendButton);
      await tester.pump();

      // 5. 验证消息顺序
      // 注意：这里需要检查消息列表中的消息顺序

      // 6. 等待 LLM 回复
      // 注意：这里需要等待所有 LLM 回复完成
    });
  });
}
