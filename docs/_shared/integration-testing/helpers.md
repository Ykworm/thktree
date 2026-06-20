# 集成测试 Helpers 工具函数清单

> **适用对象**：要在集成测试里做 UI 操作 / 等待 / 断言的开发者  
> **核心问题**：测试代码应该怎么写才不会和真实 UI 时序 race？

---

## 1. 工具函数总览

[`integration_test/test_helpers.dart`](../../../integration_test/test_helpers.dart) 共 18 个工具函数，按用途分为 5 类：

| 分类 | 工具数 | 主要作用 |
|------|--------|----------|
| 等待 / pump | 5 | 等待 UI 稳定、LLM 流式结束、特定文本/widget 出现 |
| UI 操作 | 4 | 安全点击、文本输入、长按、拖拽 |
| 断言辅助 | 2 | 收集所有 Text 内容、检查文本包含 |
| 业务快捷方法 | 6 | 创建节点、导航、发消息、停止流式、刷新、收集节点标题 |
| 空实现（⚠️ 待补） | 2 | `getNodeTitles()` / `verifyNodeOrder()` |

---

## 2. 等待 / pump 类

### 2.1 `pumpAndSettleWithTimeout`

```dart
Future<void> pumpAndSettleWithTimeout(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 30),
  Duration duration = const Duration(milliseconds: 100),
})
```

**作用**：带超时的 `pumpAndSettle`，等待所有动画 + 微任务完成。

**默认超时**：30 秒（足够覆盖大部分 UI 流转，**不**够 LLM 流式）。

**使用约定**：
- ✅ 永远用这个，**不要**直接调 `tester.pumpAndSettle()`（没有超时保护）
- ✅ 涉及 LLM 流式时手动调高：`pumpAndSettleWithTimeout(tester, timeout: Duration(seconds: 90))`

### 2.2 `waitForLLMResponse`

```dart
Future<void> waitForLLMResponse(
  WidgetTester tester, {
  required bool Function() checkStreaming,
  Duration timeout = const Duration(seconds: 30),
  Duration pollInterval = const Duration(milliseconds: 500),
})
```

**作用**：等待 LLM 流式响应结束（`checkStreaming` 返回 false）。

**参数**：
- `checkStreaming`：回调函数，返回当前是否还在流式（通常是读 `chatController.isStreaming`）
- `timeout`：默认 30s，**真 API 建议 90s**
- `pollInterval`：轮询间隔，默认 500ms

**使用场景**：发送消息后等待 assistant 回复完整。

### 2.3 `waitForText`

```dart
Future<void> waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 30),
  Duration pollInterval = const Duration(milliseconds: 500),
})
```

**作用**：持续 pump 直到 `find.text(text)` 非空或超时。

**使用场景**：等待异步操作产生的文本出现（如创建主题后等待列表里出现新主题）。

### 2.4 `waitForWidget`

```dart
Future<void> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  Duration pollInterval = const Duration(milliseconds: 500),
})
```

**作用**：持续 pump 直到 `finder` 非空或超时。

**使用场景**：等待按钮状态变化（`send_button` → `stop_button` → `send_button`）。

### 2.5 `waitForLoadingToComplete`

```dart
Future<void> waitForLoadingToComplete(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 30),
})
```

**作用**：等待 `CupertinoActivityIndicator` 消失。

**使用场景**：页面切换后等待 loading 状态消失。

---

## 3. UI 操作类

### 3.1 `safeTap`

```dart
Future<void> safeTap(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
})
```

**作用**：安全点击（可滚动到可见区域再点）。

**参数**：
- `finder`：要点的 widget
- `scrollable`：可选，指定滚动容器；提供后会先滚动到可见

**使用场景**：长列表里点击某个 item（先确保在屏幕里再点）。

### 3.2 `enterTextAndWait`

```dart
Future<void> enterTextAndWait(
  WidgetTester tester,
  Finder finder,
  String text, {
  Duration waitDuration = const Duration(milliseconds: 500),
})
```

**作用**：输入文本 + 等待 UI 更新。

