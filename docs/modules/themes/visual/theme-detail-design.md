# ThemeDetailScreen — 主题详情 / 对话树设计

> 范围：`ThemeDetailScreen` + `ThemeDetailController` + 节点卡片视觉系统（`_NodePalette` / `_TreeRowView` / `_DragHandle`）+ 拖拽/swipe/重命名/删除交互。完整模块索引见 [README.md](README.md)；主题列表见 [theme-list-design.md](theme-list-design.md)。

## Summary

`ThemeDetailScreen` 是主题 Tab 的"内容容器"——把主题下所有节点渲染成树形对话网络。核心 UI 是 `_TreeRowView` 节点卡片：56px 固定行高 + 12pt 圆圈 + 缩进表达层级 + SwipeableRow 包裹 + 最右侧拖拽手柄。每个节点通过 `_NodePalette`（5 套双色配色，圆圈 + 标题 + 副标题各不同色）形成视觉区分；拖拽/swipe 颜色跟随主题色（不跟随节点色）。支持长按重命名、swipe 左滑删除（带子树确认）、swipe 右滑创建分支、拖拽手柄重排（同父级）。

**核心设计语言**：与 [design-system.md](../../../_shared/design-system.md) 对齐——`pageBg` 背景、`accent`（indigo）通用交互色、`colorForTheme(themeId)` 拖拽/swipe 主题色。节点卡片的 `_NodePalette` 是本屏**独有的扩展系统**，5 套预设与节点 `nodeId` 稳定绑定。

---

## 设计决策

| 决策点 | 选择 | 说明 |
|--------|------|------|
| 层级表达 | 纯缩进，无连接线 | `depth × 28px` padding 表达层级 |
| 展开/折叠交互入口 | 12pt 随机色圆圈 | 有子节点时可点击，切换空心↔实心 |
| 节点配色 | 5 套 `_NodePalette`（圆圈+标题+副标题），基于 nodeId hash | 同一节点每次打开颜色一致 |
| 拖拽/swipe 颜色 | 跟随 theme 色 | 不跟随节点主色 |
| 节点卡片布局 | 56px 固定行高 + leading 圆圈 + title/subtitle + 拖拽手柄 | 单行不换行 |
| 拖拽触发 | 拖拽手柄 LongPress 400ms | 整行不直接拖拽，避免误操作 |
| 拖拽范围 | 仅同父级重排 | 跨父级拖拽被 onWillAcceptWithDetails 拒绝 |
| 折叠状态 | 不持久化，存 `_collapsedIds: Set<String>` | 每次进入全部展开 |
| Swipe 行为 | 左滑删除 / 右滑分支 | 与节点卡片共用 `SwipeableRow` |
| 删除确认 | 子树提示 + 同标题节点二次确认 | 防止误删 |

---

## 1. 节点配色系统（`_NodePalette`）

5 套双色配色方案（圆圈 + 标题 + 副标题，三色各异）：

```dart
class _NodePalette {
  const _NodePalette(this.circle, this.title, this.subtitle);
  final Color circle;
  final Color title;
  final Color subtitle;
}

const _nodePalettes = [
  _NodePalette(Color(0xFF3B82F6), Color(0xFF1E1B4B), Color(0xFF6366F1)), // 0: electric blue + deep purple + indigo
  _NodePalette(Color(0xFF10B981), Color(0xFF881337), Color(0xFFEA580C)), // 1: emerald + deep rose + coral
  _NodePalette(Color(0xFF8B5CF6), Color(0xFF134E4A), Color(0xFF0369A1)), // 2: violet + deep teal + ocean
  _NodePalette(Color(0xFFEC4899), Color(0xFF312E81), Color(0xFF0D9488)), // 3: hot pink + deep indigo + jade
  _NodePalette(Color(0xFFFBBF24), Color(0xFF0F172A), Color(0xFF7C3AED)), // 4: amber + deep slate + purple
];

_NodePalette _paletteForNode(String nodeId) {
  return _nodePalettes[nodeId.hashCode.abs() % _nodePalettes.length];
}
```

**配色表**：

| Index | 圆圈 | 标题 | 副标题 | 风格 |
|-------|------|------|--------|------|
| 0 | 电蓝 `#3B82F6` | 深紫 `#1E1B4B` | 靛蓝 `#6366F1` | electric |
| 1 | 翠绿 `#10B981` | 深玫瑰 `#881337` | 珊瑚 `#EA580C` | 暖色 |
| 2 | 紫罗兰 `#8B5CF6` | 深青 `#134E4A` | 海蓝 `#0369A1` | 冷色 |
| 3 | 热粉 `#EC4899` | 深靛 `#312E81` | 翡翠 `#0D9488` | 粉冷对比 |
| 4 | 琥珀 `#FBBF24` | 深板岩 `#0F172A` | 紫蓝 `#7C3AED` | 复古 |

