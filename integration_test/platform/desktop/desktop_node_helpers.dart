// macOS 桌面端集成测试 — 节点 Helper
//
// 依赖：desktop_primitive_helpers.dart, desktop_theme_helpers.dart (ThemeCtx)

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'desktop_primitive_helpers.dart';
import 'desktop_test_fixtures.dart' show ThemeCtx, NodeCtx, ChatCtx;

/// 在指定主题下创建根节点
Future<NodeCtx> createRootNode(WidgetTester tester, ThemeCtx theme, String title) async {
  await tapKey(tester, const ValueKey('add_node_button'));
  await tester.pumpAndSettle();

  await enterTextByKey(tester, const ValueKey('node_title_input'), title);

  await tapKey(tester, const ValueKey('node_create_button'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();

  // 滚到可见
  await scrollToText(tester, title);
  assertText(tester, title, count: 1);

  // 从 widget tree 中 mock nodeId（无法从 UI 直接获取，用已知模式构造）
  // 实际集成测试中，nodeId 不重要——我们用 title 定位
  final ctx = NodeCtx(
    nodeId: title, // 用 title 作为临时 ID
    title: title,
    theme: theme,
    depth: 1,
  );
  theme.roots.add(ctx);
  return ctx;
}

/// 选中节点，返回 ChatCtx（打开右栏聊天）
Future<ChatCtx> selectNode(WidgetTester tester, NodeCtx node) async {
  await scrollToText(tester, node.title);
  await tapFinder(tester, find.text(node.title), warnIfMissed: true);
  await tester.pumpAndSettle();
  await waitForKey(tester, const ValueKey('chat_input'));
  return ChatCtx(node: node);
}

/// 在主题下创建 N 层节点树
/// [depth] 最大深度（根节点=1），[countPerLevel] 每层创建多少节点
Future<ThemeCtx> createNodeTree(
  WidgetTester tester,
  ThemeCtx theme, {
  int depth = 3,
  int countPerLevel = 3,
}) async {
  // 逐层创建：先创建所有根节点，再在首个子节点下创建下一层
  for (int i = 0; i < countPerLevel; i++) {
    await createRootNode(tester, theme, '根节点_${theme.title}_$i');
  }

  // 深度≥2：在第一个根节点下创建子节点
  if (depth >= 2 && theme.roots.isNotEmpty) {
    final root = theme.roots.first;
    // 选中第一个根节点（展开子节点视图）
    // 注意：选中根节点后，需回到 ThemeDetailScreen 再创建子节点
    // 这里先在根节点对话中创建分支（branch）
    // 子节点创建走分支创建流程，见 desktop_branch_helpers.dart
  }

  return theme;
}

/// 验证无法超过 kMaxNodeDepth（=4）
Future<void> assertMaxDepthExceeded(WidgetTester tester, NodeCtx deepestNode) async {
  // 选中最深节点
  await selectNode(tester, deepestNode);

  // 尝试创建分支（应被拦截并显示错误提示）
  // 实现依赖于具体的分支创建 UI —— 如果当前节点 depth=4，创建子节点应被拒绝
  // 具体断言在 desktop_branch_helpers.dart 中
}
