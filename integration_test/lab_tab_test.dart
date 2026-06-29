// Lab tab 集成测试
//
// 验证底部 tab bar 中「Lab」tab 可点击并跳转到占位页（LabPlaceholderScreen），
// 且占位页正确渲染 l10n.labEmptyHint 文案（"实验功能筹备中"）。
//
// 验收路径：
// 1. 启动后默认在 /search tab → Lab tab label "Lab" 应存在
// 2. 点击"Lab" → 切到 lab branch → 应出现 l10n.labEmptyHint 占位文案
// 3. 点击"搜索" → 切回搜索 → 占位文案消失
//
// 备注：
// - 纯渲染/导航验证，不涉及 LLM
// - 默认初始 location 是 /search，所以从搜索切到 Lab、再切回搜索
// - 当前所有 tab 都统一使用 SF Symbol 渲染（无 PNG/SVG 资源依赖），
//   因此不再断言 icon 渲染
// - 超时：60 秒

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Lab tab 可点击并跳转到占位页',
    (tester) async {
      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // ────────────────────────────────────────────────────────────
      // 初始状态：默认 /search tab
      // ────────────────────────────────────────────────────────────
      expect(find.text('Lab'), findsOneWidget,
          reason: '底部 tab bar 应有"Lab"label');
      expect(find.text('实验功能筹备中'), findsNothing,
          reason: '初始在搜索 tab，不应渲染 Lab 占位文案');

      // ────────────────────────────────────────────────────────────
      // 点击 Lab tab → 跳转到 LabPlaceholderScreen
      // ────────────────────────────────────────────────────────────
      await tester.tap(find.text('Lab'));
      await tester.pumpAndSettle();

      expect(find.text('实验功能筹备中'), findsOneWidget,
          reason: '点击 Lab tab 后应渲染 l10n.labEmptyHint 占位文案');

      // ────────────────────────────────────────────────────────────
      // 切回搜索 tab → 占位文案消失
      // ────────────────────────────────────────────────────────────
      await tester.tap(find.text('搜索'));
      await tester.pumpAndSettle();

      expect(find.text('实验功能筹备中'), findsNothing,
          reason: '切回搜索 tab 后，Lab 占位文案应消失');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
