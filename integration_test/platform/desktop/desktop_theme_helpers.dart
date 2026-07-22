// macOS 桌面端集成测试 — 主题 Helper
//
// 依赖：desktop_primitive_helpers.dart, desktop_test_fixtures.dart (ThemeCtx)

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'desktop_primitive_helpers.dart';
import 'desktop_test_fixtures.dart' show ThemeCtx, NodeCtx;

/// 创建单个主题，返回 ThemeCtx
Future<ThemeCtx> createTheme(WidgetTester tester, String title) async {
  await tapKey(tester, const ValueKey('add_theme_button'));
  await tester.pumpAndSettle();

  await enterTextByKey(tester, const ValueKey('theme_title_input'), title);

  await tapKey(tester, const ValueKey('theme_create_button'));
  await tester.pumpAndSettle();
  // 异步 provider 完成后额外 pump
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();

  // 滚到可见 + 断言
  await scrollToText(tester, title);
  assertText(tester, title, count: 1);

  // 从 local state 读取 themeId（通过 row key 模式）
  // themeId 从 key `theme_row_thm_{id}` 中提取
  final rowFinder = find.byWidgetPredicate(
    (w) => w is GestureDetector && w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('theme_row_'),
  );
  final rows = rowFinder.evaluate().toList();
  // 取最后一个（最新创建的）
  final lastRow = rows.last;
  final keyVal = ((lastRow.widget as GestureDetector).key as ValueKey).value.toString();
  final themeId = keyVal.replaceFirst('theme_row_', '');

  final ctx = ThemeCtx(themeId: themeId, title: title);
  return ctx;
}

/// 选中已有主题（展开三栏，等待 add_node_button 出现）
Future<void> selectTheme(WidgetTester tester, ThemeCtx ctx) async {
  await scrollToText(tester, ctx.title);
  await tapFinder(tester, find.text(ctx.title), warnIfMissed: true);
  await tester.pumpAndSettle();
  await waitForKey(tester, const ValueKey('add_node_button'));
}

/// 批量创建主题
Future<List<ThemeCtx>> createThemes(WidgetTester tester, List<String> titles) async {
  final results = <ThemeCtx>[];
  for (final title in titles) {
    results.add(await createTheme(tester, title));
  }
  return results;
}
