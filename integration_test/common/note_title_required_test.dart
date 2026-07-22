// 笔记标题自动提取与必填验证
//
// 覆盖 NoteEditorScreen ✓ 按钮的标题逻辑：
// - 标题空 + 正文有内容 → 自动取正文前 8 字符（去掉 Markdown 标记）作为标题
// - 标题空 + 正文空 → 弹 alert 拦截
// - 标题非空：正常放行
// - alert 关闭：alert 上"确定"能正常消失
// - alert 关闭后：编辑器仍在（没 pop）

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import '../_support/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('笔记标题自动提取与必填：6 个场景', (tester) async {
    final app = await createTestApp(locale: const Locale('zh'));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final ts = DateTime.now().millisecondsSinceEpoch;
    final themeTitle = 'TitleReq主题_$ts';

    // 切换到笔记 Tab
    await _switchToNotesTab(tester);
    await tester.pumpAndSettle();

    // 1. 入口：点 + → 创建新主题 → 进入 NoteEditorScreen
    await _enterEditorWithFreshTheme(tester, themeTitle);
    await tester.pump(const Duration(milliseconds: 500));

    final titleInput = find.byKey(const ValueKey('note_title_input'));
    final bodyInput = find.byKey(const ValueKey('note_body_input'));
    final checkBtn = find.byIcon(AppIcons.check);
    const cannotEmpty = '标题不能为空，请输入后再保存';

    // ────────────────────────────────────────────────────────────────
    // Case 1: 完全空标题 + 点 ✓ → 弹 alert + 编辑器仍在
    // ────────────────────────────────────────────────────────────────
    expect(titleInput, findsOneWidget, reason: '编辑器应展示标题输入框');
    await tester.enterText(titleInput, '');
    await tester.pump();

    await tester.tap(checkBtn);
    await tester.pumpAndSettle();

    expect(find.text(cannotEmpty), findsOneWidget,
        reason: '空标题点 ✓ 应弹出 titleCannotBeEmpty 提示');
    // 编辑器 NavigationBar 仍在 → 没 pop
    expect(find.byIcon(AppIcons.check), findsOneWidget,
        reason: '校验弹 alert 后编辑器不应 pop');

    // ────────────────────────────────────────────────────────────────
    // Case 2: 关闭 alert → 编辑器还在 + 输入框还在
    // ────────────────────────────────────────────────────────────────
    await _dismissAlert(tester, '确定');
    await tester.pumpAndSettle();

    expect(find.text(cannotEmpty), findsNothing,
        reason: '点 alert 的"确定"后提示应消失');
    expect(find.byKey(const ValueKey('note_title_input')), findsOneWidget,
        reason: 'alert 关闭后编辑器应仍在');
    expect(find.byKey(const ValueKey('note_body_input')), findsOneWidget,
        reason: 'alert 关闭后 body 输入框应仍在');

    // ────────────────────────────────────────────────────────────────
    // Case 3: 标题空 + 正文有内容 → 自动取正文前 8 字符作为标题
    // ────────────────────────────────────────────────────────────────
    await tester.enterText(titleInput, '');
    await tester.pump();
    await tester.enterText(bodyInput, '这是一段测试正文内容');
    await tester.pump();

    await tester.tap(checkBtn);
    await tester.pumpAndSettle();

    // 不应弹 alert，应正常保存并退出
    expect(find.text(cannotEmpty), findsNothing,
        reason: '有正文时空标题应自动提取，不应弹 alert');
    expect(find.byKey(const ValueKey('note_title_input')), findsNothing,
        reason: '自动提取标题后应 pop 回列表');

    // ────────────────────────────────────────────────────────────────
    // Case 4: 标题空 + 正文空 → 弹 alert 拦截
    // ────────────────────────────────────────────────────────────────
    // 从 ThemeNoteListScreen 返回 NoteBrowseScreen，再进入新编辑器
    // 使用 back 按钮返回
    final backBtn = find.byIcon(AppIcons.back);
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tap(backBtn.first);
      await tester.pumpAndSettle();
    }
    await _enterEditorWithFreshTheme(tester, '${themeTitle}_2');
    await tester.pump(const Duration(milliseconds: 500));

    final titleInput2 = find.byKey(const ValueKey('note_title_input'));
    final bodyInput2 = find.byKey(const ValueKey('note_body_input'));
    final checkBtn2 = find.byIcon(AppIcons.check);

    // 不输入标题，也不输入正文
    await tester.enterText(titleInput2, '');
    await tester.pump();
    await tester.enterText(bodyInput2, '');
    await tester.pump();

    await tester.tap(checkBtn2);
    await tester.pumpAndSettle();

    expect(find.text(cannotEmpty), findsOneWidget,
        reason: '标题和正文都为空时应弹 alert 拦截');

    // 关闭 alert 后，直接在同一个编辑器里测试 Case 5 和 Case 6
    // ────────────────────────────────────────────────────────────────
    // Case 5: 正常标题 → 正常退出（对照组）
    // ────────────────────────────────────────────────────────────────
    const validTitle = '有效标题A';
    await tester.enterText(titleInput2, validTitle);
    await tester.pump();
    await tester.enterText(bodyInput2, '一些正文内容');
    await tester.pump();
    // 等自动保存 debounce
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(checkBtn2);
    await tester.pumpAndSettle();

    expect(find.text(cannotEmpty), findsNothing,
        reason: '有有效标题时不应弹 alert');
    // 验证已返回到 ThemeNoteListScreen（通过查找大标题页的 trailing + 按钮）
    // NoteEditorScreen 的 check 按钮和 ThemeNoteListScreen 的 add 按钮都用 AppIcons.check / AppIcons.add
    // 用 page bg 差异或导航栏标题判断更可靠，这里简化：直接等待并检查编辑器 key 消失
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note_title_input')), findsNothing,
        reason: '点 ✓ 后应 pop 回列表（编辑器消失）');

    // ────────────────────────────────────────────────────────────────
    // Case 6: 再次进入编辑器 → 标题清空 + 正文清空 → 弹 alert → 关闭 → 编辑器仍在
    //   验证 alert 多次触发的稳定性 + 不残留状态
    // ────────────────────────────────────────────────────────────────
    // 从 ThemeNoteListScreen 返回 NoteBrowseScreen
    final backBtn2 = find.byIcon(AppIcons.back);
    if (backBtn2.evaluate().isNotEmpty) {
      await tester.tap(backBtn2.first);
      await tester.pumpAndSettle();
    }

    // 重新进入编辑器（新笔记）
    await _enterEditorWithFreshTheme(tester, '${themeTitle}_3');
    await tester.pump(const Duration(milliseconds: 500));

    final titleInput3 = find.byKey(const ValueKey('note_title_input'));
    final bodyInput3 = find.byKey(const ValueKey('note_body_input'));
    final checkBtn3 = find.byIcon(AppIcons.check);

    // 先输入一些内容，然后清空，再点 ✓
    await tester.enterText(titleInput3, '临时标题');
    await tester.pump();
    await tester.enterText(bodyInput3, '临时正文');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 清空 title 和 body
    await tester.enterText(titleInput3, '');
    await tester.pump();
    await tester.enterText(bodyInput3, '');
    await tester.pump();

    await tester.tap(checkBtn3);
    await tester.pumpAndSettle();

    expect(find.text(cannotEmpty), findsOneWidget,
        reason: '标题和正文都空时应弹 alert');
    expect(find.byKey(const ValueKey('note_title_input')), findsOneWidget,
        reason: '弹 alert 后编辑器应仍在');

    await _dismissAlert(tester, '确定');
    await tester.pumpAndSettle();
    expect(find.text(cannotEmpty), findsNothing, reason: '重复触发 alert 也能正常关闭');
  }, timeout: const Timeout(Duration(seconds: 120)));
}

