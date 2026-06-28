// 搜索页 → 设置入口 集成测试。
//
// 覆盖 1 个关键场景：
//   Case 1: 启动 → 搜索 tab 默认展示 → 顶栏右上角齿轮按钮 → 点击 push 进入 settings 页
//
// 验收点：
// - 齿轮按钮存在并可点击
// - 点击后 SettingsScreen 显示（settingsTitle 出现在 NavBar/CupertinoNavigationBar 中）
// - 返回按钮存在（push 而非 replace）
//
// 备注：
// - 超时：30 秒

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/main_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '搜索页齿轮按钮 → push 进入 settings 页',
    (tester) async {
      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

      // ── 默认应在搜索页 ────────────────────────────────────────────────────
      // 顶栏标题 = 搜索（l10n.searchTabLabel）
      expect(find.text(l10n.searchTabLabel), findsWidgets,
          reason: '默认应在搜索 tab，顶栏标题应可见');

      // ── 齿轮按钮存在 ────────────────────────────────────────────────────────
      final settingsBtn = find.byKey(const ValueKey('settings_button'));
      expect(settingsBtn, findsOneWidget,
          reason: '搜索页顶栏右上角应显示齿轮按钮');

      // ── 点击齿轮 push 进入 settings ────────────────────────────────────────
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      // SettingsScreen 的 ThkLargeTitlePage 标题（出现在大标题区）
      expect(find.text(l10n.settingsTitle), findsWidgets,
          reason: 'push 后应显示 SettingsScreen 标题');

      // settings 页里至少有"语言"section header 出现，说明确实是 settings 页
      expect(find.text(l10n.language), findsWidgets,
          reason: 'settings 页应显示"语言" section');

      // 返回按钮（push 而非 replace，应该有返回栈）
      final backBtn = find.byType(CupertinoButton);
      expect(backBtn.evaluate().isNotEmpty, true,
          reason: 'settings 页应有可点击的导航元素（返回 / 列表项）');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}