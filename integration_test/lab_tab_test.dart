// 实验室 tab 集成测试
//
// 验证底部 tab bar 中「实验室」tab 可点击并跳转到占位页（LabPlaceholderScreen），
// 且 lab 选中态使用 assets/icons/lab_selected.png 作为 icon。
//
// 验收路径：
// 1. 启动后默认在 /search tab → 实验室 tab label "实验室" 应存在
// 2. 点击"实验室" → 切到 lab branch → 应出现 l10n.labEmptyHint 占位文案
// 3. 切到 lab 后，tab bar 中应渲染 lab_selected.png 作为 lab tab 选中态 icon
// 4. 点击"搜索" → 切回搜索 → 占位文案消失，lab_selected.png 也消失
//
// 备注：
// - 纯渲染/导航验证，不涉及 LLM
// - 默认初始 location 是 /search，所以从搜索切到实验室、再切回搜索
// - 超时：60 秒

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 定位 lab tab 的 selectedIcon：lab 选中时，tab bar 中应存在
  // 以 assets/icons/lab_selected.png 为源的 Image widget。
  Finder findLabSelectedIcon() {
    return find.byWidgetPredicate((widget) {
      if (widget is! Image) return false;
      final image = widget.image;
      return image is AssetImage && image.assetName == 'assets/icons/lab_selected.png';
    });
  }

  testWidgets(
    '实验室 tab 可点击并跳转到占位页',
    (tester) async {
      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // ────────────────────────────────────────────────────────────
      // 初始状态：默认 /search tab
      // ────────────────────────────────────────────────────────────
      expect(find.text('实验室'), findsOneWidget,
          reason: '底部 tab bar 应有"实验室"label');
      expect(find.text('实验功能筹备中'), findsNothing,
          reason: '初始在搜索 tab，不应渲染实验室占位文案');
      expect(findLabSelectedIcon(), findsNothing,
          reason: '初始在搜索 tab，lab 未选中，不应渲染 lab_selected.png');

      // ────────────────────────────────────────────────────────────
      // 点击实验室 tab → 跳转到 LabPlaceholderScreen + 选中态 PNG 出现
      // ────────────────────────────────────────────────────────────
      await tester.tap(find.text('实验室'));
      await tester.pumpAndSettle();

      expect(find.text('实验功能筹备中'), findsOneWidget,
          reason: '点击实验室 tab 后应渲染 l10n.labEmptyHint 占位文案');
      expect(findLabSelectedIcon(), findsOneWidget,
          reason: '点击实验室 tab 后，tab bar 应渲染 lab_selected.png 作为选中态 icon');

      // ────────────────────────────────────────────────────────────
      // 切回搜索 tab → 占位文案消失 + lab_selected.png 也消失
      // ────────────────────────────────────────────────────────────
      await tester.tap(find.text('搜索'));
      await tester.pumpAndSettle();

      expect(find.text('实验功能筹备中'), findsNothing,
          reason: '切回搜索 tab 后，实验室占位文案应消失');
      expect(findLabSelectedIcon(), findsNothing,
          reason: '切回搜索 tab 后，lab 未选中，lab_selected.png 应消失');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
