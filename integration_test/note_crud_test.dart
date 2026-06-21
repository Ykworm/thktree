// 笔记 CRUD 集成测试
//
// 验证笔记的完整生命周期：
// 1. 创建笔记（通过主题选择器）
// 2. 编辑笔记内容
// 3. 重命名笔记
// 4. 重启 App 验证持久化
// 5. 删除笔记
//
// 备注：
// - 不依赖 LLM（纯 CRUD 操作）
// - 不清理测试数据
// - 时间戳后缀避免重复运行冲突
// - 超时：90 秒

import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/thk_text_field.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('笔记 CRUD 完整生命周期', (tester) async {
    // 启动 App，强制中文 locale
    final app = await createTestApp(locale: const Locale('zh'));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // 时间戳后缀，避免重复运行冲突
    final ts = DateTime.now().millisecondsSinceEpoch;
    final themeTitle = 'Intg笔记主题_$ts';
    final noteTitle = 'Intg笔记_$ts';
    final editBody = '测试内容_$ts';
    final editAppend = '追加内容_$ts';
    final renameTitle = 'Intg重命名_$ts';

    // ── 准备：创建主题 ───────────────────────────────────────────────
    await _switchToTab(tester, '主题');
    await tester.pumpAndSettle();
    await _createTheme(tester, themeTitle);
    await waitForText(tester, themeTitle,
        timeout: const Duration(seconds: 10));
    expect(find.text(themeTitle), findsOneWidget,
        reason: '新主题应出现在主题列表中');

    // ── 步骤 1：创建笔记 ──────────────────────────────────────────────
    await _switchToTab(tester, '笔记');
    await tester.pumpAndSettle();

    final addBtn = find.byIcon(AppIcons.add);
    expect(addBtn, findsWidgets, reason: '笔记页应有 + 按钮');
    await tester.tap(addBtn.last);
    await tester.pumpAndSettle();

    await waitForText(tester, themeTitle,
        timeout: const Duration(seconds: 10));
    await tester.tap(find.text(themeTitle).last);
    await tester.pumpAndSettle();

    expect(find.text('无标题'), findsOneWidget,
        reason: '编辑器标题输入框应显示 placeholder');
    expect(find.text('开始写点什么...'), findsOneWidget,
        reason: '编辑器内容输入框应显示 placeholder');

    final textFields = find.byType(CupertinoTextField);
    expect(textFields, findsWidgets, reason: '编辑器应有文本输入框');

    await tester.enterText(textFields.first, noteTitle);
    await tester.pump();
    await tester.enterText(textFields.at(1), editBody);
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.check));
    await tester.pumpAndSettle();

    // 进入主题笔记列表验证
    await waitForText(tester, themeTitle,
        timeout: const Duration(seconds: 10));
    await tester.tap(find.text(themeTitle));
    await tester.pumpAndSettle();

    await waitForText(tester, noteTitle,
        timeout: const Duration(seconds: 10));
    expect(find.text(noteTitle), findsOneWidget,
        reason: '创建后笔记应出现在主题笔记列表中');

    // ── 步骤 2：编辑笔记 ──────────────────────────────────────────────
    await tester.tap(find.text(noteTitle));
    await tester.pumpAndSettle();

    expect(find.text(editBody), findsOneWidget,
        reason: '详情页应显示笔记内容');

    await tester.tap(find.byIcon(AppIcons.edit));
    await tester.pumpAndSettle();

    final editField = find.byType(CupertinoTextField);
    expect(editField, findsOneWidget,
        reason: '编辑模式应有且仅有一个文本输入框');

    await tester.enterText(editField, '$editBody$editAppend');
    await tester.pump();
    await tester.tap(find.byIcon(AppIcons.check));
    await tester.pumpAndSettle();

    expect(find.textContaining(editAppend), findsWidgets,
        reason: '编辑后详情页应显示追加内容');

    // ── 步骤 3：重命名笔记 ──────────────────────────────────────────
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();

    await tester.tap(find.text('重命名笔记'));
    await tester.pumpAndSettle();

    final renameInput = find.byType(ThkTextField);
    expect(renameInput, findsOneWidget, reason: '重命名对话框应有输入框');
    await tester.enterText(renameInput, renameTitle);
    await tester.pump();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();

    await waitForText(tester, renameTitle,
        timeout: const Duration(seconds: 5));
    expect(find.text(renameTitle), findsOneWidget,
        reason: '重命名后列表应显示新标题');
    expect(find.text(noteTitle), findsNothing,
        reason: '旧标题不应再出现');

    // ── 步骤 4：验证持久化（数据层）─────────────────────────────────
    // 通过直接读取文件系统验证笔记数据已持久化到磁盘。
    // pumpWidget 重启在集成测试中存在全局 GoRouter 状态残留问题，
    // 因此用数据层验证替代 UI 重启验证。
    await tester.runAsync(() async {
      final paths = await AppPaths.load();
      final themesDir = paths.themesDir;

      // 扫描 themes 目录找到测试主题
      final themeDirs = await themesDir.list().toList();
      Directory? testThemeDir;
      for (final entity in themeDirs) {
        if (entity is! Directory) continue;
        final metaFile = File('${entity.path}/theme.meta.json');
        if (await metaFile.exists()) {
          final content = await metaFile.readAsString();
          final map = jsonDecode(content) as Map<String, dynamic>;
          if (map['title'] == themeTitle) {
            testThemeDir = entity;
            break;
          }
        }
      }
      expect(testThemeDir, isNotNull,
          reason: '持久化后主题目录应存在');

      // 验证笔记存在且标题已重命名
      final notesDir =
          Directory('${testThemeDir!.path}/notes');
      final noteStore = NoteStore(notesDir: notesDir);
      final metas = await noteStore.listNoteMetas(includePreview: true);
      final note =
          metas.where((m) => m.title == renameTitle).firstOrNull;
      expect(note, isNotNull,
          reason: '持久化后重命名笔记应存在');

      // 验证笔记内容包含编辑后的内容
      final body = await noteStore.readBody(note!.noteId);
      expect(body, contains(editAppend),
          reason: '持久化后笔记内容应包含编辑追加');
    });

    // ── 步骤 5：删除笔记 ────────────────────────────────────────────
    // 步骤 3 pop 后已在主题笔记列表，点击笔记进入详情
    await tester.tap(find.text(renameTitle));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget,
        reason: '应弹出删除确认对话框');
    await waitForWidget(
      tester,
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('删除'),
      ),
      timeout: const Duration(seconds: 5),
    );
    await tester.tap(find.descendant(
      of: find.byType(CupertinoAlertDialog),
      matching: find.text('删除'),
    ));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(renameTitle), findsNothing,
        reason: '删除后笔记应从列表消失');
  }, timeout: const Timeout(Duration(seconds: 90)));
}

// ---------------------------------------------------------------------------
// Local helpers
// ---------------------------------------------------------------------------

/// 点底部 tab 栏的指定 tab（按 label 文本定位）。
Future<void> _switchToTab(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  expect(labelFinder, findsWidgets, reason: '底部 tab 应包含 "$label"');
  await tester.tap(labelFinder.first, warnIfMissed: false);
}

/// 在主题列表页创建主题：点 + 按钮 → dialog → 输入标题 → 点"创建"。
Future<void> _createTheme(WidgetTester tester, String title) async {
  final addBtn = find.byKey(const ValueKey('add_theme_button'));
  expect(addBtn, findsOneWidget, reason: '主题列表页应找到 + 按钮');
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  final titleInput = find.byKey(const ValueKey('theme_title_input'));
  expect(titleInput, findsOneWidget, reason: '应弹出主题创建 dialog');
  await tester.enterText(titleInput, title);
  await tester.pump();

  final createBtn = find.byKey(const ValueKey('theme_create_button'));
  expect(createBtn, findsOneWidget, reason: '应找到主题创建按钮');
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}
