# 集成测试 · 节点拖拽重排序

> **创建**：2026-06-18
> **最近更新**：2026-06-18
> **维护者**：AI + 用户审阅
> **状态**：✅ ValueKey 已存在 + 3 个 testWidgets 仍为伪完成（硬编码 nodeId），核心 TODO 是"获取真实 nodeId + 拼 drag_handle Key"
> **相关 spec**：[README.md](./README.md) · [theme-chat-e2e.md](./theme-chat-e2e.md) · [helpers.md](./helpers.md)

---

## 1. 目标

验证**主题详情页节点拖拽重排序** 的完整链路：从 `LongPressDraggable` 长按 → `DragTarget` 接受/拒绝 → `nodeStore.reorderNode` 持久化 sortOrder → `refreshNodesOnly()` 局部刷新。

覆盖 3 个核心场景：

| 场景 | 拖拽方向 | 期望行为 |
|------|---------|---------|
| 同层节点拖拽重排序 | 同 parentId | 顺序立即改变 + 持久化 |
| 跨层拖拽应被禁止 | 跨 parentId | DragTarget 拒绝，顺序不变 |
| 拖拽后刷新保持顺序 | 同 parentId | refresh 后顺序与拖拽后一致 |

---

## 2. 测试现状

`integration_test/node_reorder_test.dart`（154 行）有 3 个 testWidgets：

| # | testWidgets | 前置步骤 | 核心 TODO | LLM 依赖 |
|---|------------|---------|----------|---------|
| 1 | `同层节点拖拽重排序` | ❌ 空壳（`createTestApp` 后没建节点） | ❌ 拼 drag_handle Key + 真实拖拽 | ❌ |
| 2 | `跨层拖拽应被禁止` | ❌ 空壳 | ❌ 跨层节点 + 拖拽验证 | ❌ |
| 3 | `拖拽后刷新保持顺序` | ❌ 空壳 | ❌ 拖拽 + refresh + 顺序校验 | ❌ |

**伪完成原因**：

```dart
// line 11-15（测试 1 的样板）
final app = await createTestApp();
await tester.pumpWidget(app);
await tester.pumpAndSettle();
// ⚠️ 后面就直接 find.byKey(ValueKey('drag_handle_node1'))
//    但代码里 Key 是 ValueKey('drag_handle_${actualNodeId}')
//    node1 / node2 / parent / child 都是硬编码占位符
```

3 个测试共有的硬编码占位 Key：

| 测试 | 硬编码 Key | 代码里实际 Key |
|------|-----------|---------------|
| 1 | `drag_handle_node1` / `drag_handle_node2` | `drag_handle_${真实nodeId}` |
| 2 | `drag_handle_parent` / `drag_handle_child` | `drag_handle_${真实nodeId}` |
| 3 | `drag_handle_node1` / `drag_handle_node2` | `drag_handle_${真实nodeId}` |

> **关键发现**：和 [branch-creation.md](./branch-creation.md) 的情况**完全相反**——branch 流程的 ValueKey **基本全缺失**，而 node-reorder 的 ValueKey **几乎全存在**（`node_list` / `drag_handle_${nodeId}` / `refresh_button` / `add_node_button` / `node_title_input` / `node_create_button`）。node-reorder 的主要工作是**通过 Riverpod 拿到真实 nodeId**，而不是补 Key。

---

## 3. 底层实现剖析

### 3.1 拖拽架构（两层结构）

