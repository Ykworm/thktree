// 搜索 tab 端到端 + 错误修复流程集成测试。
//
// 覆盖 3 个关键场景：
//   Case 1: 搜索有结果 → 笔记+节点均命中
//   Case 2: 搜索无结果 → 空态文案
//   Case 3: 搜索索引异常 → 修复弹窗 → 修复完成
//
// 备注：
// - 纯 CRUD 操作（不涉及 LLM）
// - Case 1 用 writeSearchFixture 写磁盘数据，触发自动索引
// - Case 3 用 FailingSearchService 模拟 DatabaseException
// - 超时：60 秒

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/ui/core/app_services.dart';

import '_support/failing_search_service.dart';
import '_support/search_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Case 1: 搜索有结果 → 笔记+节点均命中',
    (tester) async {
      // 写 fixture 需要在 app 启动前
      final paths = await AppPaths.load();
      final fixture = await writeSearchFixture(paths.themesDir);

      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // searchServiceProvider 初始化时会检测 index 是否为空，为空则自动 rebuildAll
      // 由于 fixture 已在启动前写入，rebuildAll 应该能索引到数据
      // 等待足够时间让 rebuildAll 完成
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 5)));
      await tester.pumpAndSettle();

      // ── 切换到搜索 tab ────────────────────────────────────────────────────
      await _switchToTab(tester, '搜索');
      await tester.pumpAndSettle();

      // ── 输入搜索关键词 ────────────────────────────────────────────────────
      final searchField = find.byType(CupertinoSearchTextField);
      expect(searchField, findsOneWidget, reason: '搜索页应有搜索框');
      await tester.enterText(searchField, fixture.keyword);
      // 等待防抖 + 查询
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      // 额外等待确保搜索完成
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // ── 验证结果 ──────────────────────────────────────────────────────────
      // 至少应有笔记 + 节点 2 条结果
      final results = find.byType(ListView);
      expect(results, findsWidgets, reason: '搜索结果应有列表');

      // 笔记标题应出现
      expect(find.text(fixture.noteTitle), findsOneWidget,
          reason: '应找到笔记标题');
      // 节点标题应出现
      expect(find.text(fixture.nodeTitle), findsOneWidget,
          reason: '应找到节点标题');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'Case 2: 搜索无结果 → 空态文案',
    (tester) async {
      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // ── 切换到搜索 tab ────────────────────────────────────────────────────
      await _switchToTab(tester, '搜索');
      await tester.pumpAndSettle();

      // ── 输入不匹配的关键词 ────────────────────────────────────────────────
      final searchField = find.byType(CupertinoSearchTextField);
      expect(searchField, findsOneWidget, reason: '搜索页应有搜索框');
      await tester.enterText(searchField, 'xyz_no_match_9999');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // ── 验证空态文案 ──────────────────────────────────────────────────────
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(find.text(l10n.searchNoResults), findsOneWidget,
          reason: '无结果时应显示空态文案');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Case 3: 搜索索引异常 → 修复弹窗 → 修复完成',
    (tester) async {
      final app = await createTestApp(
        locale: const Locale('zh'),
        extraOverrides: [
          searchServiceProvider.overrideWith((ref) async {
            final paths = await ref.watch(appPathsProvider.future);
            final db = await ref.watch(appDatabaseProvider.future);
            return FailingSearchService(
              db: db.db,
              paths: paths,
              noteStoreFactory: (themeId) => throw UnimplementedError(),
            );
          }),
        ],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // ── 切换到搜索 tab ────────────────────────────────────────────────────
      await _switchToTab(tester, '搜索');
      await tester.pumpAndSettle();

      // ── 输入关键词触发 DatabaseException ──────────────────────────────────
      final searchField = find.byType(CupertinoSearchTextField);
      expect(searchField, findsOneWidget, reason: '搜索页应有搜索框');
      await tester.enterText(searchField, 'anything');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // ── 验证修复弹窗 ──────────────────────────────────────────────────────
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

      // 弹窗标题
      expect(find.text(l10n.searchIndexError), findsOneWidget,
          reason: '应显示搜索索引异常弹窗标题');
      // 弹窗内容
      expect(find.text(l10n.searchIndexErrorContent), findsOneWidget,
          reason: '应显示搜索索引异常弹窗内容');
      // 立即修复按钮
      expect(find.text(l10n.repairNow), findsOneWidget,
          reason: '应显示立即修复按钮');

      // ── 点击立即修复 ──────────────────────────────────────────────────────
      await tester.tap(find.text(l10n.repairNow), warnIfMissed: false);
      await tester.pumpAndSettle();

      // 等待修复完成
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // ── 验证修复完成弹窗 ──────────────────────────────────────────────────
      expect(find.text(l10n.repairComplete), findsOneWidget,
          reason: '应显示修复完成弹窗标题');
      expect(find.text(l10n.repairCompleteContent), findsOneWidget,
          reason: '应显示修复完成弹窗内容');
      expect(find.text(l10n.ok), findsOneWidget,
          reason: '应显示确认按钮');

      // 点击确认关闭弹窗
      await tester.tap(find.text(l10n.ok), warnIfMissed: false);
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

/// 切换到底部 Tab
Future<void> _switchToTab(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  expect(labelFinder, findsWidgets, reason: '底部 tab 应包含 "$label"');
  await tester.tap(labelFinder.first, warnIfMissed: false);
  await tester.pumpAndSettle();
}