**规则**：

- 同一节点 `nodeId` 每次打开颜色一致（`hashCode.abs() % 5` 稳定）
- 标题/副标题颜色均为深色，在 `surface` 卡片上对比度 ≥ 4.5:1（WCAG AA）
- 圆圈颜色既作 12×12 视觉标记，也驱动 2px border + 浅色底（alpha 0.15）
- **不**做运行时动态生成；预设 5 套够用
- 节点色与主题色（`colorForTheme`）**完全解耦**：节点色基于 `nodeId`，主题色基于 `themeId`

---

## 2. 节点卡片布局（`_TreeRowView`）

```
┌──────────────────────────────────────────────────────────┐
│ ┌──[depth × 28px]─────────────────────────────────────┐  │
│ │                                                       │  │
│ │  ⃝   节点标题（单行省略）                          ⋮⋮  │  │
│ │      来自: 笔记                                      │  │
│ │                                                       │  │
│ └───────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
   ↑ 44×44 圆圈热区                  ↑ 52×52 拖拽手柄
```

**实现结构**：

```dart
SizedBox(
  height: 56,
  child: Padding(
    padding: EdgeInsets.only(left: depth * _kIndent),   // _kIndent = 28.0
    child: Row(
      children: [
        // 1. 圆圈交互区（44×44 热区，center 对齐）
        GestureDetector(
          onTap: hasChildren ? () => onToggleCollapse(node.nodeId) : null,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 44, height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: 200ms, curve: easeInOut,
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: hasChildren
                    ? (isCollapsed ? palette.circle : palette.circle.withValues(alpha: 0.15))
                    : palette.circle.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.circle, width: 2),
                ),
              ),
            ),
          ),
        ),
        // 2. 标题 + 副标题
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(node.title, style: AppTheme.body.copyWith(color: AppColors.textPrimary), maxLines: 1, overflow: ellipsis),
              Text(sourceLabel ?? '', style: AppTheme.caption1.copyWith(color: palette.subtitle), maxLines: 1, overflow: ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
  ),
)
```

**布局细节**：

| 元素 | 尺寸 | 颜色 | 备注 |
|------|------|------|------|
| 行高 | 56px 固定 | — | 不因内容差异而变化 |
| 缩进 | `depth × 28px` | — | 纯缩进表达层级，无连接线 |
| 圆圈 | 12×12 | `palette.circle` border + alpha 0.15 底 | 2px border，圆角 = 圆形 |
| 圆圈热区 | 44×44 | — | 整个区域可点，不只是圆圈本身 |
| 标题 | `AppTheme.body` | `AppColors.textPrimary` | 单行省略 |
| 副标题 | `AppTheme.caption1` | `palette.subtitle` | 来源标签，单行 |
| 拖拽手柄 | 52×52 | 24pt `line_horizontal_3` icon | `textTertiary.withValues(alpha: 0.4)` |

**深度与缩进**：

```dart
static const _kIndent = 28.0;
```

- depth 0（根节点）：无缩进
- depth 1：左边 28px
- depth 2：左边 56px
- 以此类推

**子节点渲染**：

```dart
if (!hasChildren || isCollapsed) {
  return tile;  // 无子节点 或 已折叠 → 只渲染自己
}

final childWidgets = <Widget>[tile];
for (int i = 0; i < children.length; i++) {
  childWidgets.add(
    _TreeRowView(themeId: themeId, node: children[i], allNodes: allNodes,
                 depth: depth + 1, collapsedIds: collapsedIds, onToggleCollapse: onToggleCollapse),
  );
}
return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: childWidgets);
```

子节点以**递归 `_TreeRowView`** 渲染，而非扁平 ListView。优势是父子关系清晰、缩进自动累加；缺点是深嵌套时 Column 可能偏长（实测 5 层内无性能问题）。

---

## 3. 圆圈交互

### 3.1 状态定义

| 状态 | 视觉 | 含义 |
|------|------|------|
| 空心（展开） | 12×12，2px border `palette.circle`，填充 `palette.circle` alpha 0.15 | 能窥见下面的 branch |
| 实心（收起） | 12×12，实心 `palette.circle` | 已封起来 |

### 3.2 动画

