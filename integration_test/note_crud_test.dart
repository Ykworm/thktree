// 笔记 CRUD 全流程集成测试
//
// 验证「创建笔记 → 编辑笔记 → 重命名笔记 → 删除笔记」完整链路。
//
// 备注：
// - 纯 CRUD 操作（不涉及 LLM）
// - 不清理测试数据
// - 时间戳避免重复运行冲突
// - 超时：90 秒

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/thk_list_tile.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('笔记 CRUD 全流程 + 持久化验证', (tester) async {
    final app = await createTestApp(locale: const Locale('zh'));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final ts = DateTime.now().millisecondsSinceEpoch;
    final themeTitle = 'Intg主题_$ts';
    final noteTitle = 'Intg笔记_$ts';
    final editedContent = '编辑后的内容_$ts';
    final renamedTitle = '重命名_$ts';

    // 切换到底部 "笔记" tab
    await _switchToTab(tester, '笔记');
    await tester.pumpAndSettle();

    // ──────────────────────────────────────────────────────────────────────
    // 步骤 1: 创建笔记
    // ──────────────────────────────────────────────────────────────────────
    await _createNote(tester, themeTitle, noteTitle, '测试内容');

    // 创建完成后回到 NoteBrowseScreen，需要点击主题进入 ThemeNoteListScreen 验证
    await tester.pump(const Duration(milliseconds: 500));
    await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));
    await tester.tap(find.text(themeTitle));
    await tester.pumpAndSettle();

    // 验证笔记出现在主题笔记列表中
    await waitForText(tester, noteTitle, timeout: const Duration(seconds: 10));
    expect(find.text(noteTitle), findsOneWidget, reason: '新笔记应出现在主题笔记列表中');

    // ──────────────────────────────────────────────────────────────────────
    // 步骤 2: 编辑笔记
    // ──────────────────────────────────────────────────────────────────────
    await _editNote(tester, noteTitle, editedContent);

    // ──────────────────────────────────────────────────────────────────────
    // 步骤 3: 重命名笔记
    // ──────────────────────────────────────────────────────────────────────
    await _renameNote(tester, renamedTitle);

    // ──────────────────────────────────────────────────────────────────────
    // 步骤 4: 删除笔记
    // ──────────────────────────────────────────────────────────────────────
    await _deleteNote(tester, renamedTitle);

  }, timeout: const Timeout(Duration(seconds: 90)));
}

// ---------------------------------------------------------------------------
// Local helpers
// ---------------------------------------------------------------------------

Future<void> _switchToTab(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  expect(labelFinder, findsWidgets, reason: '底部 tab 应包含 "$label"');
  await tester.tap(labelFinder.first, warnIfMissed: false);
}

/// 创建笔记：
/// NoteBrowseScreen → 点 + → ThemePicker → 创建主题 → pop → NoteEditorScreen
/// → 填写 → 点 check → pop 回 NoteBrowseScreen
Future<void> _createNote(
  WidgetTester tester,
  String themeTitle,
  String noteTitle,
  String content,
) async {
  // 1. 点 NoteBrowseScreen 的 + 按钮
  final addBtn = find.byKey(const ValueKey('add_note_button'));
  expect(addBtn, findsOneWidget, reason: '笔记列表页应找到 + 按钮');
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  // 2. ThemePicker 已打开，点 + 创建新主题
  final addThemeBtns = find.byIcon(AppIcons.add);
  await tester.tap(addThemeBtns.last);
  await tester.pumpAndSettle();

  // 3. 输入主题标题并创建
  final themeTitleInput = find.byType(CupertinoTextField);
  expect(themeTitleInput, findsWidgets, reason: '应找到主题标题输入框');
  await tester.enterText(themeTitleInput.last, themeTitle);
  await tester.pump();

  final createBtn = find.text('创建');
  expect(createBtn, findsOneWidget, reason: '应找到创建按钮');
  await tester.tap(createBtn);
  await tester.pumpAndSettle();

  // 4. NoteEditorScreen 已打开
  await tester.pump(const Duration(milliseconds: 500));

  final titleInput = find.byKey(const ValueKey('note_title_input'));
  expect(titleInput, findsOneWidget, reason: '应找到标题输入框');
  await tester.enterText(titleInput, noteTitle);
  await tester.pump();

  final bodyInput = find.byKey(const ValueKey('note_body_input'));
  expect(bodyInput, findsOneWidget, reason: '应找到内容输入框');
  await tester.enterText(bodyInput, content);
  await tester.pump();

  // 等待自动保存
  await tester.pump(const Duration(milliseconds: 600));

  // 5. 点 check 退出编辑器
  final checkBtn = find.byIcon(AppIcons.check);
  expect(checkBtn, findsOneWidget, reason: '应找到 check 按钮');
  await tester.tap(checkBtn);
  await tester.pumpAndSettle();
}