```
┌──────────────────────────────────────────────────────────────────┐
│ UI 层（theme_detail_screen.dart _TreeRowView + _DragHandle）       │
├──────────────────────────────────────────────────────────────────┤
│ ① 每个 row 是 DragTarget<NodeEntity>（line 293）                  │
│    onWillAcceptWithDetails:                                      │
│      details.data.parentId == node.parentId &&                   │
│      details.data.nodeId != node.nodeId                          │
│                                                                  │
│ ② 行内右侧 _DragHandle 是 LongPressDraggable<NodeEntity>         │
│    delay: 400ms（HapticFeedback.mediumImpact onDragStarted）      │
│                                                                  │
│ ③ 用户长按 400ms → 进入 drag 态 → 拖到另一个 row 上             │
│    → DragTarget.onAcceptWithDetails 触发                         │
│    → _handleReorder() 重排兄弟节点的 sortOrder                   │
│    → refreshNodesOnly() 局部刷新                                 │
└──────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│ 数据层（NodeStore + themeDetailControllerProvider）               │
├──────────────────────────────────────────────────────────────────┤
│ • nodeStore.reorderNode(nodeId, newSortOrder)                    │
│ • themeDetailController.refreshNodesOnly()                       │
│   （仅刷新 nodes，跳过 disk reindex + session preview）           │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 DragTarget 接受/拒绝决策表（关键）

| 拖源节点 parentId | 目标节点 parentId | 同一节点？ | 是否接受 | 视觉效果 |
|------------------|------------------|----------|---------|---------|
| null（根） | null（根） | ❌ | ✅ | 蓝色指示线（顶/底）+ 背景高亮 |
| null（根） | null（根） | ✅ | ❌（拖到自己） | 无 |
| null（根） | "n_child"（子） | — | ❌（跨层） | 无 |
| "n_child"（子） | null（根） | — | ❌（跨层） | 无 |
| "n_child"（子） | "n_child"（子） | ❌ | ✅ | 同上 |
| "n_child"（子） | "n_child"（子） | ✅ | ❌ | 无 |

**关键发现**（`theme_detail_screen.dart:294-296`）：

```dart
onWillAcceptWithDetails: (details) =>
    details.data.parentId == node.parentId &&   // 同层
    details.data.nodeId != node.nodeId,         // 不是自己