- `AnimatedContainer` duration **200ms**，curve `Curves.easeInOut`
- 尺寸：始终 12×12（空心视觉略大通过 border 平衡）
- 颜色：从 alpha 0.15 背景 ↔ 实心 `palette.circle` 平滑过渡

### 3.3 显示条件

- **所有节点**均显示 12×12 圆圈
- **有子节点**（`hasChildren == true`）：圆圈可点击 → `onToggleCollapse(nodeId)` + 切换空心↔实心
- **无子节点**：`onTap: null`，圆圈仅作视觉装饰，仍保持空心样式（始终显示淡色底）

```dart
onTap: hasChildren ? () => onToggleCollapse(node.nodeId) : null,
```

### 3.4 折叠状态管理

`Set<String> _collapsedIds` 存在 `_ThemeDetailScreenState`：

```dart
final Set<String> _collapsedIds = {};
```

```dart
onToggleCollapse: (id) => setState(() {
  if (!_collapsedIds.remove(id)) {
    _collapsedIds.add(id);
  }
}),
```

**不持久化**：用户每次进入主题详情页，折叠状态重置为全部展开（`Set` 是空的）。

---

## 4. 拖拽重排

### 4.1 拖拽手柄（`_DragHandle`）

52×52 区域，最右侧 `Padding(EdgeInsets.only(right: 8))` 留出右边距。

**视觉**：

```dart
SizedBox(
  width: 52, height: 52,
  child: Center(
    child: Icon(CupertinoIcons.line_horizontal_3, size: 24,
      color: CupertinoColors.tertiaryLabel.resolveFrom(context).withValues(alpha: 0.4)),
  ),
)
```

**交互**：

```dart
GestureDetector(
  onTapDown: (_) => _scaleCtrl.forward(),
  onTapUp: (_) => _scaleCtrl.reverse(),
  onTapCancel: () => _scaleCtrl.reverse(),
  child: LongPressDraggable<NodeEntity>(
    data: widget.node,
    delay: const Duration(milliseconds: 400),
    onDragStarted: () => HapticFeedback.mediumImpact(),
    onDragEnd: (_) => _scaleCtrl.reverse(),
    onDraggableCanceled: (_, _) => _scaleCtrl.reverse(),
    feedback: /* 圆角气泡 280px max, surface bg, shadow */,
    childWhenDragging: Opacity(opacity: 0.15, child: Icon(line_horizontal_3, 24, tertiaryLabel)),
    child: /* 原 icon with scale 1.0→1.1 动画 */
  ),
)
```

**关键行为**：

- 长按 400ms 触发拖拽（`delay: 400ms`）
- 拖拽开始：`HapticFeedback.mediumImpact()` 触感反馈
- 拖拽时原位 icon 透明度 0.15（视觉"被拿起"）
- 反馈气泡：`ConstrainedBox(maxWidth: 280)` + 圆角 10 + 黑色 20% shadow + 92% 透明度
- 拖拽结束 / 取消：scale 动画 reverse（弹回 1.0）
- 点击 / 按下 / 松开都有 scale 1.0→1.1→1.0 动画（120ms easeOut）

### 4.2 DragTarget（落在节点行）

每个 `_TreeRowView` 的最外层是 `DragTarget<NodeEntity>`：

```dart
DragTarget<NodeEntity>(
  onWillAcceptWithDetails: (details) =>
    details.data.parentId == node.parentId &&
    details.data.nodeId != node.nodeId,
  onAcceptWithDetails: (details) async {
    await _handleReorder(ref, draggedNode: details.data, targetNode: node, allNodes: allNodes);
    await ref.read(themeDetailControllerProvider(themeId).notifier).refreshNodesOnly();
  },
  builder: (context, candidateData, rejectedData) {
    final isHovering = candidateData.isNotEmpty;
    final siblings = allNodes.where((n) => n.parentId == node.parentId).toList()..sort(_compareNodes);
    final isLastChild = siblings.isNotEmpty && siblings.last.nodeId == node.nodeId;
    final indicatorSide = isLastChild
      ? const Border(bottom: BorderSide(color: systemBlue, width: 2.5))
      : const Border(top: BorderSide(color: systemBlue, width: 2.5));
    return Container(
      decoration: isHovering
        ? BoxDecoration(
            color: systemBlue.resolveFrom(context).withValues(alpha: 0.08),
            border: indicatorSide,
          )
        : null,
      child: Row(children: [/* SwipeableRow + 拖拽手柄 */]),
    );
  },
)
```

**关键约束**：

