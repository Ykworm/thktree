# ThemeDetailScreen — 主题详情 / 对话树设计

> 范围：`ThemeDetailScreen` + `ThemeDetailController` + 节点卡片视觉系统（`_NodePalette` / `_TreeRowView` / `_DragHandle`）+ 拖拽/swipe/重命名/删除交互。完整模块索引见 [README.md](README.md)；主题列表见 [theme-list-design.md](theme-list-design.md)。

## Summary

`ThemeDetailScreen` 是主题 Tab 的"内容容器"——把主题下所有节点渲染成树形对话网络。核心 UI 是 `_TreeRowView` 节点卡片：56px 固定行高 + 12pt 圆圈 + 缩进表达层级 + SwipeableRow 包裹 + 最右侧拖拽手柄。每个节点通过 `_NodePalette`（5 套配色，圆圈 + 标题 + 副标题各不同色）形成视觉区分。支持长按重命名、swipe 左滑删除（带子树确认）、swipe 右滑创建分支、拖拽手柄重排（同父级）。列表顶部有**节点标题搜索**（本地 title 过滤，非全局 FTS）。

**核心设计语言**：与 [design-system.md](../../../_shared/design-system.md) 对齐——`surface` 白色背景、`accent`（indigo）通用交互色。节点卡片的 `_NodePalette` 是本屏独有的扩展系统，5 套预设与节点 `nodeId` 稳定绑定。

---

## 设计决策

| 决策点 | 选择 | 说明 |
|--------|------|------|
| 层级表达 | 纯缩进，无连接线 | `depth × 28px` padding 表达层级 |
| 展开/折叠交互入口 | 12pt 彩色圆圈 | 有子节点时可点击，切换空心↔实心 |
| 节点配色 | 5 套 `_NodePalette`（圆圈+标题+副标题），基于 nodeId hash | 典雅黑金色调 |
| 节点卡片布局 | 56px 固定行高 + leading 圆圈 + title/subtitle + 拖拽手柄 | 单行不换行 |
| 拖拽触发 | 拖拽手柄 LongPress 400ms | 整行不直接拖拽，避免误操作 |
| 拖拽范围 | 仅同父级重排 | 跨父级拖拽被 onWillAcceptWithDetails 拒绝 |
| 折叠状态 | 不持久化，存 `_collapsedIds: Set<String>` | 每次进入全部展开 |
| Swipe 行为 | 左滑删除 / 右滑分支 | 与节点卡片共用 `SwipeableRow` |
| 删除确认 | 子树提示 + 同标题节点二次确认 | 防止误删 |
| 标题搜索 | 顶部常驻 `CupertinoSearchTextField` | 只匹配 `NodeEntity.title`；命中 ∪ 祖先；见第 7.1 节 |

---

## 1. 节点配色系统（`_NodePalette`）

5 套配色方案（圆圈 + 标题 + 副标题，三色各异），典雅黑金色调：

```dart
class _NodePalette {
  const _NodePalette(this.circle, this.title, this.subtitle);
  final Color circle;
  final Color title;
  final Color subtitle;
}

const _nodePalettes = [
  _NodePalette(
    Color(0xFFB8A07A),  // circle: 暖金
    Color(0xFF4A4A4A),  // title: 深灰
    Color(0xFF8B7355),  // subtitle: 棕灰
  ),
  _NodePalette(
    Color(0xFF7A8B7A),  // circle: 灰绿
    Color(0xFF3D4A3D),  // title: 深绿灰
    Color(0xFF6B7B6B),  // subtitle: 中绿灰
  ),
  _NodePalette(
    Color(0xFF8B7A8B),  // circle: 灰紫
    Color(0xFF4A3D4A),  // title: 深紫灰
    Color(0xFF7B6B7B),  // subtitle: 中紫灰
  ),
  _NodePalette(
    Color(0xFF8B7A7A),  // circle: 灰粉
    Color(0xFF4A3D3D),  // title: 深粉灰
    Color(0xFF7B6B6B),  // subtitle: 中粉灰
  ),
  _NodePalette(
    Color(0xFF7A7A8B),  // circle: 灰蓝
    Color(0xFF3D3D4A),  // title: 深蓝灰
    Color(0xFF6B6B7B),  // subtitle: 中蓝灰
  ),
];

_NodePalette _paletteForNode(String nodeId) {
  return _nodePalettes[nodeId.hashCode.abs() % _nodePalettes.length];
}
```

**配色表**：

| Index | 圆圈 | 标题 | 副标题 | 风格 |
|-------|------|------|--------|------|
| 0 | 暖金 `#B8A07A` | 深灰 `#4A4A4A` | 棕灰 `#8B7355` | 温暖 |
| 1 | 灰绿 `#7A8B7A` | 深绿灰 `#3D4A3D` | 中绿灰 `#6B7B6B` | 沉稳 |
| 2 | 灰紫 `#8B7A8B` | 深紫灰 `#4A3D4A` | 中紫灰 `#7B6B7B` | 优雅 |
| 3 | 灰粉 `#8B7A7A` | 深粉灰 `#4A3D3D` | 中粉灰 `#7B6B6B` | 细腻 |
| 4 | 灰蓝 `#7A7A8B` | 深蓝灰 `#3D3D4A` | 中蓝灰 `#6B6B7B` | 冷静 |

