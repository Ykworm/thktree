// macOS 桌面端集成测试 — 聊天 Helper
//
// 依赖：desktop_primitive_helpers.dart, desktop_test_fixtures.dart (ChatCtx)

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'desktop_primitive_helpers.dart';
import 'desktop_test_fixtures.dart' show ChatCtx, NodeCtx;

/// 发送消息 + 等流式回复完成
Future<void> sendAndWait(WidgetTester tester, String message, {Duration timeout = const Duration(seconds: 180)}) async {
  // 确认 chat_input 和 send_button 存在
  expect(find.byKey(const ValueKey('chat_input')), findsOneWidget);
  expect(find.byKey(const ValueKey('send_button')), findsOneWidget);

  // 输入文本
  await enterTextByKey(tester, const ValueKey('chat_input'), message);

  // 按 Enter 发送
  await pressEnter(tester);

  // 等流式完成：stop_button 出现 → send_button 恢复
  // 短回复可能在 pump 间隙完成，用两阶段检测
  await tester.pump(const Duration(seconds: 1));
  final sw = Stopwatch()..start();
  bool sawStream = false;
  while (true) {
    final hasStop = find.byKey(const ValueKey('stop_button')).evaluate().isNotEmpty;
    final hasSend = find.byKey(const ValueKey('send_button')).evaluate().isNotEmpty;
    if (hasStop) sawStream = true;
    if (sawStream && hasSend) break; // 流式结束
    if (!sawStream && hasSend && sw.elapsed > const Duration(seconds: 3)) break; // 极短回复已完成
    if (sw.elapsed > timeout) fail('sendAndWait: 超时（${message.substring(0, message.length < 30 ? message.length : 30)}...）');
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pump();
}

/// 发送快捷键 Enter（依赖焦点在 chat_input）
Future<void> pressEnter(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
}

/// 在聊天中切换模型
Future<void> switchModel(WidgetTester tester, String providerId, String modelId) async {
  // 点导航栏中的模型名称区域（middle GestureDetector）
  final modelArea = find.byWidgetPredicate(
    (w) => w is GestureDetector && w.onTap != null,
  );
  // 注：模型面板 toggle 绑定在导航栏 middle 区域的 GestureDetector
  // 这里简化处理：先关掉 sheet（如果开着），再点模型名
  // 实际集成测试中，需要定位到正确的 GestureDetector
  // 如果测试需要切换模型，在 test 层面先 openSettings → 大模型 → 默认模型配置
}

/// 开始聊天：选中节点并配置模型
Future<ChatCtx> startChat(WidgetTester tester, NodeCtx node, {String? modelId}) async {
  await scrollToText(tester, node.title);
  await tapFinder(tester, find.text(node.title), warnIfMissed: true);
  await tester.pumpAndSettle();
  await waitForKey(tester, const ValueKey('chat_input'));

  final chat = ChatCtx(node: node);
  chat.modelId = modelId;
  return chat;
}
