// 图片插入公共步骤（跨平台共享）
//
// 提供：打开图片选择、附加图片、发送并验证图片出现在消息中。

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import '../../_support/test_helpers.dart';

/// 点击图片附加按钮，打开图片选择（相机 / 相册）
Future<void> openImagePicker(WidgetTester tester, AppLocalizations l10n) async {
  // TODO(verify-key): 确认 Android 图片附加按钮的实际 ValueKey
  final imgBtn = find.byKey(const ValueKey('attach_image_button'));
  expect(imgBtn, findsOneWidget, reason: '聊天输入框应显示图片附加按钮');
  await tester.tap(imgBtn);
  await tester.pumpAndSettle();
}

/// 在图片选择中选择第一张图片（相册场景）
Future<void> pickFirstImage(WidgetTester tester) async {
  // TODO(verify-key): 确认图片选择器中缩略图的定位方式（模拟器相册可能为空，需预置 fixture）
  final thumb = find.byKey(const ValueKey('gallery_thumbnail_0'));
  if (thumb.evaluate().isNotEmpty) {
    await tester.tap(thumb);
    await tester.pumpAndSettle();
  }
}

/// 验证消息气泡中出现图片
Future<void> expectImageInMessage(WidgetTester tester) async {
  final imageFinder = find.byType(Image);
  expect(imageFinder, findsWidgets, reason: '消息中应出现图片 widget');
}