**规则**：

- 同一节点 `nodeId` 每次打开颜色一致（`hashCode.abs() % 5` 稳定）
- 标题/副标题颜色均为深色，在 `surface` 卡片上对比度 ≥ 4.5:1（WCAG AA）
- 圆圈颜色既作 12×12 视觉标记，也驱动 2px border + 浅色底（alpha 0.15）
- **不**做运行时动态生成；预设 5 套够用
- 节点色与主题色（`colorForTheme`）**完全解耦**：节点色基于 `nodeId`，主题色基于 `themeId`
- 典雅黑金色调：低饱和度、暖灰调，与主题列表配色协调

---

## 2. 节点卡片布局（`_TreeRowView`）

```
┌──────────────────────────────────────────────────────────┐
│ ┌──[depth × 28px]─────────────────────────────────────┐  │
│ │                                                       │  │
│ │  ⃝   节点标题（单行省略）                          ⋮⋮  │  │
│ │      来源标签                                         │  │
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

---

## 3. 圆圈交互

### 3.1 状态定义

| 状态 | 视觉 | 含义 |
|------|------|------|
| 空心（展开） | 12×12，2px border `palette.circle`，填充 `palette.circle` alpha 0.15 | 能窥见下面的 branch |
| 实心（收起） | 12×12，实心 `palette.circle` | 已封起来 |

### 3.2 动画

- `AnimatedContainer` duration **200ms**，curve `Curves.easeInOut`
- 尺寸：始终 12×12
- 颜色：从 alpha 0.15 背景 ↔ 实心 `palette.circle` 平滑过渡

### 3.3 显示条件

- **所有节点**均显示 12×12 圆圈
- **有子节点**（`hasChildren == true`）：圆圈可点击 → `onToggleCollapse(nodeId)` + 切换空心↔实心
- **无子节点**：`onTap: null`，圆圈仅作视觉装饰

---

## 4. 拖拽重排

### 4.1 拖拽手柄（`_DragHandle`）

52×52 区域，最右侧 `Padding(EdgeInsets.only(right: 8))` 留出右边距。

**交互**：
- 长按 400ms 触发拖拽
- 拖拽开始：`HapticFeedback.mediumImpact()` 触感反馈
- 拖拽时原位 icon 透明度 0.15
- 反馈气泡：`ConstrainedBox(maxWidth: 280)` + 圆角 10 + 黑色 20% shadow
- 拖拽结束 / 取消：scale 动画 reverse

### 4.2 DragTarget（落在节点行）

- `onWillAcceptWithDetails`：**只接受同父级**（`parentId` 相同）且**不是自己**的拖拽
- Hover 背景：`systemBlue` alpha 0.08 tint
- Hover 指示线：
  - 中间节点：上边 2.5px `systemBlue`
  - 最后节点：下边 2.5px `systemBlue`

---

## 5. Swipe 行为

`_TreeRowView` 的内容用 `SwipeableRow` 包裹：

```dart
SwipeableRow(
  onSwipeLeft: () => _handleDelete(...),
  onSwipeRight: () => _onCreateBranchFromMenu(...),
  leftActionLabel: l10n.swipeDelete,
  leftActionIcon: AppIcons.delete,
  leftActionColor: CupertinoColors.destructiveRed,
  rightActionLabel: l10n.swipeBranch,
  rightActionIcon: AppIcons.callSplit,
  rightActionColor: CupertinoColors.systemBlue,
  child: GestureDetector(/* 点击进对话 + 长按重命名 */),
)
```

---

## 6. 长按重命名

```dart
onLongPress: () => _showRenameDialog(context, ref, node, themeId, allNodes),
```

`_showRenameDialog`：CupertinoAlertDialog + CupertinoTextField + 取消/保存

---

## 7. NavBar

```dart
ThkNavBar.inline(
  title: l10n.treeTitle(localizedThemeTitle(l10n, data.themeTitle)),
  leading: CupertinoButton(/* 返回 */),
  trailing: CupertinoButton(/* ⋯ overflow */),
)
```

### 7.1 工具行（body 顶部）

Tree tab 顶部常驻一行工具行：搜索框 + 两个操作按钮（操作集中右侧）：

```
[ 🔍 搜索框 (Expanded) ]  [ + ]  [ 📥 ]
```

| 元素 | key | 说明 |
|------|-----|------|
| 标题搜索框 | `tree_title_search` | `CupertinoSearchTextField`，行为见 7.1.1 |
| 新建根节点 `+` | `add_node_button` | accent 图标；`_promptRootTitle` → `createRootChatNode` |
| 导入文档并拆分 📥 | `doc_split_button` | textSecondary 图标；`AppIcons.docSplit` = `arrow.down.doc`（SF Symbol） |

- 两个操作按钮用 `_buildToolbarButton`：40×36 圆角矩形底衬（`AppColors.surface` 白卡，圆角 10，图标 20pt），与搜索框等高对齐，视觉重量平衡。
- docSplit 图标 2026-07-20 由 `square.split.2x1`（形似侧栏开关，语义误导）改为 `arrow.down.doc`。

### 7.1.1 节点标题搜索行为

| 项 | 行为 |
|----|------|
| 匹配 | `title.toLowerCase().contains(query)`，**不**搜消息 / lastMessagePreview |
| 展示 | 滤树：只渲染 `visibleNodeIds`（命中 + 祖先）；保持缩进层级 |
| 算法 | `visibleNodeIdsForTitleQuery`（`tree_title_filter.dart`）；空 query → `null`（不过滤） |
| 触发 | `onChanged` live 过滤（本地过滤，无需显式提交；与笔记 tab 的显式搜索不同，见 `docs/_tmp/search-explicit-button.md`） |
| 搜索态 | 强制展开（忽略 `_collapsedIds`）；`reorderEnabled=false`（无拖拽手柄 / DragTarget） |
| 仍可用 | 点进 chat、长按重命名、swipe 删除/分支 |
| 无命中 | `l10n.treeTitleSearchNoResults`（「无匹配标题」） |
| 占位 | `l10n.treeTitleSearchHint`（「搜索节点标题」） |
| 非目标 | 全局 Search tab、FTS、`FullTreeScreen`、`searchPrefill` 深链（本次未接） |

---

## 8. 空状态 / 错误 / Loading

### 8.1 树空状态

- 主题下无任何根节点：工具行保留（可搜索 / 新建 / 导入）+ 居中 `l10n.emptyTree`
- 有节点但标题搜索无命中：搜索框保留 + `l10n.treeTitleSearchNoResults`

### 8.2 错误 / Loading

- 错误：NavBar 标题为空 + 错误文本居中
- Loading：NavBar 标题为空 + CupertinoActivityIndicator

---

## 9. 列表最大宽度约束

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

平板 / 横屏 / Mac Catalyst 时列表最大 800px 宽，居中显示。

---

## 10. ThemeDetailController

```dart
class ThemeDetailController extends AsyncNotifier<ThemeDetailState> {
  ThemeDetailController(this.themeId);
  final String themeId;