```

跨层拖拽时 `parentId` 不等 → `onWillAcceptWithDetails` 返回 false → `onAcceptWithDetails` 不触发 → 顺序不变。

### 3.3 `_handleReorder` 重排算法（line 553-599）

```dart
Future<void> _handleReorder(WidgetRef ref, {
  required NodeEntity draggedNode,
  required NodeEntity targetNode,
  required List<NodeEntity> allNodes,
}) async {
  final nodeStore = await ref.read(nodeStoreProvider.future);
  final parentId = targetNode.parentId;

  // 1. 取同 parent 的所有兄弟
  final siblings = allNodes
      .where((n) => n.parentId == parentId)
      .toList()
    ..sort(_compareNodes);

  // 2. 判断拖拽方向
  final draggedIdx = siblings.indexWhere((n) => n.nodeId == draggedNode.nodeId);
  final targetOriginalIdx = siblings.indexWhere((n) => n.nodeId == targetNode.nodeId);
  final draggingDown = draggedIdx < targetOriginalIdx;

  // 3. 从兄弟列表移除 dragged，插入到 target 附近
  siblings.removeWhere((n) => n.nodeId == draggedNode.nodeId);
  siblings.insert(draggingDown ? targetIdx + 1 : targetIdx, draggedNode);

  // 4. 全部重新赋值 sortOrder（nowMs + 索引）
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (int i = 0; i < siblings.length; i++) {
    await nodeStore.reorderNode(
      nodeId: siblings[i].nodeId,
      newSortOrder: now + i,
    );
  }
}
```

**关键细节**：

- `draggingDown = draggedIdx < targetOriginalIdx`：如果从前往后拖（dragged 在前），目标是"放到 target 之后"；从后往前拖则"放到 target 之前"
- sortOrder 用 `nowMs + i`（时间戳基数 + 索引），**保证全部新值都大于历史值**，避免回退
- `reorderNode` 是逐个 update 的 SQL（line 354-365），不是事务（**潜在 race condition 风险，但单机无问题**）

### 3.4 `LongPressDraggable.delay = 400ms`

`theme_detail_screen.dart:453`：

```dart
LongPressDraggable<NodeEntity>(
  key: ValueKey('drag_handle_${widget.node.nodeId}'),
  data: widget.node,
  delay: const Duration(milliseconds: 400),  // ⚠️ 长按 400ms 才进入拖拽
  ...
)
```

`test_helpers.dart:117` 的 `longPressAndWait` 默认 `waitDuration: 500ms`：

```dart
Future<void> longPressAndWait(
  WidgetTester tester,
  Finder finder, {
  Duration waitDuration = const Duration(milliseconds: 500),
}) async {
  await tester.longPress(finder);
  await tester.pump(waitDuration);
}
```

⚠️ **隐患**：500ms 看似"刚好够"，但 `tester.longPress` 本身只触发 `onLongPressStart`，不会等 delay 结束。建议**显式 pump(500ms) 后再 drag**，或重写 helper 加 `longPressDuration` 参数。

### 3.5 已存在的 ValueKey 清单 ✅

| Key | 位置 | 用途 |
|-----|------|------|
| `node_list` | theme_detail_screen.dart:102 | 节点列表 ListView |
| `refresh_button` | theme_detail_screen.dart:71 | 顶部刷新按钮 |
| `add_node_button` | theme_detail_screen.dart:80 | 顶部 + 创建节点 |
| `drag_handle_${nodeId}` | theme_detail_screen.dart:451 | 拖拽把手（动态拼接） |
| `node_title_input` | theme_detail_screen.dart:850 | 创建节点 dialog 输入框 |
| `node_create_button` | theme_detail_screen.dart:869 | 创建节点 dialog 确认按钮 |
| `add_theme_button` | theme_list_screen.dart（外部） | 主题列表 + 按钮 |
| `theme_title_input` | theme_list_screen.dart（外部） | 主题创建 dialog |
| `theme_create_button` | theme_list_screen.dart（外部） | 主题创建 dialog 确认 |

> **0 个缺失 Key** —— node-reorder 是少数 ValueKey 已就绪的 spec。

---

## 4. 编写前置依赖（必做项清单）

### 4.1 提取 `_createTheme` / `_createNode` 到 `_support/`

`theme_chat_e2e_test.dart:172-207` 的 `_createTheme` / `_createNode` 是带 ValueKey 的完整实现：

```dart
// theme_chat_e2e_test.dart:172-188 (_createTheme 完整版)
Future<void> _createTheme(WidgetTester tester, String title) async {
  final addBtn = find.byKey(const ValueKey('add_theme_button'));
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  final titleInput = find.byKey(const ValueKey('theme_title_input'));
  await tester.enterText(titleInput, title);
  await tester.pump();

  final createBtn = find.byKey(const ValueKey('theme_create_button'));
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}

// theme_chat_e2e_test.dart:191-207 (_createNode 完整版)
Future<void> _createNode(WidgetTester tester, String title) async {
  final addBtn = find.byKey(const ValueKey('add_node_button'));
  await tester.tap(addBtn);
  await tester.pumpAndSettle();

  final titleInput = find.byKey(const ValueKey('node_title_input'));
  await tester.enterText(titleInput, title);
  await tester.pump();

  final createBtn = find.byKey(const ValueKey('node_create_button'));
  await tester.tap(createBtn);
  await tester.pumpAndSettle();
}
```

`node_reorder_test.dart` 和 `theme_chat_e2e_test.dart` 复制粘贴同一份代码，应提取到 `integration_test/_support/test_fixtures.dart`：

```dart
// 新增 _support/test_fixtures.dart
Future<void> createThemeViaUi(WidgetTester tester, String title) async { ... }
Future<void> createNodeViaUi(WidgetTester tester, String title) async { ... }
```

> **不在本文档任务范围**：用户决策 3（"本次只写文档不动代码"）。

### 4.2 新增 helper：从 controller 读真实 nodeId

node-reorder 的核心难点是 `drag_handle_${nodeId}` 需要真实 ID。需要新增 helper：

```dart
// 新增 test_helpers.dart 或 _support/test_fixtures.dart

