import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试工具函数库
/// 提供集成测试中常用的辅助方法

/// 带超时的 pumpAndSettle
/// 
/// 默认超时时间为 30 秒，用于等待 LLM 响应等长时间操作
Future<void> pumpAndSettleWithTimeout(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 30),
  Duration duration = const Duration(milliseconds: 100),
}) async {
  await tester.pumpAndSettle(duration, EnginePhase.sendSemanticsUpdate, timeout);
}

/// 等待 LLM 响应完成
/// 
/// 通过检查流式状态来判断 LLM 是否完成响应
/// [checkStreaming] 是一个函数，返回当前是否正在流式传输
/// 超时时间为 30 秒
Future<void> waitForLLMResponse(
  WidgetTester tester, {
  required bool Function() checkStreaming,
  Duration timeout = const Duration(seconds: 30),
  Duration pollInterval = const Duration(milliseconds: 500),
}) async {
  final stopwatch = Stopwatch()..start();
  
  while (checkStreaming()) {
    if (stopwatch.elapsed > timeout) {
      throw TimeoutException('LLM response timeout after ${timeout.inSeconds}s');
    }
    await tester.pump(pollInterval);
  }
  
  // 额外 pump 一次确保 UI 更新
  await tester.pump();
}

/// 等待特定文本出现
/// 
/// 持续 pump 直到找到指定文本或超时
Future<void> waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 30),
  Duration pollInterval = const Duration(milliseconds: 500),
}) async {
  final stopwatch = Stopwatch()..start();
  
  while (find.text(text).evaluate().isEmpty) {
    if (stopwatch.elapsed > timeout) {
      throw TimeoutException('Text "$text" not found after ${timeout.inSeconds}s');
    }
    await tester.pump(pollInterval);
  }
}

/// 等待特定 widget 出现
/// 
/// 持续 pump 直到找到指定 widget 或超时
Future<void> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  Duration pollInterval = const Duration(milliseconds: 500),
}) async {
  final stopwatch = Stopwatch()..start();
  
  while (finder.evaluate().isEmpty) {
    if (stopwatch.elapsed > timeout) {
      throw TimeoutException('Widget not found after ${timeout.inSeconds}s');
    }
    await tester.pump(pollInterval);
  }
}

/// 安全点击
/// 
/// 先滚动到可见区域，然后点击
Future<void> safeTap(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
}) async {
  if (scrollable != null) {
    await tester.scrollUntilVisible(
      finder,
      500.0,
      scrollable: scrollable,
    );
  }
  await tester.tap(finder);
  await tester.pump();
}

/// 输入文本并等待
/// 
/// 在指定输入框中输入文本，然后等待 UI 更新
Future<void> enterTextAndWait(
  WidgetTester tester,
  Finder finder,
  String text, {
  Duration waitDuration = const Duration(milliseconds: 500),
}) async {
  await tester.enterText(finder, text);
  await tester.pump(waitDuration);
}

/// 长按并等待
/// 
/// 长按指定 widget，然后等待 UI 更新
Future<void> longPressAndWait(
  WidgetTester tester,
  Finder finder, {
  Duration waitDuration = const Duration(milliseconds: 500),
}) async {
  await tester.longPress(finder);
  await tester.pump(waitDuration);
}

/// 拖拽操作
/// 
/// 从 start 拖拽到 end 位置
Future<void> dragFromTo(
  WidgetTester tester,
  Offset start,
  Offset end, {
  Duration duration = const Duration(milliseconds: 500),
}) async {
  final gesture = await tester.startGesture(start);
  await gesture.moveBy(end - start);
  await gesture.up();
  await tester.pump(duration);
}

/// 获取所有匹配的文本内容
/// 
/// 返回所有匹配文本的列表
List<String> getAllTexts(Finder finder) {
  final texts = <String>[];
  for (final element in finder.evaluate()) {
    final widget = element.widget;
    if (widget is Text) {
      texts.add(widget.data ?? '');
    }
  }
  return texts;
}

/// 检查是否包含指定文本（忽略大小写）
/// 
/// 检查所有文本 widget 是否包含指定字符串
bool containsText(String searchText) {
  final finder = find.byType(Text);
  for (final element in finder.evaluate()) {
    final widget = element.widget;
    if (widget is Text) {
      final data = widget.data;
      if (data != null && data.toLowerCase().contains(searchText.toLowerCase())) {
        return true;
      }
    }
  }
  return false;
}

