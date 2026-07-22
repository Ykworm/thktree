// 分享导出公共步骤（跨平台共享）
//
// 提供：在消息气泡上打开分享、验证系统分享 sheet 出现。

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import '../../_support/test_helpers.dart';

/// 在指定消息上点击分享按钮，打开系统分享 sheet
Future<void> openShareSheet(
  WidgetTester tester,
  AppLocalizations l10n, {
  required String messageText,
}) async {
  // TODO(verify-key): 确认消息气泡分享图标的实际 ValueKey
  final shareBtn = find.byKey(const ValueKey('share_button'));
  expect(shareBtn, findsWidgets, reason: '消息气泡应显示分享按钮');
  await tester.tap(shareBtn.first);
  await tester.pumpAndSettle();
}

/// 验证系统分享 sheet 已出现
///
/// 注意：Android 分享走系统分享 sheet（非 Flutter 自建 UI），其文案由系统决定，
/// 无法用 find.text 稳定断言。此处仅作为占位，运行时需结合截图/平台通道验证。
Future<void> expectShareSheetVisible(WidgetTester tester) async {
  // TODO(verify-runtime): Android 系统分享 sheet 非 Flutter widget，需平台级验证。
}