- `onWillAcceptWithDetails`：**只接受同父级**（`parentId` 相同）且**不是自己**的拖拽
- 跨父级拖拽：自动拒绝（不显示 hover 效果）
- Hover 背景：`systemBlue` alpha 0.08 tint
- Hover 指示线：
  - 中间节点：上边 2.5px `systemBlue` 指示线
  - 最后节点：下边 2.5px `systemBlue` 指示线
- 落点位置自动判断（向上插入 vs 向下插入）

### 4.3 重排逻辑（`_handleReorder`）

```dart
Future<void> _handleReorder(WidgetRef ref, {
  required NodeEntity draggedNode,
  required NodeEntity targetNode,
  required List<NodeEntity> allNodes,
}) async {
  final nodeStore = await ref.read(nodeStoreProvider.future);
  final parentId = targetNode.parentId;

  final siblings = allNodes.where((n) => n.parentId == parentId).toList()..sort(_compareNodes);

  // 方向判断：向下拖 → 插入 target 之后；向上拖 → 插入 target 之前
  final draggedIdx = siblings.indexWhere((n) => n.nodeId == draggedNode.nodeId);
  final targetOriginalIdx = siblings.indexWhere((n) => n.nodeId == targetNode.nodeId);
  final draggingDown = draggedIdx < targetOriginalIdx;

  siblings.removeWhere((n) => n.nodeId == draggedNode.nodeId);
  final targetIdx = siblings.indexWhere((n) => n.nodeId == targetNode.nodeId);
  siblings.insert(draggingDown ? targetIdx + 1 : targetIdx, draggedNode);

  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (int i = 0; i < siblings.length; i++) {
    await nodeStore.reorderNode(nodeId: siblings[i].nodeId, newSortOrder: now + i);
  }
}
```

**要点**：

- 拖拽完成后用 `refreshNodesOnly()`（不走磁盘 reindex）
- 用 `now + i` 作为新的 sortOrder（毫秒级精度足够区分）
- 方向判断避免"向上拖动时插入位置错乱"
- debug 模式打印 [REORDER] 日志，便于排查

**为什么不支持跨父级**：避免循环引用、避免破坏树结构稳定性。如果未来需要"移动节点到其他主题"，应单独开一个 `moveToTheme` action。

---

## 5. Swipe 行为

`_TreeRowView` 的内容用 `SwipeableRow` 包裹（拖拽手柄在外面）：

```dart
SwipeableRow(
  onSwipeLeft: () => _handleDelete(context, ref, l10n, node: node, themeId: themeId, allNodes: allNodes),
  onSwipeRight: () => _onCreateBranchFromMenu(context, ref, node: node),
  leftActionLabel: l10n.swipeDelete,
  leftActionIcon: AppIcons.delete,
  leftActionColor: CupertinoColors.destructiveRed,    // 系统语义色
  rightActionLabel: l10n.swipeBranch,
  rightActionIcon: AppIcons.callSplit,
  rightActionColor: CupertinoColors.systemBlue,         // 这里用 systemBlue（swipe 触发色），不直接用主题色
  child: GestureDetector(/* 点击进对话 + 长按重命名 */),
)
```

**注意**：swipe 右滑的 `rightActionColor` 当前用 `systemBlue`（**不**跟随主题色）。这与文档开头的"swipe 右滑跟随 theme 色"略有出入——保留这一行为是为了 swipe 反馈的统一性（systemBlue 是 iOS 通用交互色）。如果未来要严格跟主题色，改成 `colorForTheme(themeId)` 即可。

---

## 6. Swipe 左滑 — 删除

### 6.1 流程

```
swipe 左滑
    │
    ▼
_handleDelete
    │
    ├─ _collectSubtreeNodes(node, allNodes)  → 子树节点列表
    ├─ 查找同标题节点（不在子树内）  → sameTitleNodesOutside
    │
    ▼
_confirmDeleteNode(node, subtreeNodes, sameTitleNodesOutside)
    │
    ├─ 弹 CupertinoAlertDialog
    │   - title: "删除"
    │   - content: "确认删除 [title]?" + 子树提示 + 同标题提示
    │   - actions: [取消] [删除(危险)]
    │
    ▼
if confirmed:
    deleteNodeSubtree(nodeId)  → 弹 toast deletedCount(n)
```

### 6.2 子树收集（`_collectSubtreeNodes`）

BFS 收集 root 节点 + 所有后代：

