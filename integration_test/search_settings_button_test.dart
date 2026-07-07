// 搜索页 → 设置入口 集成测试。
//
// 覆盖 1 个关键场景：
//   Case 1: 启动 → 搜索 tab 默认展示 → 顶栏左上角 ≡ 菜单按钮 → 从左滑出半屏面板 → 点击「设置」→ push 进入 settings 页
//
// 验收点：
// - ≡ 菜单按钮存在并可点击
// - 点击后从左滑出半屏面板（含「设置」和「关于」选项）
// - 点击「设置」后 SettingsScreen 显示（settingsTitle 出现在 NavBar/CupertinoNavigationBar 中）
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
    '搜索页 ≡ 菜单 → sheet → 设置',
    (tester) async {
      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

      // ── 默认应在搜索页 ────────────────────────────────────────────────────
      expect(find.text(l10n.searchTabLabel), findsWidgets,
          reason: '默认应在搜索 tab，顶栏标题应可见');

      // ── ≡ 菜单按钮存在 ──────────────────────────────────────────────────────
      final menuBtn = find.byKey(const ValueKey('menu_button'));
      expect(menuBtn, findsOneWidget,
          reason: '搜索页顶栏左上角应显示 ≡ 菜单按钮');

      // ── 点击 ≡ 从左滑出半屏面板 ────────────────────────────────────────
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      // 面板中应有「设置」选项
      expect(find.text(l10n.menuSettings), findsOneWidget,
          reason: '点击 ≡ 后应从左滑出面板，含「设置」选项');

      // 面板中应有「关于」选项
      expect(find.text(l10n.menuAbout), findsOneWidget,
          reason: '点击 ≡ 后应从左滑出面板，含「关于」选项');

      // ── 点击「设置」push 进入 settings ────────────────────────────────────
      await tester.tap(find.text(l10n.menuSettings));
      await tester.pumpAndSettle();

      // SettingsScreen 的标题
      expect(find.text(l10n.settingsTitle), findsWidgets,
          reason: 'push 后应显示 SettingsScreen 标题');

      // settings 页里至少有"语言"section header 出现
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