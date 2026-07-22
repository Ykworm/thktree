// Android 分享导出 E2E 测试
//
// 验证 Android 端在消息气泡上点击分享按钮可触发系统分享 sheet。
// 流程：
// 1. App 启动 → 进入一个 chat 节点并发送一条消息
// 2. 在消息气泡上点击分享按钮
// 3. 验证系统分享 sheet 被触发
//
// 说明：Android 分享走系统分享 sheet（非自定义 UI），截图/保存动作依赖系统，
// 本测试仅断言分享流程被触发。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import '../../_support/test_helpers.dart';
import '../branch/branch_shared.dart';
import 'share_shared.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android 分享导出：消息分享触发系统 sheet', (tester) async {
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
    final themeTitle = 'ShareTest_$ts';
    final nodeTitle = 'N_$ts';

    await switchToThemesTab(tester, l10n);
    await createTheme(tester, themeTitle, l10n);
    await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));
    await tester.tap(find.text(themeTitle));
    await tester.pumpAndSettle();
    await createNode(tester, nodeTitle);
    await waitForText(tester, nodeTitle, timeout: const Duration(seconds: 10));
    await enterNode(tester, nodeTitle);

    // 发送一条消息，产生可分享的气泡
    await sendMessage(tester, message: '分享这条');
    await tester.pumpAndSettle();

    // 打开分享 sheet
    await openShareSheet(tester, l10n, messageText: '分享这条');
    await expectShareSheetVisible(tester);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