```dart
List<NodeEntity> _collectSubtreeNodes(NodeEntity root, List<NodeEntity> allNodes) {
  final childrenByParent = <String?, List<NodeEntity>>{};
  for (final item in allNodes) {
    childrenByParent.putIfAbsent(item.parentId, () => []).add(item);
  }
  final result = <NodeEntity>[];
  final queue = <NodeEntity>[root];
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    result.add(current);
    queue.addAll(childrenByParent[current.nodeId] ?? const []);
  }
  return result;
}
```

### 6.3 同标题二次确认

当 `sameTitleNodesOutside.isNotEmpty`（有相同标题的节点不在子树内）时：

- 显示提示："有 N 个同标题节点保留"
- 列出这些 nodeId（每行一个）
- 弹出 checkbox："我已了解"（不勾选时"删除"按钮 disabled）

```dart
final needsAck = sameTitleNodesOutside.isNotEmpty;
bool acknowledged = false;
// StatefulBuilder
// checkbox 切换 acknowledged
// 删除按钮：needsAck && !acknowledged ? null : pop(true)
```

**为什么需要二次确认**：避免"删除后磁盘上还有同名节点导致用户困惑"的情况。

### 6.4 Toast 提示

```dart
_showAlert(context, l10n.deletedCount(deletedCount));   // 成功
_showAlert(context, l10n.deleteFailed(e.toString()));  // 失败
```

简单 `CupertinoAlertDialog` + "OK" 按钮。

---

## 7. Swipe 右滑 — 创建分支

### 7.1 流程

```
swipe 右滑
    │
    ▼
_onCreateBranchFromMenu
    │
    ▼
showBranchModeSheet(context)  → 选择模式（如续写/改写）
    │
    ▼
_showBranchFlow
    │
    ├─ 读 nodeStore.getNodeRow → sessionPath
    ├─ 读 session.md → 解析 → parentTranscript
    ├─ 拿 providerId / modelId（从 settings 兼容映射）
    │
    ▼
showBranchFlow(
  context: context, mode, parentTranscript,
  providerId, modelId, themeId, parentNodeId,
)
```

`showBranchFlow` 是 `branch_flow` 共享弹层（与笔记模块的"转对话"共用，见 [notes/README.md §chat→note](../../notes/README.md)）。这里不重复展开。

### 7.2 LLM Provider 兼容映射

```dart
String _mapLegacyProviderToPresetId(LlmProvider provider) {
  switch (provider) {
    case LlmProvider.claude: return 'preset_anthropic';
    case LlmProvider.deepseek: return 'preset_deepseek';
    case LlmProvider.openai: return 'preset_openai';
    case LlmProvider.gemini: return 'preset_gemini';
    case LlmProvider.minimax: return 'preset_minimax';
    case LlmProvider.kimi: return 'preset_kimi';
  }
}
```

把旧版枚举值映射到新版 preset ID（字符串）。

---

## 8. 长按重命名

```dart
GestureDetector(
  onLongPress: () => _showRenameDialog(context, ref, node, themeId, allNodes),
  child: tileContent,
)
```

`_showRenameDialog`：

```dart
showCupertinoDialog(
  context: context,
  builder: (ctx) => CupertinoAlertDialog(
    title: Text(l10n.renameNode),
    content: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CupertinoTextField(
        controller: controller, autofocus: true,
        placeholder: l10n.enterNewTitle,
      ),
    ),
    actions: [
      CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
      CupertinoDialogAction(isDefaultAction: true, onPressed: () async {
        final newTitle = controller.text.trim();
        if (newTitle.isNotEmpty) {
          await nodeStore.updateNodeTitle(nodeId: node.nodeId, newTitle: newTitle);
          ref.read(themeDetailControllerProvider(themeId).notifier).refresh();
        }
        if (context.mounted) Navigator.pop(ctx);
      }, child: Text(l10n.save)),
    ],
  ),
);
```

**注意**：

- 取消按钮用 `isDestructiveAction: true`（红色），视觉上让"取消 = 危险操作"的暗示（避免误删）
- 保存后调 `refresh()`（触发磁盘 reindex）
- 标题为空时静默不保存（不弹错误）

---

## 9. 标题（Title）显示

```dart
Text(
  l10n.treeTitle(localizedThemeTitle(l10n, data.themeTitle)),
  // 例如："主题 A 的会话"
)
```

`localizedThemeTitle` 把磁盘的"未分类"映射到 l10n 的 `uncategorized`。

---

## 10. NavBar