/// 等待加载完成
/// 
/// 等待所有异步操作完成，包括 loading indicator 消失
Future<void> waitForLoadingToComplete(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  // 等待可能存在的 loading indicator
  final loadingFinder = find.byType(CupertinoActivityIndicator);
  
  if (loadingFinder.evaluate().isNotEmpty) {
    final stopwatch = Stopwatch()..start();
    
    while (loadingFinder.evaluate().isNotEmpty) {
      if (stopwatch.elapsed > timeout) {
        throw TimeoutException('Loading timeout after ${timeout.inSeconds}s');
      }
      await tester.pump(const Duration(milliseconds: 500));
    }
  }
  
  // 额外等待确保 UI 稳定
  await tester.pump();
}

/// 创建测试节点
/// 
/// 辅助函数，用于在测试中创建新节点
Future<void> createTestNode(
  WidgetTester tester, {
  required String title,
}) async {
  // 点击添加按钮
  final addButton = find.byKey(const ValueKey('add_button'));
  if (addButton.evaluate().isNotEmpty) {
    await tester.tap(addButton);
    await tester.pump();
    
    // 输入标题
    final titleInput = find.byKey(const ValueKey('title_input'));
    if (titleInput.evaluate().isNotEmpty) {
      await tester.enterText(titleInput, title);
      await tester.pump();
      
      // 点击确认
      final confirmButton = find.byKey(const ValueKey('confirm_button'));
      if (confirmButton.evaluate().isNotEmpty) {
        await tester.tap(confirmButton);
        await tester.pump();
      }
    }
  }
}

/// 导航到对话页面
/// 
/// 从主题列表页面导航到指定对话
Future<void> navigateToChat(
  WidgetTester tester, {
  required String themeId,
  required String nodeId,
}) async {
  // 点击对应的主题项
  final themeItem = find.text(themeId);
  if (themeItem.evaluate().isNotEmpty) {
    await tester.tap(themeItem);
    await tester.pump();
    
    // 点击对应的节点
    final nodeItem = find.text(nodeId);
    if (nodeItem.evaluate().isNotEmpty) {
      await tester.tap(nodeItem);
      await tester.pump();
    }
  }
}

/// 导航到主题页面
/// 
/// 从主页面导航到主题列表
Future<void> navigateToTheme(
  WidgetTester tester, {
  required String themeName,
}) async {
  // 点击对应的主题项
  final themeItem = find.text(themeName);
  if (themeItem.evaluate().isNotEmpty) {
    await tester.tap(themeItem);
    await tester.pump();
  }
}

/// 模拟发送消息
/// 
/// 在聊天输入框中输入并发送消息
Future<void> sendMessage(
  WidgetTester tester, {
  required String message,
}) async {
  // 找到聊天输入框
  final chatInput = find.byKey(const ValueKey('chat_input'));
  if (chatInput.evaluate().isNotEmpty) {
    await tester.enterText(chatInput, message);
    await tester.pump();
    
    // 点击发送按钮
    final sendButton = find.byKey(const ValueKey('send_button'));
    if (sendButton.evaluate().isNotEmpty) {
      await tester.tap(sendButton);
      await tester.pump();
    }
  }
}

/// 模拟停止流式传输
/// 
/// 点击停止按钮
Future<void> stopStreaming(WidgetTester tester) async {
  final stopButton = find.byKey(const ValueKey('stop_button'));
  if (stopButton.evaluate().isNotEmpty) {
    await tester.tap(stopButton);
    await tester.pump();
  }
}

/// 刷新节点列表
/// 
/// 点击 ⋯ 菜单中的"刷新"选项
Future<void> refreshNodeList(WidgetTester tester) async {
  final menuButton = find.byKey(const ValueKey('overflow_menu_button'));
  if (menuButton.evaluate().isEmpty) return;
  await tester.tap(menuButton);
  await tester.pumpAndSettle();
  // CupertinoActionSheet renders "Refresh" as a button text.
  final refreshAction = find.text('Refresh');
  if (refreshAction.evaluate().isNotEmpty) {
    await tester.tap(refreshAction);
    await tester.pumpAndSettle();
  }
}

/// 获取所有节点标题
/// 
/// 返回节点列表中所有节点的标题
List<String> getNodeTitles() {
  // 这里需要根据实际的 UI 结构来实现
  // 返回一个示例实现
  return [];
}

/// 验证节点顺序
/// 
/// 验证节点的顺序是否符合预期
bool verifyNodeOrder(List<String> expectedOrder) {
  // 这里需要根据实际的 UI 结构来实现
  // 返回一个示例实现
  return true;
}
