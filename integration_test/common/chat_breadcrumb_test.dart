// Chat 页面包屑 + initState/dispose provider 修改回归测试
//
// 背景（2026-07-09）：
// 1) 给聊天页加祖先链面包屑后，运行时报
//    "Tried to modify a provider while the widget tree was building"，
//    崩在 _ChatScreenState.initState —— initState 里直接写
//    branchFromSelectionProvider.notifier.state 违反了 Riverpod 的
//    _debugCanModifyProviders 断言。修复：把写 provider 延迟到
//    addPostFrameCallback（首帧构建完成之后）。
// 2) 用户点击面包屑回跳时崩：
//    "You have popped the last page off of the stack"。根因：聊天页位于
//    go_router 的 StatefulShellBranch 内、栈由 go_router 管理，原实现用
//    Navigator.popUntil 按 RouteSettings.name 弹栈会把 go_router 的 route
//    match list 摘空。修复：go_router 路由改用 GoRouter.of(context).go(path)
//    声明式回跳（BreadcrumbSegment.goPath）。
// 3) 第二次崩溃：导航离开聊天页触发 dispose，dispose 里同步改 provider 同样
//    违反 _debugCanModifyProviders（"缓存 notifier 引用"没用，断言看的是
//    是否在构建/finalize 期）。修复：把清空延迟到 Future.microtask，并用闭包
//    引用做守卫只清自己设的值。
//
// 本测试覆盖：
// - 进入聊天页全程不崩（initState）
// - 面包屑渲染且含主题名段
// - 【逐个】点击每个可点面包屑段（主题 tab 根 + 主题树）都能正确回跳且不崩
//   （单级节点只有这两段可点；更深的祖先段走完全相同的 go() 代码路径，仅 path
//    不同，本无 LLM 的集成套件无法通过 UI 造出多级嵌套节点，故未单独覆盖）
//
// 备注：不需要 LLM（纯导航路径即可复现上述崩溃），不注入 llmSettings。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import '../_support/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('进入聊天页不崩溃且面包屑每段均可点回跳', (tester) async {
    // 捕获构建/生命周期期间抛出的异常（含 Riverpod 断言、go_router 栈摘空）。
    final caughtErrors = <FlutterErrorDetails>[];
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      caughtErrors.add(details);
      prevOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = prevOnError);

    final app = await createTestApp(locale: const Locale('zh'));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final ts = DateTime.now().millisecondsSinceEpoch;
    final themeTitle = 'Crumb主题_$ts';
    final nodeTitle = 'Crumb讨论_$ts';

    // App 默认进 /search，切到 "主题" tab（顺便重置 themes 分支到主题列表）
    await _switchToTab(tester, '主题');
    await tester.pumpAndSettle();

    // 创建主题
    await _createTheme(tester, themeTitle);
    await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));
    expect(find.text(themeTitle), findsOneWidget, reason: '新主题应出现在列表中');

    // 进入主题详情
    await tester.tap(find.text(themeTitle));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('add_node_button')),
      findsOneWidget,
      reason: '进入主题详情后应能看到 + 按钮',
    );

    // 创建节点
    await _createNode(tester, nodeTitle);
    await waitForText(tester, nodeTitle, timeout: const Duration(seconds: 10));
    expect(find.text(nodeTitle), findsOneWidget, reason: '新节点应出现在树中');

    // 进入聊天页 —— 触发 _ChatScreenState.initState（原崩溃点 1）
    await _enterNodeChat(tester, themeTitle, nodeTitle);

    // 断言 1：聊天页正常渲染（输入框存在 = initState 没崩）
    expect(
      find.byKey(const ValueKey('chat_input')),
      findsOneWidget,
      reason: '进入聊天页后应能看到输入框（说明 initState 未崩溃）',
    );

    // 断言 2：没有在构建期修改 provider 的断言错误（initState）
    _expectNoProviderBuildErrors(caughtErrors);

    // 断言 3：面包屑渲染，且包含主题名段
    expect(
      find.byType(ThkBreadcrumbRow),
      findsOneWidget,
      reason: '聊天页应渲染面包屑行',
    );
    expect(
      find.text(themeTitle),
      findsWidgets,
      reason: '面包屑中应包含主题名段',
    );

    // 断言 4：逐个点击每个可点面包屑段，验证回跳正确且不崩。
    // 单级节点链为 [主题(tab根), 主题名(主题树), 当前节点(不可点)]，
    // 可点段索引：1 = 主题名，0 = 主题 tab 根。
    // 每次点击会离开聊天页，故每段都重新进入聊天页再点。
    const clickableIndexes = [1, 0];
    for (final idx in clickableIndexes) {
      await _enterNodeChat(tester, themeTitle, nodeTitle);
      expect(
        find.byType(ThkBreadcrumbRow),
        findsOneWidget,
        reason: '重新进入聊天页后面包屑应仍在',
      );

      await _tapCrumb(tester, idx);

      // 回跳后聊天页面包屑应消失
      expect(
        find.byType(ThkBreadcrumbRow),
        findsNothing,
        reason: '点击面包屑第 $idx 段后应跳走，聊天页面包屑消失',
      );

      if (idx == 1) {
        // 主题名 → 主题树详情页
        expect(
          find.byKey(const ValueKey('add_node_button')),
          findsOneWidget,
          reason: '点击"主题名"后应回到主题树详情页',
        );
      } else {
        // 主题 tab 根 → 主题列表页
        expect(
          find.byKey(const ValueKey('add_theme_button')),
          findsOneWidget,
          reason: '点击"主题"后应回到主题列表页',
        );
      }
    }

    // 断言 5：全程无导航类崩溃（popUntil 摘空栈的回归）
    final navErrors = caughtErrors.where((e) {
      final s = e.exceptionAsString();
      return s.contains('popped the last page off of the stack') ||
          s.contains('currentConfiguration.isNotEmpty') ||
          s.contains('GoRouterDelegate');
    }).toList();
    expect(
      navErrors,
      isEmpty,
      reason: '不应出现 go_router 栈被摘空的导航崩溃，'
          '实际捕获：${navErrors.map((e) => e.exceptionAsString()).join("\n")}',
    );

    // 断言 6：dispose 触发后也无"构建/finalize 期改 provider"崩溃
    _expectNoProviderBuildErrors(caughtErrors,
        label: '（含 dispose 导航离开后）');
  }, timeout: const Timeout(Duration(minutes: 3)));
}

