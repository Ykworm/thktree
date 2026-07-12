// Android 分支创建 E2E 测试
//
// 验证 Android 端在节点详情页点击 branch 按钮可进入分支创建流程。
// 注意：B4 修复后 Android 不使用 SelectionArea 长按选词分支，改为点击 branch 按钮。
// 流程：
// 1. App 启动 → 切到"主题" tab
// 2. 创建测试主题 + 1 个 chat 节点
// 3. 进入节点详情 → 点击 branch 按钮
// 4. 验证进入分支创建流程（分支相关 UI 出现）

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import '../../_support/test_helpers.dart';
import 'branch_shared.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android 分支创建：点 branch 按钮进入分支流程', (tester) async {
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
    final themeTitle = 'BranchTest_$ts';
    final nodeTitle = 'N_$ts';

    await switchToThemesTab(tester, l10n);
    await createTheme(tester, themeTitle, l10n);
    await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));
    await tester.tap(find.text(themeTitle));
    await tester.pumpAndSettle();

    await createNode(tester, nodeTitle);
    await waitForText(tester, nodeTitle, timeout: const Duration(seconds: 10));
    await enterNode(tester, nodeTitle);

    // Android：点击 branch 按钮（非 SelectionArea 长按）
    // TODO(verify-key): 确认 Android 分支按钮的实际 ValueKey
    final branchBtn = find.byKey(const ValueKey('branch_button'));
    expect(branchBtn, findsOneWidget, reason: '节点详情应显示 branch 按钮');
    await tester.tap(branchBtn);
    await tester.pumpAndSettle();

    // 验证进入分支创建流程（分支相关文案出现）
    expect(
      find.text(l10n.branch),
      findsWidgets,
      reason: '应进入分支创建流程',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