```dart
ThkNavBar.inline(
  title: l10n.treeTitle(localizedThemeTitle(l10n, data.themeTitle)),
  leading: CupertinoButton(
    padding: EdgeInsets.zero, minimumSize: Size.zero,
    onPressed: () {
      if (Navigator.canPop(context)) context.pop();
      else context.go('/');
    },
    child: const Icon(AppIcons.back),
  ),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CupertinoButton(
        key: const ValueKey('refresh_button'),
        padding: EdgeInsets.zero,
        onPressed: () => ref.read(themeDetailControllerProvider(widget.themeId).notifier).refresh(),
        child: Icon(AppIcons.refresh),
      ),
      CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () async {
          final title = await _promptRootTitle(context);
          if (title == null) return;
          await ref.read(themeDetailControllerProvider(widget.themeId).notifier).createRootChatNode(title: title);
        },
        child: Icon(AppIcons.add),
      ),
    ],
  ),
)
```

**按钮语义**：

| 按钮 | Icon | 行为 | 备注 |
|------|------|------|------|
| ← | `AppIcons.back` | `context.pop()` 或 `context.go('/')` | 优先 pop，无 stack 时回 Tab |
| ↻ | `AppIcons.refresh` | `refresh()` 完整 reindex | 走磁盘 |
| + | `AppIcons.add` | 弹 `_promptRootTitle` → `createRootChatNode` | 见 §11 |

---

## 11. 新建根节点对话框

与主题列表的 `_promptTitle` 几乎一样，唯一差异是 `title` 文案（`l10n.newSession` vs `l10n.newTheme`）。

```dart
Future<String?> _promptRootTitle(BuildContext context) async {
  // showCupertinoDialog<String> + CupertinoAlertDialog
  // title: l10n.newSession
  // content: ThkTextField(autofocus: true, maxLength: 30)
  // actions: [取消] [创建(isDefaultAction)]
}
```

**与主题列表新建的差异**：

| 维度 | 主题列表 | 主题详情（根节点） |
|------|----------|------------------|
| 标题文案 | `l10n.newTheme` | `l10n.newSession` |
| 创建后调用的方法 | `themeListControllerProvider.createTheme` | `themeDetailControllerProvider.createRootChatNode` |
| 是否触发列表刷新 | 是 | 否（详情页自己刷新） |

---

## 12. 空状态 / 错误 / Loading

### 12.1 树空状态

```dart
roots.isEmpty
  ? Center(child: Text(l10n.emptyTree))
  : SafeArea(child: Center(child: ConstrainedBox(constraints: maxWidth: 800, child: ListView.separated(...))))
```

树空时直接 `Center(Text(l10n.emptyTree))`，无 icon、无按钮（用户可用 NavBar + 创建根节点）。

**注意**：这个空状态比主题列表的空状态更"裸"，没有 accountTree icon。设计权衡：树空时通常用户已通过 swipe 等方式操作过了，不引导"创建第一个节点"。

### 12.2 错误

```dart
error: (e, st) => CupertinoPageScaffold(
  navigationBar: ThkNavBar.inline(title: ''),
  child: Center(child: Text(e.toString())),
)
```

NavBar 标题为空 + 错误文本居中。

### 12.3 Loading

```dart
loading: () => CupertinoPageScaffold(
  navigationBar: ThkNavBar.inline(title: ''),
  child: const Center(child: CupertinoActivityIndicator()),
)
```

NavBar 标题为空 + CupertinoActivityIndicator。

---

## 13. 列表最大宽度约束

```dart
SafeArea(
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: ListView.separated(...),
    ),
  ),
)
```

平板 / 横屏 / Mac Catalyst 时列表最大 800px 宽，居中显示，左右留白。手机端宽度 < 800px，自动占满。

---

## 14. ThemeDetailController

```dart
class ThemeDetailController extends AsyncNotifier<ThemeDetailState> {
  ThemeDetailController(this.themeId);
  final String themeId;

  @override
  Future<ThemeDetailState> build() async => _load();

  Future<ThemeDetailState> _load() async {
    // themeStore.reindexThemesFromDisk() + nodeStore.reindexNodesFromDisk()
    // + getThemeRow + listNodes + 异步加载 lastMessagePreview
  }

  Future<void> refresh() async { /* 完整 _load */ }
  Future<void> refreshNodesOnly() async { /* 只刷节点顺序，不走磁盘 */ }
  Future<void> createRootChatNode({required String title}) async { ... }
  Future<NodeEntity> createChildChatNode({required String parentId, required String title}) async { ... }
  Future<int> deleteNodeSubtree({required String nodeId}) async { ... }
}

final themeDetailControllerProvider =
  AsyncNotifierProvider.autoDispose.family<ThemeDetailController, ThemeDetailState, String>(
    ThemeDetailController.new);
```