// ---------------------------------------------------------------------------
// 断言辅助
// ---------------------------------------------------------------------------

void _expectNoProviderBuildErrors(List<FlutterErrorDetails> caughtErrors,
    {String label = ''}) {
  final errors = caughtErrors.where((e) {
    final s = e.exceptionAsString();
    return s.contains(
            'Tried to modify a provider while the widget tree was building') ||
        s.contains('_debugCanModifyProviders');
  }).toList();
  expect(
    errors,
    isEmpty,
    reason: '不应出现"构建期修改 provider"断言错误$label，'
        '实际捕获：${errors.map((e) => e.exceptionAsString()).join("\n")}',
  );
}

// ---------------------------------------------------------------------------
// 导航辅助
// ---------------------------------------------------------------------------

/// 从任意状态重新进入指定节点的聊天页。
/// 先点底部"主题" tab 把 themes 分支重置到主题列表，再进主题、进节点。
Future<void> _enterNodeChat(
    WidgetTester tester, String themeTitle, String nodeTitle) async {
  await _switchToTab(tester, '主题');
  await tester.pumpAndSettle();
  await tester.tap(find.text(themeTitle));
  await tester.pumpAndSettle();
  await tester.tap(find.text(nodeTitle));
  await tester.pumpAndSettle();
}

/// 点击面包屑行中第 [index] 个可点段（GestureDetector）。
/// 顺序：index 0 = 第一段（主题 tab 根），1 = 第二段（主题名），……末段不可点。
Future<void> _tapCrumb(WidgetTester tester, int index) async {
  final crumbRow = find.byType(ThkBreadcrumbRow);
  final tappable = find.descendant(
    of: crumbRow,
    matching: find.byType(GestureDetector),
  );
  await tester.tap(tappable.at(index));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Local helpers（复制自 theme_chat_e2e_test.dart，保持独立）
// ---------------------------------------------------------------------------

Future<void> _switchToTab(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  expect(labelFinder, findsWidgets, reason: '底部 tab 应包含 "$label"');
  await tester.tap(labelFinder.first, warnIfMissed: false);
}

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

Future<void> _createNode(WidgetTester tester, String title) async {
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
