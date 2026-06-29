// 笔记标题必填验证
//
// 覆盖 NoteEditorScreen ✓ 按钮的空标题校验：
// - 完全空字符串
// - 纯空格（trim 后为空）
// - 标题非空：正常放行
// - alert 关闭：alert 上"确定"能正常消失
// - alert 关闭后：编辑器仍在（没 pop）

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('笔记标题必填：5 个场景', (tester) async {
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
    // Case 3: 纯空格标题 + 点 ✓ → 弹 alert（trim().isEmpty 必须拦截）
    // ────────────────────────────────────────────────────────────────
    await tester.enterText(titleInput, '   ');
    await tester.pump();
    // body 也填一段内容，确保"有内容"也不能蒙混过关
    await tester.enterText(bodyInput, '有内容但标题是空格');
    await tester.pump();

    await tester.tap(checkBtn);
    await tester.pumpAndSettle();

    expect(find.text(cannotEmpty), findsOneWidget,
        reason: '纯空格标题点 ✓ 也应被拦截');

    // 关闭 alert 进入下一个 case
    await _dismissAlert(tester, '确定');
    await tester.pumpAndSettle();

    // ────────────────────────────────────────────────────────────────
    // Case 4: 正常标题 → 正常退出（对照组）
    // ────────────────────────────────────────────────────────────────
    const validTitle = '有效标题A';
    await tester.enterText(titleInput, validTitle);
    await tester.pump();
    // 等自动保存 debounce
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(checkBtn);
    await tester.pumpAndSettle();

    expect(find.text(cannotEmpty), findsNothing,
        reason: '有有效标题时不应弹 alert');
    expect(find.byKey(const ValueKey('note_title_input')), findsNothing,
        reason: '点 ✓ 后应 pop 回列表（编辑器消失）');

    // ────────────────────────────────────────────────────────────────
    // Case 5: 再次进入编辑器 → 标题清空 → 弹 alert → 关闭 → 编辑器仍在
    //   验证 alert 多次触发的稳定性 + 不残留状态
    // ────────────────────────────────────────────────────────────────
    // 当前应在主题笔记列表中，可点击笔记再次进入编辑器
    // 注：编辑器对已有笔记会 load 现有标题，"再次进入 + 清空 + 拦截"是更接近真实场景的复测
    await waitForText(tester, validTitle, timeout: const Duration(seconds: 10));
    await tester.tap(find.text(validTitle));
    await tester.pumpAndSettle();

    // 进入编辑模式（NoteDetailScreen 的 edit 按钮）
    final editBtn = find.byKey(const ValueKey('note_edit_button'));
    expect(editBtn, findsOneWidget, reason: '详情页应展示编辑按钮');
    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    // title 应预填旧值，全部清空再点 ✓
    final editTitleInput = find.byKey(const ValueKey('note_title_input'));
    expect(editTitleInput, findsOneWidget, reason: '编辑模式应展示标题输入框');
    await tester.enterText(editTitleInput, '');
    await tester.pump();

    final editCheckBtn = find.byIcon(AppIcons.check);
    await tester.tap(editCheckBtn);
    await tester.pumpAndSettle();

    expect(find.text(cannotEmpty), findsOneWidget,
        reason: '编辑模式下空标题也应弹 alert');
    expect(find.byKey(const ValueKey('note_title_input')), findsOneWidget,
        reason: '弹 alert 后编辑器应仍在');

    await _dismissAlert(tester, '确定');
    await tester.pumpAndSettle();
    expect(find.text(cannotEmpty), findsNothing, reason: '重复触发 alert 也能正常关闭');
  }, timeout: const Timeout(Duration(seconds: 90)));
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