/// 编辑笔记：ThemeNoteListScreen → NoteDetailScreen → 编辑 → 退出
Future<void> _editNote(
  WidgetTester tester,
  String noteTitle,
  String newContent,
) async {
  // 点击笔记进入详情
  await tester.tap(find.text(noteTitle));
  await tester.pumpAndSettle();

  // 点击编辑按钮
  final editBtn = find.byKey(const ValueKey('note_edit_button'));
  expect(editBtn, findsOneWidget, reason: '应找到编辑按钮');
  await tester.tap(editBtn);
  await tester.pumpAndSettle();

  // 修改内容
  final bodyInput = find.byType(CupertinoTextField);
  expect(bodyInput, findsWidgets, reason: '应找到内容输入框');
  await tester.enterText(bodyInput.last, newContent);
  await tester.pump();

  // 等待自动保存
  await tester.pump(const Duration(milliseconds: 600));

  // 退出编辑模式
  final editBtnAfter = find.byKey(const ValueKey('note_edit_button'));
  await tester.tap(editBtnAfter);
  await tester.pumpAndSettle();

  // 验证修改成功（NoteDetailScreen 显示编辑后的内容）
  expect(find.text(newContent), findsWidgets, reason: '笔记内容应已更新');

  // 返回 ThemeNoteListScreen
  final backBtn = find.byIcon(CupertinoIcons.back);
  if (backBtn.evaluate().isNotEmpty) {
    await tester.tap(backBtn.first);
    await tester.pumpAndSettle();
  }
  
  // 等待列表刷新
  await tester.pump(const Duration(milliseconds: 500));
}

/// 重命名笔记
Future<void> _renameNote(WidgetTester tester, String newTitle) async {
  // 确保在 ThemeNoteListScreen，找到笔记标题并点击进入详情
  final noteTiles = find.byType(ThkListTile);
  if (noteTiles.evaluate().isEmpty) {
    // 可能不在 ThemeNoteListScreen，尝试用文本查找
    final noteText = find.textContaining('Intg笔记');
    if (noteText.evaluate().isNotEmpty) {
      await tester.tap(noteText.first);
    }
  } else {
    await tester.tap(noteTiles.first);
  }
  await tester.pumpAndSettle();

  // 点击更多操作按钮
  final moreBtn = find.byKey(const ValueKey('note_more_actions_button'));
  expect(moreBtn, findsOneWidget, reason: '应找到更多操作按钮');
  await tester.tap(moreBtn);
  await tester.pumpAndSettle();

  // 选择重命名
  final renameBtn = find.text('重命名笔记');
  expect(renameBtn, findsOneWidget, reason: '应找到重命名选项');
  await tester.tap(renameBtn);
  await tester.pumpAndSettle();

  // 输入新标题
  final titleInput = find.byType(CupertinoTextField);
  expect(titleInput, findsWidgets, reason: '应找到标题输入框');
  await tester.enterText(titleInput.last, newTitle);
  await tester.pump();

  // 点击保存按钮
  final saveBtn = find.text('保存');
  expect(saveBtn, findsOneWidget, reason: '应找到保存按钮');
  await tester.tap(saveBtn);
  await tester.pumpAndSettle();

  // 等待重命名完成
  await tester.pump(const Duration(milliseconds: 500));

  // 在 NoteDetailScreen 验证重命名成功（导航栏应显示新标题）
  expect(find.text(newTitle), findsWidgets, reason: '笔记标题应已重命名');

  // 返回 ThemeNoteListScreen
  final backBtn = find.byIcon(CupertinoIcons.back);
  if (backBtn.evaluate().isNotEmpty) {
    await tester.tap(backBtn.first);
    await tester.pumpAndSettle();
  }

  // 等待列表刷新
  await tester.pump(const Duration(milliseconds: 500));
}

/// 删除笔记
Future<void> _deleteNote(WidgetTester tester, String noteTitle) async {
  // 点击笔记进入详情
  await tester.tap(find.text(noteTitle));
  await tester.pumpAndSettle();

  // 点击更多操作按钮
  final moreBtn = find.byKey(const ValueKey('note_more_actions_button'));
  expect(moreBtn, findsOneWidget, reason: '应找到更多操作按钮');
  await tester.tap(moreBtn);
  await tester.pumpAndSettle();

  // 选择删除（底部 sheet 中的删除按钮）
  final deleteBtn = find.text('删除');
  expect(deleteBtn, findsWidgets, reason: '应找到删除选项');
  await tester.tap(deleteBtn.first);
  await tester.pumpAndSettle();

  // 等待确认弹窗出现
  await tester.pump(const Duration(milliseconds: 500));

  // 确认删除（CupertinoAlertDialog 中的删除按钮）
  final confirmBtn = find.text('删除');
  expect(confirmBtn, findsWidgets, reason: '应找到确认删除按钮');
  await tester.tap(confirmBtn.last);
  await tester.pumpAndSettle();

  // 删除后自动 pop 回 ThemeNoteListScreen
  expect(find.text(noteTitle), findsNothing, reason: '笔记应已删除');
}
