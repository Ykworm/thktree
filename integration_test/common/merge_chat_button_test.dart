// Merge Chat 按钮可点击性 E2E 测试
//
// 验证 FullTreeScreen 多选模式下底部 "合并 & 创建新 Chat" 按钮可点击并导航到确认页。
// 不涉及 LLM 调用，仅验证 UI 交互链路。
//
// 流程：
// 1. App 启动 → 切换到"主题" tab
// 2. 创建测试主题
// 3. 创建 2 个 chat 节点
// 4. 进入主题详情 → Overflow → "合并 & 创建新 Chat"
// 5. FullTreeScreen 加载（多选模式自动开启）
// 6. 点击 2 个节点标题选中
// 7. 点击底部"合并 & 创建新 Chat"按钮
// 8. 验证导航到 MergeChatConfirmScreen（检查"选择挂载位置"文本）

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import '../_support/step_timer.dart';
import '../_support/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Merge Chat 按钮可点击并导航到确认页', (tester) async {
    final timer = StepTimer()..start();

    // ──────────────────────────────────────────────────────────────────────
    // 1. 启动 App（中文 locale，不需要 LLM Config）
    // ──────────────────────────────────────────────────────────────────────
    final app = await createTestApp(
      locale: const Locale('zh'),
      llmSettings: AppSettings(
        localeLanguageCode: 'zh',
        faceIdEnabled: false,
        darkMode: false,
      ),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    timer.step('启动 App');

    // 获取本地化实例
    final appElement = tester.element(find.byType(CupertinoApp));
    final l10n = AppLocalizations.of(appElement)!;

    // 时间戳后缀，避免数据冲突
    final ts = DateTime.now().millisecondsSinceEpoch;
    final themeTitle = 'MergeTest_$ts';
    final node1Title = 'N1_$ts';
    final node2Title = 'N2_$ts';

    // ──────────────────────────────────────────────────────────────────────
    // 2. 切换到"主题" tab
    // ──────────────────────────────────────────────────────────────────────
    await _switchToTab(tester, l10n.themesTabLabel);
    await tester.pumpAndSettle();
    timer.step('切换到主题 tab');

    // ──────────────────────────────────────────────────────────────────────
    // 3. 创建主题
    // ──────────────────────────────────────────────────────────────────────
    await _createTheme(tester, themeTitle, l10n);
    await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));
    expect(find.text(themeTitle), findsOneWidget,
        reason: '新主题应出现在列表中');
    timer.step('创建主题');

    // ──────────────────────────────────────────────────────────────────────
    // 4. 进入主题详情
    // ──────────────────────────────────────────────────────────────────────
    await tester.tap(find.text(themeTitle));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('add_node_button')),
      findsOneWidget,
      reason: '进入主题详情后应能看到 + 按钮',
    );
    timer.step('进入主题详情');

    // ──────────────────────────────────────────────────────────────────────
    // 5. 创建 2 个 chat 节点
    // ──────────────────────────────────────────────────────────────────────
    await _createNode(tester, node1Title);
    await waitForText(tester, node1Title, timeout: const Duration(seconds: 10));
    expect(find.text(node1Title), findsOneWidget,
        reason: '第 1 个节点应出现在树中');
    timer.step('创建节点 1');

    await _createNode(tester, node2Title);
    await waitForText(tester, node2Title, timeout: const Duration(seconds: 10));
    expect(find.text(node2Title), findsOneWidget,
        reason: '第 2 个节点应出现在树中');
    timer.step('创建节点 2');

    // ──────────────────────────────────────────────────────────────────────
    // 6. 点击 overflow menu → 选"合并 & 创建新 Chat"
    // ──────────────────────────────────────────────────────────────────────
    await tester.tap(find.byKey(const ValueKey('overflow_menu_button')));
    await tester.pumpAndSettle();

    // CupertinoActionSheet 中出现"合并 & 创建新 Chat" action
    await tester.tap(find.text(l10n.mergeAndCreate));
    await tester.pumpAndSettle();
    timer.step('打开合并页面');

    // ──────────────────────────────────────────────────────────────────────
    // 7. FullTreeScreen 已加载，多选模式应已开启。
    //    点击节点标题选择节点（用 .last 避开 ThemeDetailScreen 中的同名节点）
    // ──────────────────────────────────────────────────────────────────────
    // 选择第一个节点
    await tester.tap(find.text(node1Title).last);
    await tester.pump();

    // 选择第二个节点
    await tester.tap(find.text(node2Title).last);
    await tester.pump();

    // 验证选择计数显示（"已选 2/3"）
    expect(
      find.text(l10n.selectedCount(2, 3)),
      findsOneWidget,
      reason: '选择 2 个节点后应显示 "已选 2/3"',
    );
    timer.step('选择 2 个节点');

    // ──────────────────────────────────────────────────────────────────────
    // 8. 点击底部"合并 & 创建新 Chat"按钮
    // ──────────────────────────────────────────────────────────────────────
    // 注意：此时 CupertinoActionSheet 已关闭且 FullTreeScreen
    // 没有其他 l10n.mergeAndCreate 文本，find.text 唯一匹配就是底部按钮。
    await tester.tap(find.text(l10n.mergeAndCreate));
    await tester.pumpAndSettle();
    timer.step('点击合并按钮');

    // ──────────────────────────────────────────────────────────────────────
    // 9. 验证导航到 MergeChatConfirmScreen
    //    - "选择挂载位置" 标题
    //    - "根节点（顶层）" 选项
    // ──────────────────────────────────────────────────────────────────────
    expect(
      find.text(l10n.selectMountLocation),
      findsOneWidget,
      reason: '应导航到合并确认页，看到"选择挂载位置"',
    );
    expect(
      find.text(l10n.rootNode),
      findsOneWidget,
      reason: '应看到"根节点（顶层）"挂载选项',
    );
    timer.step('验证确认页');

    timer.finish();
  }, timeout: const Timeout(Duration(minutes: 3)));
}

// ---------------------------------------------------------------------------
// Local helpers（复用 theme_chat_e2e_test 的模式）
// ---------------------------------------------------------------------------

Future<void> _switchToTab(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  expect(labelFinder, findsWidgets, reason: '底部 tab 应包含 "$label"');
  await tester.tap(labelFinder.first, warnIfMissed: false);
}

Future<void> _createTheme(
    WidgetTester tester, String title, AppLocalizations l10n) async {
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

Future<void> _createNode(
    WidgetTester tester, String title) async {
  final addBtn = find.byKey(const ValueKey('add_node_button'));
  expect(addBtn, findsOneWidget, reason: '主题详情页应找到 + 按钮');
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  final titleInput = find.byKey(const ValueKey('node_title_input'));
  expect(titleInput, findsOneWidget, reason: '应弹出节点创建 dialog');
  await tester.enterText(titleInput, title);
  await tester.pump();

  final createBtn = find.byKey(const ValueKey('node_create_button'));
  expect(createBtn, findsOneWidget, reason: '应找到节点创建按钮');
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}