**使用场景**：往输入框里写内容，比手动 `enterText` + `pump(500ms)` 简洁。

### 3.3 `longPressAndWait`

```dart
Future<void> longPressAndWait(
  WidgetTester tester,
  Finder finder, {
  Duration waitDuration = const Duration(milliseconds: 500),
})
```

**作用**：长按 + 等待 UI 更新。

**使用场景**：长按消息弹出 ActionSheet、长按节点拖拽。

### 3.4 `dragFromTo`

```dart
Future<void> dragFromTo(
  WidgetTester tester,
  Offset start,
  Offset end, {
  Duration duration = const Duration(milliseconds: 500),
})
```

**作用**：从 `start` 坐标拖拽到 `end` 坐标。

**使用场景**：拖拽重排序节点（先用 `getCenter` 拿坐标）。

⚠️ **当前实现是简化版**（startGesture + moveBy + up），复杂的 `DragTarget.onWillAcceptWithDetails` 可能识别不到。如遇问题改用：

```dart
final gesture = await tester.startGesture(start);
await gesture.moveBy(Offset(0, 10));   // 先微移触发 drag start
for (var i = 1; i <= 10; i++) {
  await gesture.moveBy((end - start) * (i / 10));
  await tester.pump(Duration(milliseconds: 50));
}
await gesture.up();
```

---

## 4. 断言辅助类

### 4.1 `getAllTexts`

```dart
List<String> getAllTexts(Finder finder)
```

**作用**：收集 finder 匹配的所有 Text widget 的内容。

**使用场景**：验证列表内容（如节点树所有节点标题）。

### 4.2 `containsText`

```dart
bool containsText(String searchText)
```

**作用**：检查所有 Text widget 是否包含 `searchText`（忽略大小写）。

**使用场景**：验证长文本片段存在（如 LLM 回复含特定关键词）。

⚠️ **慎用**——这是全文搜索，**会**匹配到不相关的 Text（如按钮 label、菜单项）。

---

## 5. 业务快捷方法

### 5.1 `createTestNode`

```dart
Future<void> createTestNode(
  WidgetTester tester, {
  required String title,
})
```

**作用**：点击 `add_button` → 输入 `title` → 点击 `confirm_button`，创建新节点。

**依赖 ValueKey**：`add_button` / `title_input` / `confirm_button`。

⚠️ **当前实现的 Key 是泛化的**，不同页面的对话框 Key 可能不同（如 `theme_title_input` vs `node_title_input`），用这个 helper 前先确认 Key 是否匹配。

### 5.2 `navigateToChat`

```dart
Future<void> navigateToChat(
  WidgetTester tester, {
  required String themeId,
  required String nodeId,
})
```

**作用**：从主题列表 → 主题详情 → 节点 → 进入聊天页。

**当前实现**：`find.text(themeId)` + `find.text(nodeId)`，**不依赖 ValueKey**。

⚠️ **如果 themeId/nodeId 是中文**，会因 `enterText` 输入后 UI 渲染延迟导致匹配失败——建议改成 ValueKey 定位。

### 5.3 `navigateToTheme`

```dart
Future<void> navigateToTheme(
  WidgetTester tester, {
  required String themeName,
})
```

**作用**：从主页面点击主题项进入主题列表。

### 5.4 `sendMessage`

```dart
Future<void> sendMessage(
  WidgetTester tester, {
  required String message,
})
```

**作用**：在聊天输入框输入 + 点击发送按钮。

**依赖 ValueKey**：`chat_input` / `send_button`。

### 5.5 `stopStreaming`

```dart
Future<void> stopStreaming(WidgetTester tester)
```

**作用**：点击 `stop_button` 停止流式。

**依赖 ValueKey**：`stop_button`。

### 5.6 `refreshNodeList`

```dart
Future<void> refreshNodeList(WidgetTester tester)
```

**作用**：点击 `refresh_button` 刷新节点列表。

**依赖 ValueKey**：`refresh_button`。

---

## 6. 空实现（⚠️ 待补）

