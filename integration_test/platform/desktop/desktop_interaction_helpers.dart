// macOS 桌面端集成测试 — 交互 Helper
// 快捷键、右键、hover、菜单栏

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

// ── 快捷键 ──

/// 模拟 Cmd+N
Future<void> shortcutNewTheme(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

/// 模拟 Cmd+Enter
Future<void> shortcutNewNode(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

/// 模拟 Cmd+,
Future<void> shortcutSettings(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.sendKeyDownEvent(LogicalKeyboardKey.comma);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.sendKeyUpEvent(LogicalKeyboardKey.comma);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

/// 模拟 Cmd+F
Future<void> shortcutSearch(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

// ── 右键菜单 ──

/// 右键点击指定 widget
Future<void> rightClick(WidgetTester tester, Finder finder) async {
  final center = tester.getCenter(finder);
  final event = PointerDownEvent(
    position: center,
    buttons: kSecondaryMouseButton,
  );
  await tester.sendEventToBinding(event);
  await tester.pump();
  final upEvent = PointerUpEvent(position: center, buttons: kSecondaryMouseButton);
  await tester.sendEventToBinding(upEvent);
  await tester.pumpAndSettle();
}

// ── Hover ──

/// 鼠标悬停到指定 widget
Future<void> hover(WidgetTester tester, Finder finder) async {
  final center = tester.getCenter(finder);
  final event = PointerMoveEvent(position: center);
  await tester.sendEventToBinding(event);
  await tester.pump();
}