/// 从 themeDetailControllerProvider 读出按 sortOrder 排序的节点列表。
///
/// 返回 List<NodeEntity>，调用方可按索引取"第 N 个节点"。
Future<List<NodeEntity>> readNodesInOrder(
  WidgetTester tester,
  String themeId,
) async {
  final element = tester.element(find.byKey(const ValueKey('node_list')));
  final container = ProviderScope.containerOf(element);
  final state = await container.read(themeDetailControllerProvider(themeId).future);
  return state.nodes..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

/// 拼出 drag_handle_${nodeId} 的 ValueKey。
Key dragHandleKey(String nodeId) => ValueKey('drag_handle_$nodeId');
```

> **不在本文档任务范围**：用户决策 3。文档里给出代码，**实际 helper 提取留待后续**。

### 4.3 修改 `longPressAndWait` 支持 400ms delay

由于 `LongPressDraggable.delay = 400ms`，建议重写 helper：

```dart
// test_helpers.dart:117 替换为
Future<void> longPressAndWait(
  WidgetTester tester,
  Finder finder, {
  Duration waitDuration = const Duration(milliseconds: 500),
}) async {
  await tester.longPress(finder);
  // LongPressDraggable.delay 默认 400ms，waitDuration 必须 ≥ delay 才能进入拖拽态
  await tester.pump(waitDuration);
}
```

当前 helper 默认 500ms 已经够用，**但应当把这个 magic number 用注释固化**（防止未来 delay 改了没人知道）。

---

## 5. 编写路线（3 个 testWidgets 完整代码）

> **前提**：完成 § 4.1 helper 提取 + § 4.2 readNodesInOrder + § 4.3 longPressAndWait 注释。

### 5.1 同层节点拖拽重排序

```dart
testWidgets('同层节点拖拽重排序', (tester) async {
  // 不需要 LLM
  final app = await createTestApp();
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  // 1. 导航到主题列表 → 创建主题
  await _switchToTab(tester, '主题');  // theme_chat_e2e_test.dart:163 的私有 helper
  await createThemeViaUi(tester, 'Reorder Test ${DateTime.now().millisecondsSinceEpoch}');
  await tester.pumpAndSettle();

  // 2. 进入主题详情
  final themeTitleFinder = find.text(/* 上一步创建的主题标题 */);
  await tester.tap(themeTitleFinder.first);
  await tester.pumpAndSettle();

  // 3. 创建 2 个根节点
  await createNodeViaUi(tester, 'Node-A');
  await createNodeViaUi(tester, 'Node-B');
  await tester.pumpAndSettle();

  // 4. 拿到真实 nodeId（按 sortOrder 升序）
  final themeId = /* 从 controller 拿，或从 URL 解析 */;
  final nodes = await readNodesInOrder(tester, themeId);
  expect(nodes.length, 2);
  final firstNode = nodes[0];   // Node-A
  final secondNode = nodes[1];  // Node-B

  // 5. 长按第 2 个节点的拖拽把手
  final secondHandle = find.byKey(dragHandleKey(secondNode.nodeId));
  expect(secondHandle, findsOneWidget);
  await longPressAndWait(tester, secondHandle);

  // 6. 拖拽到第 1 个节点位置
  final start = tester.getCenter(secondHandle);
  final end = tester.getCenter(find.byKey(dragHandleKey(firstNode.nodeId)));
  await dragFromTo(tester, start, end);
  await tester.pumpAndSettle();

  // 7. 验证：顺序反转（Node-B 现在在前）
  final nodesAfter = await readNodesInOrder(tester, themeId);
  expect(nodesAfter[0].title, 'Node-B');
  expect(nodesAfter[1].title, 'Node-A');

  // 8. 点击 refresh，顺序保持
  await refreshNodeList(tester);
  await tester.pumpAndSettle();
  final nodesAfterRefresh = await readNodesInOrder(tester, themeId);
  expect(nodesAfterRefresh[0].title, 'Node-B');
  expect(nodesAfterRefresh[1].title, 'Node-A');
});
```

### 5.2 跨层拖拽应被禁止

```dart
testWidgets('跨层拖拽应被禁止', (tester) async {
  // ... 同样的前置到主题详情 ...
  await createNodeViaUi(tester, 'Parent Node');
  await createNodeViaUi(tester, 'Child Node');

  // ⚠️ 创建 child node 需要先 tap parent 进入 chat（chat_screen 的 swipe right / add 按钮？）
  // 实际路径：tap parent → 进入 chat → 通过某个按钮创建子节点
  // 简化路线：手动调 themeDetailControllerProvider.createChildChatNode（不依赖 UI）
  final themeId = /* ... */;
  final element = tester.element(find.byKey(const ValueKey('node_list')));
  final container = ProviderScope.containerOf(element);
  await container.read(themeDetailControllerProvider(themeId).notifier)
      .createChildChatNode(parentId: parentNodeId, title: 'Child Node');
  await tester.pumpAndSettle();

  final nodes = await readNodesInOrder(tester, themeId);
  final parentNode = nodes.firstWhere((n) => n.parentId == null);
  final childNode = nodes.firstWhere((n) => n.parentId == parentNode.nodeId);

  // 记录初始顺序
  final beforeNodes = await readNodesInOrder(tester, themeId);

  // 尝试把 child 拖到 parent 位置（跨层）
  final childHandle = find.byKey(dragHandleKey(childNode.nodeId));
  await longPressAndWait(tester, childHandle);

  final start = tester.getCenter(childHandle);
  final end = tester.getCenter(find.byKey(dragHandleKey(parentNode.nodeId)));
  await dragFromTo(tester, start, end);
  await tester.pumpAndSettle();

  // 验证：顺序不变（DragTarget.onWillAcceptWithDetails 返回 false → onAccept 不触发）
  final afterNodes = await readNodesInOrder(tester, themeId);
  expect(afterNodes.map((n) => n.nodeId).toList(),
         beforeNodes.map((n) => n.nodeId).toList(),
         reason: '跨层拖拽应被 DragTarget 拒绝，顺序不变');
});
```

**辅助断言**：可加 `find.byKey(dragHandleKey(childNode.nodeId))` 仍存在 + 节点列表里 child 仍在 parent 后面（不是前面）来双重验证。

### 5.3 拖拽后刷新保持顺序

```dart
testWidgets('拖拽后刷新保持顺序', (tester) async {
  // ... 前置同 5.1 ...
  final themeId = /* ... */;
  await createNodeViaUi(tester, 'Node-1');
  await createNodeViaUi(tester, 'Node-2');
  await tester.pumpAndSettle();

  final nodes = await readNodesInOrder(tester, themeId);
  final firstNode = nodes[0];
  final secondNode = nodes[1];

  // 拖拽第 2 个到第 1 个位置
  final secondHandle = find.byKey(dragHandleKey(secondNode.nodeId));
  await longPressAndWait(tester, secondHandle);
  final start = tester.getCenter(secondHandle);
  final end = tester.getCenter(find.byKey(dragHandleKey(firstNode.nodeId)));
  await dragFromTo(tester, start, end);
  await tester.pumpAndSettle();

  // 验证：拖拽后顺序
  final afterDrag = await readNodesInOrder(tester, themeId);
  expect(afterDrag[0].title, 'Node-2');

  // 点击 refresh 按钮
  await refreshNodeList(tester);
  await tester.pumpAndSettle();

  // 验证：刷新后顺序保持
  final afterRefresh = await readNodesInOrder(tester, themeId);
  expect(afterRefresh[0].title, 'Node-2');
  expect(afterRefresh[1].title, 'Node-1');

  // 进一步验证：sortOrder 单调递增（nowMs + 索引）
  expect(afterRefresh[0].sortOrder < afterRefresh[1].sortOrder, isTrue);
});
```

---

## 6. 依赖的 helpers 与 fixtures

| 依赖 | 来源 | 用途 |
|------|------|------|
| `createTestApp()` | `lib/main_test.dart` | 启动 App（无 LLM 注入即可） |
| `_switchToTab` | theme_chat_e2e_test.dart（**需提取**） | 切到底部 "主题" tab |
| `createThemeViaUi` / `createNodeViaUi` | **⚠️ 需提取到 `_support/`** | UI 创建主题 / 节点 |
| `longPressAndWait` | `test_helpers.dart:117` | 长按拖拽把手（注意 400ms delay） |
| `dragFromTo` | `test_helpers.dart:129` | 拖拽手势 |
| `getCenter(finder)` | Flutter Test 内置 | 取 widget 中心坐标 |
| `refreshNodeList` | `test_helpers.dart:300` | 点 refresh_button |
| `pumpAndSettleWithTimeout` | `test_helpers.dart:12` | 长操作等待 |
| `readNodesInOrder` / `dragHandleKey` | **⚠️ 需新增** | 从 controller 读 nodeId + 拼 Key |

---

## 7. 阻塞点汇总

按依赖顺序：

1. **🟡 `_createTheme` / `_createNode` 重复**（§ 4.1）—— `theme_chat_e2e` 和 `node_reorder` 复制粘贴，未提取到 `_support/`
2. **🟡 `_switchToTab` 重复** —— `theme_chat_e2e` line 163 的私有 helper，`node_reorder` 也需要
3. **🟡 `readNodesInOrder` / `dragHandleKey` 缺失**（§ 4.2）—— node-reorder **核心依赖**，没有它就只能硬编码 nodeId
4. **🟢 `longPressAndWait` magic number 500ms**（§ 4.3）—— 现有值刚好够 400ms delay，但应该注释
5. **🟢 创建子节点的 UI 入口** —— 主题详情页没有明显"创建子节点"按钮，**只能走 chat_screen 或直接调 controller**

> **与 [branch-creation.md](./branch-creation.md) 对比**：branch-creation 有 10 个 ValueKey 缺失 + 多个 helper 缺失；node-reorder 只有 3 个 helper 缺失 + 0 个 ValueKey 缺失。**node-reorder 实施成本显著更低**。

---

## 8. 风险与边界

### 不在本文档范围

- ❌ **不实现**任何 node_reorder_test.dart 的 TODO
- ❌ **不重构** `_support/` 或 `test_helpers.dart`（用户决策 3）
- ❌ **不修改** `LongPressDraggable.delay`（属于 UI 行为改动）

### 已知风险

- **`LongPressDraggable.delay = 400ms` 时序**：`longPressAndWait` 默认 500ms 看似够，但 `tester.longPress` 触发的是 `onLongPressStart`，delay 计时在 `LongPressDraggable` 内部，**没有显式等待 drag state 进入**。建议加 `await tester.pump(Duration(milliseconds: 400))` 显式同步
- **`DragTarget.onWillAcceptWithDetails` 不可观察**：Flutter 没有 expose "接受/拒绝"的事件，只能通过"顺序变/不变"间接验证。**测试 2 的断言只能用"顺序不变"**
- **同一节点拖自己**：`onWillAcceptWithDetails` 返回 false（同 nodeId），但**视觉上**看不出区别——只能通过"顺序不变"间接验证
- **跨层拖拽的视觉效果**：`isHovering = candidateData.isNotEmpty`（line 317）跨层时为 false，**没有蓝色指示线**，测试可以验证"无 hover 样式"
- **`refreshNodesOnly` 跳过 disk reindex**（line 95-109）：如果拖拽后立即退出主题详情再回来，会触发完整 `_load` → `reindexNodesFromDisk` → **保留 sortOrder**（line 71-82 的 "Preserve existing sortOrder" 逻辑），所以"刷新保持顺序"实际有 2 层保障
- **创建子节点的 UI 路径**：测试 2 需要 parent + child 节点结构。**当前 UI 没有"创建子节点"入口**（chat_screen 里有"分支"按钮可创建 child），所以最简路线是直接调 `controller.createChildChatNode` 而不走 UI
- **多个子节点的子节点**（grandchild）：当前拖拽实现不支持跨层，grandchild 测试不在本文档范围

### 测试矩阵简表

| 测试 | 节点结构 | 拖拽方向 | 验证方式 | 关键路径 |
|------|---------|---------|---------|---------|
| 1 同层重排序 | 2 个根节点 | Node-B → Node-A 位置 | sortOrder 变化 + 顺序反 + 持久化 | longPress → drag → onAccept → reorderNode × 2 → refresh |
| 2 跨层禁止 | 1 根 + 1 子 | child → parent 位置 | 顺序不变 + 无 hover 样式 | longPress → drag → onWillAccept false → onAccept 不触发 |
| 3 拖拽后刷新 | 2 个根节点 | Node-2 → Node-1 位置 | 拖拽后顺序 + refresh 后顺序 + sortOrder 单调 | 同 1 + refresh_button |

---

## 9. 执行命令

```bash
# 单跑 node_reorder_test（当前 3 个测试都立即失败，但失败点都是 nodeId 不存在）
flutter test integration_test/node_reorder_test.dart -d "<iOS Simulator>"

# 带 driver 跑
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/node_reorder_test.dart \
  -d "<iOS Simulator>"

# 跑整套集成测试（避免遗漏依赖）
flutter test integration_test/ -d "<iOS Simulator>"
```

> **当前结果**：3 个 testWidgets 全部失败，因为 `find.byKey(ValueKey('drag_handle_node1'))` 找不到（实际 Key 是 `drag_handle_xxx`）。**不是"通过"也不是"超时"，是真失败**——比 branch-creation 的伪通过更健康。

---

## 10. 完成状态 Checklist

### 文档编写（本 spec）

- [x] 目标 + 3 个测试矩阵表
- [x] 测试现状（硬编码 nodeId + 0 个 ValueKey 缺失）
- [x] 底层实现剖析（拖拽架构 + DragTarget 决策表 + _handleReorder 算法）
- [x] ValueKey 缺失清单（**0 个缺失**）
- [x] 编写前置依赖（4.1-4.3）
- [x] 3 个 testWidgets 完整代码
- [x] 阻塞点汇总
- [x] 风险与边界
- [x] 测试矩阵简表
- [x] 执行命令

### 代码层面（**不在本文档任务**）

- [ ] 把 `_createTheme` / `_createNode` / `_switchToTab` 提取到 `_support/test_fixtures.dart`
- [ ] 在 `test_helpers.dart` 新增 `readNodesInOrder` / `dragHandleKey` helper
- [ ] 给 `longPressAndWait` 加 400ms delay 注释（或新增 `longPressAndWaitForDrag` helper）
- [ ] 实现 § 5.1-5.3 三个 testWidgets 实际代码
- [ ] 跑通 + 截图验证（特别注意蓝色指示线视觉）

---

## 11. 相关文档

- [README.md](./README.md) — 集成测试总论
- [theme-chat-e2e.md](./theme-chat-e2e.md) — 主题→节点→聊天完整链路（提供 _createTheme / _createNode 范式）
- [branch-creation.md](./branch-creation.md) — 分支创建（同样涉及节点树，但 ValueKey 几乎全缺失，**与本文档形成对照**）
- [chat-streaming.md](./chat-streaming.md) — chat 流式回复测试（chat_input/send_button 的关联 spec）
- [helpers.md](./helpers.md) — `test_helpers.dart` 工具清单（longPressAndWait / dragFromTo / refreshNodeList 等）
- [fixtures.md](./fixtures.md) — `InMemoryLlmConfigStore` / `LlmTestConfig` 详解
- `lib/ui/features/themes/theme_detail_screen.dart:293-379` — `DragTarget` + `_TreeRowView` 实现
- `lib/ui/features/themes/theme_detail_screen.dart:446-512` — `_DragHandle` + `LongPressDraggable` 实现
- `lib/ui/features/themes/theme_detail_screen.dart:553-599` — `_handleReorder` 算法
- `lib/data/stores/node_store.dart:354-365` — `reorderNode(nodeId, newSortOrder)` SQL
- `lib/ui/features/themes/theme_detail_controller.dart:97-109` — `refreshNodesOnly` 局部刷新