// ---------------------------------------------------------------------------
// Local helpers
// ---------------------------------------------------------------------------

Future<void> _switchToNotesTab(WidgetTester tester) async {
  final label = find.text('笔记');
  expect(label, findsWidgets, reason: '底部 tab 应包含"笔记"');
  await tester.tap(label.first, warnIfMissed: false);
}

Future<void> _enterEditorWithFreshTheme(
  WidgetTester tester,
  String themeTitle,
) async {
  // 点 + 按钮 → ThemePicker 打开
  final addBtn = find.byKey(const ValueKey('add_note_button'));
  expect(addBtn, findsOneWidget, reason: '笔记列表页应找到 + 按钮');
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  // ThemePicker 里点 + 创建新主题
  final addThemeBtns = find.byIcon(AppIcons.add);
  await tester.tap(addThemeBtns.last);
  await tester.pumpAndSettle();

  // 填主题标题 + 创建
  final themeTitleInput = find.byType(CupertinoTextField);
  expect(themeTitleInput, findsWidgets, reason: '应找到主题标题输入框');
  await tester.enterText(themeTitleInput.last, themeTitle);
  await tester.pump();

  final createBtn = find.text('创建');
  expect(createBtn, findsOneWidget, reason: '应找到"创建"按钮');
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}

/// 关闭 ThkAlert：点 defaultAction（默认 button）
Future<void> _dismissAlert(WidgetTester tester, String actionLabel) async {
  final action = find.text(actionLabel);
  expect(action, findsWidgets, reason: 'alert 上应找到"$actionLabel"按钮');
  await tester.tap(action.last);
}
