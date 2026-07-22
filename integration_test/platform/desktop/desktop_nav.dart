// macOS 桌面端集成测试 — 导航 Helper

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'desktop_primitive_helpers.dart';

/// 侧栏 → 主题分支
Future<void> switchToThemes(WidgetTester tester) async {
  await tapKey(tester, const ValueKey('sidebar_item_1'));
  await tester.pumpAndSettle();
}

/// 侧栏 → 搜索分支
Future<void> switchToSearch(WidgetTester tester) async {
  await tapKey(tester, const ValueKey('sidebar_item_0'));
  await tester.pumpAndSettle();
}

/// 侧栏 → 笔记分支
Future<void> switchToNotes(WidgetTester tester) async {
  await tapKey(tester, const ValueKey('sidebar_item_2'));
  await tester.pumpAndSettle();
}

/// 侧栏 → Lab 分支
Future<void> switchToLab(WidgetTester tester) async {
  await tapKey(tester, const ValueKey('sidebar_item_3'));
  await tester.pumpAndSettle();
}

/// 侧栏底部齿轮 → 设置页
Future<void> openSettings(WidgetTester tester) async {
  await tapKey(tester, const ValueKey('sidebar_settings'));
  await tester.pumpAndSettle();
  // 验证设置页出现（"设置" 导航栏标题或 "大模型" 设置项）
  assertText(tester, '大模型');
}
