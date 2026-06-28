// 主题 tab unselect icon 集成测试
//
// 验证底部 tab bar 中「主题」tab 未 selected 时，渲染的是 SvgPicture
// （加载自 assets/icons/theme_unselect.svg），选中时回退到 SFIcon。
//
// 验收路径：
// 1. 启动后默认在 /search tab（主题 tab 未选）→ 全局只能找到 1 个 SvgPicture
// 2. 点击主题 tab 切到 selected → 全局 0 个 SvgPicture（来自主题 tab 的 svg 已隐藏）
// 3. 切回搜索 tab → 主题 tab 重新变未选 → 再次出现 1 个 SvgPicture
//
// 备注：
// - 纯渲染验证，不涉及 LLM
// - 整个 lib 中 SvgPicture 仅在 router.dart 主题 tab unselectIcon 中使用，
//   因此全局 `find.byType(SvgPicture)` 命中数可直接等价于「主题 tab 是否未选」
// - 超时：60 秒

import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '主题 tab 未 select 时渲染 SvgPicture，selected 时回退到 SFIcon',
    (tester) async {
      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // ────────────────────────────────────────────────────────────
      // 初始状态：默认 /search tab，主题 tab 未选
      // ────────────────────────────────────────────────────────────
      expect(find.text('主题'), findsOneWidget,
          reason: '底部 tab bar 应有"主题"label');

      expect(find.byType(SvgPicture), findsOneWidget,
          reason:
              '主题 tab 未选时应渲染 SvgPicture（来自 assets/icons/theme_unselect.svg）');

      // ────────────────────────────────────────────────────────────
      // 切到主题 tab → selected 状态
      // ────────────────────────────────────────────────────────────
      await tester.tap(find.text('主题'));
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsNothing,
          reason: '主题 tab 选中时不应再渲染未选状态的 svg');

      // ────────────────────────────────────────────────────────────
      // 切回搜索 tab → 主题 tab 重新变为未选
      // ────────────────────────────────────────────────────────────
      await tester.tap(find.text('搜索'));
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget,
          reason: '切回搜索 tab 后，主题 tab 重新变未选，应再次渲染 SvgPicture');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}