**关键设计**：

- `autoDispose.family`：按 themeId 隔离，离开屏幕自动销毁
- `_withLastMessagePreviews`：异步读取每个节点 `session.md` 最后一条 user 消息（截前 40 字）作为副标题预览
- `refresh()` vs `refreshNodesOnly()`：前者走磁盘，后者只刷内存（拖拽后用）

---

## 15. 关键交互链路总结

| 触发 | 链路 | 副作用 |
|------|------|--------|
| 点击节点行 | `context.push('/themes/:themeId/nodes/:nodeId')` | 进入 chat |
| 长按节点行 | `_showRenameDialog` → `nodeStore.updateNodeTitle` → `refresh()` | 整树重新加载 |
| swipe 左滑 | `_handleDelete` → `_confirmDeleteNode` → `deleteNodeSubtree` | 子树磁盘删除 + toast |
| swipe 右滑 | `_onCreateBranchFromMenu` → `showBranchModeSheet` → `showBranchFlow` | 创建新分支（branch_flow 弹层） |
| 拖拽手柄 | `LongPressDraggable` 400ms → 拖到目标 → `_handleReorder` → `reorderNode` ×N → `refreshNodesOnly` | sortOrder 重写 |
| NavBar ↻ | `refresh()` | 完整磁盘 reindex |
| NavBar + | `_promptRootTitle` → `createRootChatNode` | 新建根节点 |

---

## 实现文件清单

| 文件 | 角色 |
|------|------|
| `lib/ui/features/themes/theme_detail_screen.dart` | 屏幕本体（906 行）+ _NodePalette + _TreeRowView + _DragHandle + 所有交互 handler |
| `lib/ui/features/themes/theme_detail_controller.dart` | controller（148 行） |
| `lib/ui/features/notes/note_browse_screen.dart` | 共享 `localizedThemeTitle()` 工具 |
| `lib/ui/features/settings/settings_controller.dart` | 读 settings（LLM provider/model） |
| `lib/ui/core/shared/title_suggestion_screen.dart` | 智能命名建议弹层 |
| `lib/ui/core/shared/branch_flow.dart` | 分支创建流程（与笔记模块共用） |
| `lib/ui/core/widgets/widgets.dart` | `ThkNavBar` / `SwipeableRow` / `ThkTextField` |
| `lib/ui/core/theme/app_colors.dart` | `colorForTheme` / `tintForTheme` |
| `lib/ui/core/theme/app_theme.dart` | `AppTheme.body` / `caption1` |
| `lib/ui/core/theme/app_icons.dart` | `back` / `add` / `refresh` / `delete` / `callSplit` |
| `lib/data/services/session_markdown.dart` | `parseSessionMarkdown` / `buildConversationTranscript` |
| `lib/data/services/llm_provider.dart` | `LlmProvider` 枚举 |

---

## Test Plan

### 节点卡片视觉

1. **5 套配色**：5 个不同 nodeId 落在不同 palette index；同一 nodeId 每次打开颜色一致
2. **行高一致**：所有节点卡片高度固定 56px，不因标题长度或副标题存在与否而变化
3. **缩进层级**：depth 0/1/2/3 缩进 0/28/56/84px
4. **圆圈显示**：所有节点都显示 12×12 圆圈（无子节点也显示但不可点）
5. **圆圈动画**：空心↔实心 AnimatedContainer 200ms easeInOut 平滑
6. **副标题颜色**：用 `palette.subtitle` 而非 `textSecondary`
7. **单行省略**：标题 / 副标题超长时 ellipsis

### 圆圈交互

8. **可点击条件**：有子节点时圆圈可点击；无子节点时 onTap: null（但视觉仍有淡色底圆圈）
9. **点击行为**：空心 ↔ 实心 + 折叠 / 展开同步
10. **不持久化**：离开屏幕再回来，折叠状态重置（`_collapsedIds` 清空）

### 拖拽重排

11. **拖拽手柄可点区域**：52×52
12. **触发延迟**：长按 400ms 触发
13. **拖拽时原位 icon**：透明度 0.15
14. **反馈气泡**：280px max，surface bg，黑色 20% shadow
15. **Haptic 反馈**：`HapticFeedback.mediumImpact()` on drag start
16. **Hover 指示线**：
    - 中间节点：上边 2.5px systemBlue
    - 最后节点：下边 2.5px systemBlue
