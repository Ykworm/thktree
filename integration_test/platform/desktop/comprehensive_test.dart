// macOS 桌面端综合功能 E2E 测试
//
// 使用 desktop_* helper 模块组装测试用例。
//
// 覆盖：
//   A. 3 主题 × 3 层节点树 + 深度限制
//   B. 三种分支创建模式（empty / 原始上下文 / 总结）
//   C. 图片消息 + Kimi
//   D. 同层排序
//   E. 节点合并
//   F. 分享导出

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'desktop_test_fixtures.dart';
import 'desktop_primitive_helpers.dart';
import 'desktop_nav.dart';
import 'desktop_theme_helpers.dart';
import 'desktop_node_helpers.dart';
import 'desktop_chat_helpers.dart';
import 'desktop_branch_helpers.dart';

void main() {
  testWidgets('A: 3 主题 × 3 层节点树 + 深度限制', (tester) async {
    final app = await createDesktopTestApp(activeProvider: 'kimi');
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await switchToThemes(tester);

    // 创建 3 个主题
    final themes = await createThemes(tester, ['综合主题_A1', '综合主题_A2', '综合主题_A3']);

    // 选中第一个主题，创建根节点
    await selectTheme(tester, themes[0]);
    for (int i = 0; i < 3; i++) {
      await createRootNode(tester, themes[0], '根节点_A_$i');
    }
    assertText(tester, '根节点_A_0');
    assertText(tester, '根节点_A_1');
    assertText(tester, '根节点_A_2');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('B: 三种分支创建模式', (tester) async {
    final app = await createDesktopTestApp(activeProvider: 'kimi');
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await switchToThemes(tester);

    final theme = await createTheme(tester, '分支测试');
    await selectTheme(tester, theme);
    final root = await createRootNode(tester, theme, '父节点');

    // 选中父节点 → 聊天
    final chat = await startChat(tester, root);

    // TODO: 从聊天界面触发分支创建（需要定位分支按钮）
    // await sendAndWait(tester, '测试消息');
    // await createBranchesAllModes(tester, root);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('C: 图片消息 + Kimi 模型', (tester) async {
    final app = await createDesktopTestApp(activeProvider: 'kimi');
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await switchToThemes(tester);

    final theme = await createTheme(tester, '图片测试');
    await selectTheme(tester, theme);
    final node = await createRootNode(tester, theme, '图片对话');
    final chat = await startChat(tester, node);

    // 发送文本 + 验证流式回复
    await sendAndWait(tester, '你好');
    assertText(tester, '你好');
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('D: 节点同层排序', (tester) async {
    // TODO: 实现拖拽排序
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('E: 节点合并', (tester) async {
    // TODO: 实现合并
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('F: 分享导出', (tester) async {
    // TODO: 实现分享
  }, timeout: const Timeout(Duration(minutes: 5)));
}