  @override
  Future<ThemeDetailState> build() async => _load();

  Future<ThemeDetailState> _load() async { ... }
  Future<void> refresh() async { ... }
  Future<void> refreshNodesOnly() async { ... }
  Future<void> createRootChatNode({required String title}) async { ... }
  Future<NodeEntity> createChildChatNode({required String parentId, required String title}) async { ... }
  Future<int> deleteNodeSubtree({required String nodeId}) async { ... }
}
```

**关键设计**：
- `autoDispose.family`：按 themeId 隔离，离开屏幕自动销毁
- `_withLastMessagePreviews`：异步读取每个节点 `session.md` 最后一条 user 消息（截前 40 字）作为副标题预览
- `refresh()` vs `refreshNodesOnly()`：前者走磁盘，后者只刷内存（拖拽后用）

---

## Test Plan

### 节点卡片视觉

1. **5 套配色**：5 个不同 nodeId 落在不同 palette index；同一 nodeId 每次打开颜色一致
2. **行高一致**：所有节点卡片高度固定 56px
3. **缩进层级**：depth 0/1/2/3 缩进 0/28/56/84px
4. **圆圈显示**：所有节点都显示 12×12 圆圈
5. **圆圈动画**：空心↔实心 AnimatedContainer 200ms easeInOut

### 拖拽重排

6. **拖拽手柄**：52×52，长按 400ms 触发
7. **Hover 指示线**：上边或下边 2.5px systemBlue
8. **跨父级拒绝**：`onWillAcceptWithDetails` 拒绝 `parentId` 不同的拖拽

### Swipe 删除

9. **左滑触发**：`onSwipeLeft` 回调
10. **确认对话框**：子树提示 + 同标题二次确认

### Swipe 分支

11. **右滑触发**：`onSwipeRight` 回调
12. **分支模式选择**：`showBranchModeSheet` 弹层

### 长按重命名

13. **长按触发**：长按节点行调 `_showRenameDialog`

---

## Assumptions

- 折叠状态（`_collapsedIds`）不持久化，每次进入主题详情页默认全部展开
- 节点拖拽**不允许跨父级**，仅支持同父级重排
- `LongPressDraggable` 400ms 延迟是手感调试结果，不要轻易改
- 节点 `sourceType` 只有 4 个枚举值：`selectedText` / `conversation` / `summary` / `note`
- 调试模式（`kDebugMode`）下删除对话框显示 nodeId——release 模式隐藏
- 节点 `lastMessagePreview` 异步加载，来自 `session.md` 最后一条 user 消息的前 40 字
- 删除节点子树时，"同标题"判定基于 `node.title` 完全匹配
- 平板 / 横屏列表最大 800px 宽（手机端自动占满）
- 典雅黑金色调：低饱和度、暖灰调，与主题列表配色协调
