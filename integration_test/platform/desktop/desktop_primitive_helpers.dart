// macOS 桌面端集成测试 — 基础操作 Helper
// 所有其他 helper 和测试脚本的基础层。

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// tap widget by key
Future<void> tapKey(WidgetTester tester, Key key, {bool warnIfMissed = false}) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key), warnIfMissed: warnIfMissed);
}

/// tap widget by Finder
Future<void> tapFinder(WidgetTester tester, Finder finder, {bool warnIfMissed = false}) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: warnIfMissed);
}

/// 输入文本
Future<void> enterTextByKey(WidgetTester tester, Key key, String text) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pump();
}

/// 滚到可见文本
Future<void> scrollToText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// 等待 widget by key 出现
Future<void> waitForKey(WidgetTester tester, Key key, {Duration timeout = const Duration(seconds: 15)}) async {
  final sw = Stopwatch()..start();
  while (find.byKey(key).evaluate().isEmpty) {
    if (sw.elapsed > timeout) throw TimeoutException('waitForKey: $key not found after $timeout');
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// 等待文本出现
Future<void> waitForTextStr(WidgetTester tester, String text, {Duration timeout = const Duration(seconds: 10)}) async {
  final sw = Stopwatch()..start();
  while (find.text(text).evaluate().isEmpty) {
    if (sw.elapsed > timeout) throw TimeoutException('waitForText: "$text" not found after $timeout');
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// 模拟 Cmd+Key 快捷键
Future<void> sendCmdKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(key);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.sendKeyUpEvent(key);
  await tester.pump();
}

/// 模拟 Enter
Future<void> pressEnter(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
}

/// 断言文本存在
void assertText(WidgetTester tester, String text, {int? count}) {
  final finder = find.text(text);
  if (count == null) {
    expect(finder, findsWidgets, reason: '应存在文本: $text');
  } else {
    expect(finder, count == 1 ? findsOneWidget : findsNWidgets(count),
        reason: '文本 "$text" 应出现 $count 次');
  }
}

/// pump + 等动画
Future<void> pumpAndSettleFor(WidgetTester tester, Duration duration) async {
  await tester.pump(duration);
  await tester.pumpAndSettle();
}
