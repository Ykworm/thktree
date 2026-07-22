// macOS 桌面端集成测试 — 分支创建 Helper
// desktop_branch_helpers.dart
//
// 依赖：desktop_primitive_helpers.dart, desktop_test_fixtures.dart (NodeCtx)

import 'package:flutter_test/flutter_test.dart';
import 'desktop_primitive_helpers.dart';
import 'desktop_test_fixtures.dart' show NodeCtx;

/// 分支创建模式
enum BranchMode { empty, originalContext, summary }

/// 按指定模式创建分支
///
/// 桌面端分支创建流程：
/// 1. 右键/长按节点 → 弹出操作菜单 → 选择"分支"
/// 2. 或选中节点后点 swipe gesture → 分支选项
/// 3. 弹出分支模式选择 sheet（empty / 原文 / 总结）
///
/// 简化实现：选中父节点 → 在聊天中点击分支按钮 → 选模式
Future<NodeCtx?> createBranch(WidgetTester tester, NodeCtx parent, BranchMode mode) async {
  // TODO: 实现具体分支创建 UI 流程
  // 1. 选中父节点
  // 2. 触发分支创建入口（桌面端走 GestureDetector）
  // 3. 在 TitleSuggestionScreen 中选择对应模式
  // 4. 等待节点创建完成
  return null;
}

/// 创建所有三种模式的分支
Future<List<NodeCtx>> createBranchesAllModes(WidgetTester tester, NodeCtx parent) async {
  final results = <NodeCtx>[];
  for (final mode in BranchMode.values) {
    final branch = await createBranch(tester, parent, mode);
    if (branch != null) {
      parent.children.add(branch);
      results.add(branch);
    }
  }
  return results;
}

// ── 节点合并 Helper ──

/// 合并节点：[source] 挂到 [target] 下（或作为 root，target=null）
Future<void> mergeNode(WidgetTester tester, NodeCtx source, {NodeCtx? target}) async {
  // TODO: 实现合并 UI 流程
  // 1. 长按 source 节点 → DragTarget
  // 2. 拖到 target 节点上（或拖到"作为 root"的 DropTarget）
  // 3. 确认合并
}

// ── 节点排序 Helper ──

/// 同层节点重排
Future<void> reorderNodes(WidgetTester tester, List<NodeCtx> nodes, List<int> newOrder) async {
  // TODO: 实现拖拽排序
  // 1. 进入排序模式（长按拖动）
  // 2. 按 newOrder 依次拖拽
  // 3. 验证最终顺序
}

// ── 分享导出 Helper ──

/// 分享对话为图片
Future<void> shareAsImage(WidgetTester tester, NodeCtx node) async {
  // TODO: 实现分享流程
  // 1. 进入 node 的聊天
  // 2. 触发分享按钮（桌面端可能是右键或工具栏按钮）
  // 3. 选择"分享为图片"
  // 4. 验证保存路径
}