17. **跨父级拒绝**：`onWillAcceptWithDetails` 拒绝 `parentId` 不同的拖拽
18. **重排逻辑**：
    - 同父级 A→B：A 出现在 B 之前或之后（按拖动方向）
    - 重新计算所有 sibling 的 sortOrder
    - 用 `now + i` 作为新 sortOrder
19. **拖拽后刷新**：`refreshNodesOnly()`（不走磁盘 reindex）
20. **拖动到无效区域**：自动回弹（`onDraggableCanceled` 触发 scale 动画 reverse）

### Swipe 删除

21. **左滑触发**：`onSwipeLeft` 回调
22. **确认对话框**：
    - title: l10n.deleteItem
    - content: 节点标题 + 子树提示
    - 有同标题节点时：额外显示 + checkbox
23. **同标题二次确认**：未勾选时"删除"按钮 disabled
24. **删除后 toast**：`l10n.deletedCount(n)` 显示删除节点数
25. **删除失败**：`l10n.deleteFailed(e.toString())`

### Swipe 分支

26. **右滑触发**：`onSwipeRight` 回调
27. **分支模式选择**：`showBranchModeSheet` 弹层
28. **创建分支**：调用 `showBranchFlow` 弹层，传入 parentTranscript / providerId / modelId / themeId / parentNodeId
29. **失败 toast**：`l10n.branchFailed(reason)`

### 长按重命名

30. **长按触发**：长按节点行调 `_showRenameDialog`
31. **重命名对话框**：CupertinoAlertDialog + CupertinoTextField + 取消/保存
32. **取消按钮**：`isDestructiveAction: true`（红色）
33. **保存空标题**：静默不保存
34. **保存后刷新**：`refresh()`（走磁盘 reindex）

### NavBar

35. **返回**：`context.pop()` 优先；无 stack 时 `context.go('/')` 回 Tab
36. **↻ 按钮**：`refresh()` 完整 reindex
37. **+ 按钮**：弹 `_promptRootTitle` → `createRootChatNode`
38. **空 title**：静默不创建

### 状态管理

39. **`themeDetailControllerProvider`**：按 themeId 隔离 + autoDispose
40. **`build()`** 包含磁盘 reindex
41. **`refreshNodesOnly()`** 不走磁盘（拖拽后用）

### 跨屏刷新

42. **详情页内 CRUD 不影响主题列表**：删除/重命名不修改 theme.title
43. **未来支持"重命名主题"** 时需要手动 `ref.invalidate(themeListControllerProvider)`

### 性能

44. **100+ 节点滑动顺畅**：ListView.separated + 56px 固定行高
45. **拖拽气泡动画 60fps**
46. **展开 / 折叠动画无卡顿**

### 设计令牌合规

47. `grep -r "CupertinoColors.white\|CupertinoColors.systemBackground\|CupertinoColors.label\|CupertinoColors.tertiaryLabel" lib/ui/features/themes/theme_detail_screen.dart` 0 命中（除系统语义色 systemRed / destructiveRed / systemBlue）
48. 节点圆圈/标题/副标题颜色用 `_NodePalette` 常量
49. 拖拽/swipe 颜色用 `colorForTheme` / `tintForTheme`（swipe 右滑保留 systemBlue 的特殊情况除外）

---

## Assumptions

- `uses-material-design: false` 保持不变
- 折叠状态（`_collapsedIds`）不持久化，每次进入主题详情页默认全部展开
- 节点拖拽**不允许跨父级**，仅支持同父级重排；如果未来要"移动到其他主题"，应单独开 `moveToTheme` action
- `LongPressDraggable` 400ms 延迟是手感调试结果，不要轻易改
- 节点 `sourceType` 只有 4 个枚举值：`selectedText` / `conversation` / `summary` / `note`；其他值副标题不显示
- 调试模式（`kDebugMode`）下删除对话框显示 nodeId——release 模式隐藏
- 节点 `lastMessagePreview` 异步加载（不影响首屏渲染），来自 `session.md` 最后一条 user 消息的前 40 字
- 删除节点子树时，"同标题"判定基于 `node.title` 完全匹配
- swipe 右滑按钮保留 `systemBlue`（不跟随主题色），便于 swipe 反馈的统一性
- 树空时无 icon / 按钮（与主题列表空状态风格不同）—— 用户已通过 swipe 操作过，UI 不再强调引导
- 平板 / 横屏列表最大 800px 宽（手机端自动占满）
- 节点子节点以**递归 `_TreeRowView`** 渲染，非扁平 ListView（深嵌套时性能可接受）
- 不做深色模式适配