### 6.1 `getNodeTitles`

```dart
List<String> getNodeTitles() {
  // 这里需要根据实际的 UI 结构来实现
  // 返回一个示例实现
  return [];
}
```

**当前状态**：返回空数组。

**什么时候必须补**：`node_reorder_test.dart` 要验证节点顺序时。

**补全思路**：

```dart
List<String> getNodeTitles() {
  final finder = find.byKey(const ValueKey('node_list'));
  if (finder.evaluate().isEmpty) return [];
  
  final titles = <String>[];
  for (final element in finder.evaluate()) {
    // 遍历 _TreeRowView，提取 title Text
    final titleFinder = find.descendant(
      of: element,
      matching: find.byType(Text),
    );
    titles.addAll(getAllTexts(titleFinder));
  }
  return titles;
}
```

### 6.2 `verifyNodeOrder`

```dart
bool verifyNodeOrder(List<String> expectedOrder) {
  // 这里需要根据实际的 UI 结构来实现
  // 返回一个示例实现
  return true;
}
```

**当前状态**：永远返回 `true`（**测试用这函数会假阳性**！）。

**什么时候必须补**：所有要验证节点顺序的测试。

**补全思路**：

```dart
bool verifyNodeOrder(List<String> expectedOrder) {
  final actualOrder = getNodeTitles();
  if (actualOrder.length != expectedOrder.length) return false;
  for (var i = 0; i < expectedOrder.length; i++) {
    if (actualOrder[i] != expectedOrder[i]) return false;
  }
  return true;
}
```

---

## 7. 使用约定

### 7.1 必须遵守

- ✅ 永远用 `pumpAndSettleWithTimeout`，**不要**直接调 `tester.pumpAndSettle()`
- ✅ 涉及 LLM 流式时手动调高超时（90s+）
- ✅ 优先 `find.byKey(ValueKey('xxx'))` 定位，**不要**靠 `find.text`（文本易变）
- ✅ 写操作后必须 `await tester.pump()` 或 `await pumpAndSettleWithTimeout` 等待 UI 更新
- ✅ 拖拽操作后用 `waitForWidget` 验证状态变化

### 7.2 禁止使用

- ❌ `tester.pumpAndSettle()` 直接调用（无超时保护）
- ❌ `find.byType(CupertinoTextField)` 在多输入框场景（不确定选哪个）
- ❌ `find.text(...)` 定位交互按钮（按钮文案可能改）
- ❌ `await Future.delayed(Duration(seconds: 5))`（硬等待，浪费测试时间）

### 7.3 命名约定

| 操作类型 | 命名后缀 | 示例 |
|----------|----------|------|
| 输入并等待 | `AndWait` | `enterTextAndWait` |
| 长按并等待 | `AndWait` | `longPressAndWait` |
| 等待 | `waitFor` | `waitForText`、`waitForWidget` |
| 业务快捷方法 | 动词 | `sendMessage`、`stopStreaming` |

---

## 8. 已知问题和待优化

### 8.1 `dragFromTo` 简化版问题

当前实现可能不触发 `DragTarget` 的 `onWillAcceptWithDetails`，特别是跨层拖拽场景。详见 [node-reorder.md § 4.2](./node-reorder.md)。

### 8.2 `navigateToChat` / `navigateToTheme` 用 text 定位

中文场景下不可靠（输入延迟）。建议改成 ValueKey 定位。

### 8.3 业务方法分散

`createTestNode` / `_createTheme` / `_createNode` 分散在多个 test 文件，建议提到 `_support/` 统一管理。详见 [docs/_tmp/integration-test-docs-plan.md § 决策 3](../_tmp/integration-test-docs-plan.md)。

---

## 9. 相关文件

- [`integration_test/test_helpers.dart`](../../../integration_test/test_helpers.dart) — 工具函数源码（325 行）
- [`integration_test/theme_chat_e2e_test.dart`](../../../integration_test/theme_chat_e2e_test.dart) — 复用工具的范例（`_createTheme` / `_createNode` / `_sendAndWaitForReply`）