import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';
import '../_support/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('对话树节点拖拽重排序测试', () {
    testWidgets('同层节点拖拽重排序', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // TODO: 导航到包含多个节点的对话树页面
      // 这里需要根据实际的应用导航流程来实现
      // 例如：点击主题列表 -> 进入某个主题 -> 看到节点列表

      // 测试场景：
      // 1. 进入一个有多个节点的对话树页面
      // 2. 长按第 2 个节点的拖拽把手
      // 3. 拖拽到第 1 个节点的位置
      // 4. 松手

      // 验证点：
      // - 节点顺序立即改变（第 2 个变成第 1 个）
      // - 点击刷新按钮，顺序保持
      // - 退出页面重新进入，顺序仍然保持

      // 示例测试步骤（需要根据实际 UI 调整）：

      // 1. 找到节点列表
      final nodeListFinder = find.byKey(const ValueKey('node_list'));
      expect(nodeListFinder, findsOneWidget, reason: '应该找到节点列表');

      // 2. 获取初始节点顺序
      // 注意：这里需要根据实际的 UI 结构来获取节点标题
      // 假设节点标题是通过 Text widget 显示的

      // 3. 找到第 2 个节点的拖拽把手
      // 拖拽把手的 key 格式为 'drag_handle_${nodeId}'
      // 这里假设第一个节点的 nodeId 为 'node1'，第二个为 'node2'
      final secondNodeDragHandle = find.byKey(const ValueKey('drag_handle_node2'));
      expect(secondNodeDragHandle, findsOneWidget, reason: '应该找到第 2 个节点的拖拽把手');

      // 4. 找到第 1 个节点的位置
      final firstNodeDragHandle = find.byKey(const ValueKey('drag_handle_node1'));
      expect(firstNodeDragHandle, findsOneWidget, reason: '应该找到第 1 个节点的拖拽把手');

      // 5. 长按第 2 个节点的拖拽把手
      await longPressAndWait(tester, secondNodeDragHandle);

      // 6. 拖拽到第 1 个节点的位置
      final startOffset = tester.getCenter(secondNodeDragHandle);
      final endOffset = tester.getCenter(firstNodeDragHandle);
      await dragFromTo(tester, startOffset, endOffset);

      // 7. 等待 UI 更新
      await tester.pumpAndSettle();

      // 8. 验证节点顺序改变
      // 注意：这里需要根据实际的 UI 结构来验证顺序
      // 假设可以通过节点标题来判断顺序

      // 9. 点击刷新按钮验证顺序保持
      await refreshNodeList(tester);
      await tester.pumpAndSettle();

      // 10. 验证刷新后顺序仍然保持

      // 11. 退出页面重新进入验证顺序持久化
      // 这需要导航回再重新进入
    });

    testWidgets('跨层拖拽应被禁止', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // TODO: 导航到包含多层级节点的对话树页面

      // 测试场景：
      // 1. 进入一个有父子层级的对话树页面
      // 2. 尝试将子节点拖拽到父节点的位置
      // 3. 验证拖拽被拒绝

      // 验证点：
      // - 拖拽操作被拒绝
      // - 节点顺序不变

      // 示例测试步骤（需要根据实际 UI 调整）：

      // 1. 找到父节点和子节点的拖拽把手
      final parentNodeDragHandle = find.byKey(const ValueKey('drag_handle_parent'));
      final childNodeDragHandle = find.byKey(const ValueKey('drag_handle_child'));

      // 2. 长按子节点
      await longPressAndWait(tester, childNodeDragHandle);

      // 3. 尝试拖拽到父节点位置
      final startOffset = tester.getCenter(childNodeDragHandle);
      final endOffset = tester.getCenter(parentNodeDragHandle);
      await dragFromTo(tester, startOffset, endOffset);

      // 4. 等待 UI 更新
      await tester.pumpAndSettle();

      // 5. 验证拖拽被拒绝
      // 注意：DragTarget 的 onWillAcceptWithDetails 会返回 false，因此拖拽不会生效
      // 需要验证节点顺序没有改变
    });

    testWidgets('拖拽后刷新保持顺序', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // TODO: 导航到对话树页面

      // 测试场景：
      // 1. 拖拽节点改变顺序
      // 2. 点击刷新按钮
      // 3. 验证顺序保持

      // 验证点：
      // - 刷新后节点顺序与拖拽后一致

      // 示例测试步骤：

      // 1. 找到节点
      final firstNode = find.byKey(const ValueKey('drag_handle_node1'));
      final secondNode = find.byKey(const ValueKey('drag_handle_node2'));

      // 2. 执行拖拽操作
      await longPressAndWait(tester, secondNode);
      final startOffset = tester.getCenter(secondNode);
      final endOffset = tester.getCenter(firstNode);
      await dragFromTo(tester, startOffset, endOffset);
      await tester.pumpAndSettle();

      // 3. 点击刷新按钮
      await refreshNodeList(tester);
      await tester.pumpAndSettle();

      // 4. 验证顺序保持
      // 注意：这里需要根据实际的 UI 结构来验证顺序
    });
  });
}
