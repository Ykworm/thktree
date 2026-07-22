// Android 图片发送 E2E 测试
//
// 验证 Android 端在聊天中附加图片并发送，图片出现在消息气泡中。
// 流程：
// 1. App 启动 → 进入一个 chat 节点
// 2. 点击图片附加按钮 → 选择图片（相册 / 拍照）
// 3. 发送消息
// 4. 验证消息中出现图片 widget
//
// 说明：模拟器相册可能为空，实际运行前需在 assets/ 预置测试图片
// （thktree-android/assets/test_image.jpg 已作为 fixture 存在）。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import '../../_support/test_helpers.dart';
import '../branch/branch_shared.dart';
import 'image_shared.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android 图片发送：附加图片并出现在消息中', (tester) async {
    final app = await createTestApp(
      locale: const Locale('zh'),
      llmSettings: AppSettings(
        localeLanguageCode: 'zh',
        faceIdEnabled: false,
        darkMode: false,
      ),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final appElement = tester.element(find.byType(CupertinoApp));
    final l10n = AppLocalizations.of(appElement)!;

    final ts = DateTime.now().millisecondsSinceEpoch;
    final themeTitle = 'ImgTest_$ts';
    final nodeTitle = 'N_$ts';

    await switchToThemesTab(tester, l10n);
    await createTheme(tester, themeTitle, l10n);
    await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));
    await tester.tap(find.text(themeTitle));
    await tester.pumpAndSettle();
    await createNode(tester, nodeTitle);
    await waitForText(tester, nodeTitle, timeout: const Duration(seconds: 10));
    await enterNode(tester, nodeTitle);

    // 打开图片选择并选图
    await openImagePicker(tester, l10n);
    await pickFirstImage(tester);

    // 发送（图片已附加在输入框）
    await sendMessage(tester, message: '看图');
    await tester.pumpAndSettle();

    // 验证图片出现在消息中
    await expectImageInMessage(tester);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
