// 搜索 tab 端到端 + 错误修复流程集成测试。
//
// 覆盖 3 个关键场景：
//   Case 1: 搜索有结果 → 通过 UI 创建笔记后搜索验证
//   Case 2: 搜索无结果 → 空态文案
//   Case 3: 搜索索引异常 → 修复弹窗 → 修复完成
//
// 备注：
// - Case 1 复用 note_crud_test 的创建笔记流程
// - Case 3 用 FailingSearchService 模拟 DatabaseException
// - 超时：90 秒

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';

import '_support/failing_search_service.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Case 1: 搜索有结果 → 通过 UI 创建笔记后搜索验证',
    (tester) async {
      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final themeTitle = '搜索测试主题_$ts';
      final noteTitle = '搜索测试笔记_$ts';
      final keyword = 'SEK_SEARCH_KW_$ts';
      final noteContent = '这是一段包含独特关键词 $keyword 的内容用于全文搜索验证';

      // ── 通过 UI 创建笔记（复用 note_crud_test 流程）────────────────────────
      await _switchToTab(tester, '笔记');
      await tester.pumpAndSettle();

      // 点 + 进入主题选择
      final addBtn = find.byKey(const ValueKey('add_note_button'));
      expect(addBtn, findsOneWidget, reason: '笔记列表页应找到 + 按钮');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // ThemePicker → 点 + 创建新主题
      final addThemeBtns = find.byIcon(AppIcons.add);
      await tester.tap(addThemeBtns.last);
      await tester.pumpAndSettle();

      final themeTitleInput = find.byType(CupertinoTextField);
      expect(themeTitleInput, findsWidgets);
      await tester.enterText(themeTitleInput.last, themeTitle);
      await tester.pump();
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      // NoteEditorScreen：填标题 + 内容
      await tester.pump(const Duration(milliseconds: 500));
      final titleInput = find.byKey(const ValueKey('note_title_input'));
      expect(titleInput, findsOneWidget);
      await tester.enterText(titleInput, noteTitle);
      await tester.pump();
      final bodyInput = find.byKey(const ValueKey('note_body_input'));
      expect(bodyInput, findsOneWidget);
      await tester.enterText(bodyInput, noteContent);
      await tester.pump(const Duration(milliseconds: 600));

      // check 退出编辑器
      await tester.tap(find.byIcon(AppIcons.check));
      await tester.pumpAndSettle();

      // 等待 searchServiceProvider 自动 rebuildAll（笔记创建后会触发）
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
      await tester.pumpAndSettle();

      // ── 切换到搜索 tab ────────────────────────────────────────────────────
      await _switchToTab(tester, '搜索');
      await tester.pumpAndSettle();

      // ── 输入搜索关键词 ────────────────────────────────────────────────────
      final searchField = find.byType(CupertinoSearchTextField);
      expect(searchField, findsOneWidget, reason: '搜索页应有搜索框');
      await tester.enterText(searchField, keyword);
      // 等待防抖 + 查询
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      // 额外等待确保搜索完成
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // ── 验证结果 ──────────────────────────────────────────────────────────
      // 笔记标题应出现（可能在多个地方显示）
      expect(find.text(noteTitle), findsAtLeast(1),
          reason: '应找到笔记标题');
    },
    timeout: const Timeout(Duration(seconds: 90)),
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
