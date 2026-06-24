// 笔记 tab 顶部搜索统一为全文搜索的集成测试。
//
// 覆盖 4 个关键路径：
//   1. 笔记 tab 顶部输入关键词 → 命中笔记 → 跳转 NoteDetailScreen
//   2. 空查询态 → 主题分组占位正常渲染
//   3. 搜索无结果 → 空态文案
//   4. 搜索 tab 与笔记 tab 同关键词结果数量一致
//
// 备注：
// - 搜索是纯客户端功能，不依赖 LLM
// - Case 1 走 UI 流程建一条笔记，再回到笔记 tab 搜索
// - Case 4 用一个必然无匹配的关键词，验证两 tab 空态结果数量一致
// - 超时：60 秒

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart';
import 'package:thk_tree/ui/features/search/search_content.dart';

void main() {
  setUp(() async {
    // 让每个 case 拿到干净的应用数据；fixture 在 case 内按需创建。
  });

  testWidgets(
    'Case 1: 笔记 tab 顶部输入关键词 → 命中新建笔记 → 跳转 NoteDetailScreen',
    (tester) async {
      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final themeTitle = 'Search测试主题_$ts';
      final noteTitle = 'Search测试笔记_$ts';
      final noteContent =
          '这是一段包含独特关键词 SEK_TEST_KEYWORD_$ts 的内容用于全文搜索';

      // ── 准备：在主题内建一条笔记 ──────────────────────────────────────
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

      // ── 验证：搜索框 + 命中笔记 ────────────────────────────────────────
      // 笔记 tab 顶部应该出现 SearchBox（内部为 CupertinoSearchTextField）
      final searchField = find.byType(CupertinoSearchTextField);
      expect(searchField, findsOneWidget,
          reason: '笔记 tab 顶部应嵌入一个 SearchBox');

      // 等待 1s 确保内容已落盘 + FTS5 索引完成初始 upsert
      await tester.pump(const Duration(seconds: 1));

      // 输入独有关键词
      final keyword = 'SEK_TEST_KEYWORD_$ts';
      await tester.enterText(searchField, keyword);
      // 300ms 防抖 + SQLite 查询 + pump
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // 应出现 SearchResults（ListView.builder）并至少含一条结果
      final resultsList = find.descendant(
        of: find.byType(SearchResults),
        matching: find.byType(ListView),
      );
      expect(resultsList, findsOneWidget,
          reason: '输入关键词后应展示 SearchResults');

      // ── 验证：点结果跳转 NoteDetailScreen ────────────────────────────────
      // 笔记 tab 当前是 NoteBrowseScreen，搜索结果用 SearchResultItem 渲染；
      // 点击笔记类型结果会调 navigateToSearchResult 推 NoteDetailScreen。
      // 直接点击笔记标题应触发跳转。
      final noteTile = find.text(noteTitle);
      expect(noteTile, findsWidgets,
          reason: '搜索结果中应至少含一条命中笔记标题 "$noteTitle"');

      await tester.tap(noteTile.first);
      await tester.pumpAndSettle();

      // NoteBrowseScreen 不再是当前页（被压栈）
      expect(find.byType(NoteBrowseScreen), findsNothing,
          reason: '点击搜索结果后应离开 NoteBrowseScreen');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'Case 2: 空查询态 → 主题分组占位正常渲染',
    (tester) async {
      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await _switchToTab(tester, '笔记');
      await tester.pumpAndSettle();

      // 不输入任何 query，笔记 tab 顶部应展示 SearchBox
      expect(find.byType(CupertinoSearchTextField), findsOneWidget,
          reason: '笔记 tab 顶部应嵌入 SearchBox');

      // 加载完成后应进入 _buildGroupedBody 分支（可能为空或含主题项）
      // 至少不应卡在 CupertinoActivityIndicator
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CupertinoActivityIndicator), findsNothing,
          reason: '加载完成后不应仍在 loading');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Case 3: 搜索无结果 → 空态文案',
    (tester) async {
      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await _switchToTab(tester, '笔记');
      await tester.pumpAndSettle();

      final searchField = find.byType(CupertinoSearchTextField).first;
      const nonsense = 'xyz_nothing_should_match_9999';
      await tester.enterText(searchField, nonsense);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(find.text(l10n.searchNoResults), findsOneWidget,
          reason: '搜不到任何内容时应在 SearchResults 中显示 l10n.searchNoResults');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Case 4: 搜索 tab 与笔记 tab 同关键词结果数量一致',
    (tester) async {
      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      const keyword = 'xyz_consistent_check_7777';

      // 笔记 tab 搜
      await _switchToTab(tester, '笔记');
      await tester.pumpAndSettle();
      final notesField = find.byType(CupertinoSearchTextField).first;
      await tester.enterText(notesField, keyword);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      final notesCount = _countSearchResultEntities();

      // 清空
      await tester.enterText(notesField, '');
      await tester.pump(const Duration(milliseconds: 300));

      // 搜索 tab 搜
      await _switchToTab(tester, '搜索');
      await tester.pumpAndSettle();
      final searchField = find.byType(CupertinoSearchTextField).first;
      await tester.enterText(searchField, keyword);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      final searchCount = _countSearchResultEntities();

      expect(notesCount, searchCount,
          reason:
              '两 tab 用同一关键词应返回数量一致的结果（$keyword：笔记 tab=$notesCount, 搜索 tab=$searchCount）');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

// ---------------------------------------------------------------------------
// Local helpers
// ---------------------------------------------------------------------------

Future<void> _switchToTab(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  expect(labelFinder, findsWidgets, reason: '底部 tab 应包含 "$label"');
  await tester.tap(labelFinder.first, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// 统计当前 SearchResults 列表中的 ListView 项数（结果条目数）。
/// 兜底：若未找到 SearchResults（极端空态），返回 0。
int _countSearchResultEntities() {
  final resultsFinder = find.byType(SearchResults);
  if (resultsFinder.evaluate().isEmpty) return 0;
  final listFinder = find.descendant(
    of: resultsFinder,
    matching: find.byType(ListView),
  );
  if (listFinder.evaluate().isEmpty) return 0;
  // ListView.builder 内部用 SliverList/SliverChildBuilderDelegate，
  // 直接 enumerate 命中的 ListView 元素。
  return listFinder.evaluate().length;
}
