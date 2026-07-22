// 分支创建公共步骤（跨平台共享，Android / iOS / macOS 各自 _test.dart 复用）
//
// 提供：切到主题 tab、创建主题、创建节点、进入节点 等基础导航步骤。

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import '../../_support/test_helpers.dart';

/// 切换到"主题" tab
Future<void> switchToThemesTab(WidgetTester tester, AppLocalizations l10n) async {
  final labelFinder = find.text(l10n.themesTabLabel);
  expect(labelFinder, findsWidgets, reason: '底部 tab 应包含 "${l10n.themesTabLabel}"');
  await tester.tap(labelFinder.first, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// 创建主题
Future<void> createTheme(
  WidgetTester tester,
  String title,
  AppLocalizations l10n,
) async {
  final addBtn = find.byKey(const ValueKey('add_theme_button'));
  expect(addBtn, findsOneWidget, reason: '主题列表页应找到 + 按钮');
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  final titleInput = find.byKey(const ValueKey('theme_title_input'));
  expect(titleInput, findsOneWidget, reason: '应弹出主题创建 dialog');
  await tester.enterText(titleInput, title);
  await tester.pump();

  final createBtn = find.byKey(const ValueKey('theme_create_button'));
  expect(createBtn, findsOneWidget, reason: '应找到主题创建按钮');
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}

/// 创建 chat 节点
Future<void> createNode(WidgetTester tester, String title) async {
  final addBtn = find.byKey(const ValueKey('add_node_button'));
  expect(addBtn, findsOneWidget, reason: '主题详情页应找到 + 按钮');
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  final titleInput = find.byKey(const ValueKey('node_title_input'));
  expect(titleInput, findsOneWidget, reason: '应弹出节点创建 dialog');
  await tester.enterText(titleInput, title);
  await tester.pump();

  final createBtn = find.byKey(const ValueKey('node_create_button'));
  expect(createBtn, findsOneWidget, reason: '应找到节点创建按钮');
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}

/// 进入节点详情
Future<void> enterNode(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).last);
  await tester.pumpAndSettle();
}
