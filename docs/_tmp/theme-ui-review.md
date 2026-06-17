# 主题模块 UI/UX Review — 改动方案 v2

> 生成时间：2026-06-11
> 审查技能：UI/UX Pro Max + Flutter Dev + Frontend Dev
> 最后更新：基于用户反馈修正

---

## 概念对齐

App 有 4 个 Tab：搜索 / 主题 / 笔记 / 设置。

导航路径：主题 Tab → ThemeListScreen（列出所有主题）→ 点击主题 → ThemeDetailScreen（tree 视图）→ 点击节点 → ChatScreen（对话）

用户视角："列表" = tree 视图（节点列表），不是 ThemeListScreen。
本方案聚焦 tree 视图（ThemeDetailScreen）和相关交互组件。

---

## 一、确认要做的改动

### 改动 1：Swipe 重新设计

**现状**：
- 左滑 → 删除按钮
- 右滑 → 分支按钮
- 长按 → 编辑标题对话框

**改为**：
- 左滑 → 弹出 Action Sheet，包含 3 个选项：分支 / 重命名 / 删除
- 右滑 → 移除（不再支持右滑）
- 长按 → 显示预览（改动 2）

**涉及文件**：
- `theme_detail_screen.dart` — _TreeRowView 的 SwipeableRow 配置
- `swipeable_row.dart` — 可能需要调整为只支持左滑
- 新增 `_showNodeActionSheet()` 方法

**实现细节**：
```dart
// _TreeRowView 中
SwipeableRow(
  onSwipeLeft: () => _showNodeActionSheet(context, ref, node, themeId, allNodes),
  // 移除 onSwipeRight
  leftActionLabel: l10n.actions,  // 或用 "more" 图标
  leftActionIcon: AppIcons.more,
  leftActionColor: AppColors.accent,
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => context.push('/themes/$themeId/nodes/${node.nodeId}', extra: node.title),
    onLongPress: () => _showPreview(context, node),  // 改动 2
    child: tileContent,
  ),
)

// 新增方法
Future<void> _showNodeActionSheet(
  BuildContext context, WidgetRef ref, NodeEntity node, String themeId, List<NodeEntity> allNodes,
) async {
  final l10n = AppLocalizations.of(context)!;
  final action = await showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 'branch'),
          child: Text(l10n.swipeBranch),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 'rename'),
          child: Text(l10n.renameNode),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, 'delete'),
          child: Text(l10n.delete),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: Text(l10n.cancel),
      ),
    ),
  );

  if (action == 'branch') {
    await _onCreateBranchFromMenu(context, ref, node: node);
  } else if (action == 'rename') {
    _showRenameDialog(context, ref, node, themeId, allNodes);
  } else if (action == 'delete') {
    await _handleDelete(context, ref, l10n, node: node, themeId: themeId, allNodes: allNodes);
  }
}
```

**SwipeableRow 调整**：
- 移除右滑支持（或保留但不使用）
- 左滑按钮改为显示 "更多" 或三个点图标

---

### 改动 2：长按改为显示预览

**现状**：长按节点行 → 弹出编辑标题对话框
**改为**：长按节点行 → 弹出预览卡片，显示该节点的最后消息内容

**涉及文件**：`theme_detail_screen.dart`

**实现细节**：
```dart
// _TreeRowView 中
onLongPress: () => _showPreview(context, node),

// 新增方法
void _showPreview(BuildContext context, NodeEntity node) {
  showCupertinoModalPopup(
    context: context,
    builder: (ctx) => Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(node.title, style: AppTheme.headline),
          const SizedBox(height: 8),
          Text(
            node.lastMessagePreview ?? node.sourceExcerpt ?? '',
            style: AppTheme.body.copyWith(color: AppColors.textSecondary),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.close),
            ),
          ),
        ],
      ),
    ),
  );
}
```

**预览内容**：
- 优先显示 `node.lastMessagePreview`（最后一条用户消息）
- 备选显示 `node.sourceExcerpt`（来源摘录）
- 最多 5 行，超出省略

---

### 改动 3：Subtitle 改用 lastMessagePreview

**文件**：theme_detail_screen.dart → _TreeRowView.build()

**现状**：副标题显示 sourceLabel（"来自: 笔记" / "来自: 对话"）
**改为**：优先显示 lastMessagePreview，为空时 fallback 到 sourceLabel

**注意**：用户指出 preview 内容比 sourceLabel 长很多，需要处理多行。

```dart
// 改前
Text(
  sourceLabel ?? '',
  style: AppTheme.caption1.copyWith(color: palette.subtitle),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),

// 改后
Text(
  node.lastMessagePreview ?? sourceLabel ?? '',
  style: AppTheme.caption1.copyWith(color: palette.subtitle),
  maxLines: 2,  // 允许 2 行，容纳更长的 preview
  overflow: TextOverflow.ellipsis,
),
```

**视觉影响**：
- 行高从固定 56px 可能需要调整为 min-height，或保持 56px 但允许文本截断
- 如果保持 56px，2 行 caption1 (12px * 1.5 line-height = 18px) + title (17px) + spacing 刚好能放下

---

### 改动 4：硬编码白色替换为设计 token

**文件**：theme_detail_screen.dart

**替换映射**：

| 行号 | 原值 | 替换为 | 用途 |
|------|------|--------|------|
| 74 | `CupertinoColors.white` | `AppColors.pageBg` | scaffold 背景 |
| 487 | `CupertinoColors.systemBackground` | `AppColors.surface` | 拖拽气泡底色 |
| - | `CupertinoColors.tertiaryLabel` | `AppColors.textTertiary` | 拖拽手柄颜色 |
| - | `CupertinoColors.secondaryLabel` | `AppColors.textSecondary` | 删除对话框文字 |
| - | `CupertinoColors.label` | `AppColors.textPrimary` | 对话框文字 |
| - | `CupertinoColors.separator` | `AppColors.border` | 分隔线 |
| - | `CupertinoColors.systemRed` | `AppColors.destructive` | 删除确认 checkbox |

**保留原值**（语义色）：
- `CupertinoColors.systemBlue` — 拖拽 hover 指示色
- `CupertinoColors.destructiveRed` — swipe 删除色

**暗黑模式**：在 `app_colors.dart` 中新增暗黑模式 token 定义（后续支持）。

---

### 改动 5：空状态改进

**现状**：当主题没有节点时（roots.isEmpty），只显示一行文字 `l10n.emptyTree`
**改为**：与主题列表空状态风格一致，显示 icon + 引导文案

```dart
roots.isEmpty
  ? Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.chat, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              l10n.emptyTree,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () async {
                final title = await _promptRootTitle(context);
                if (title == null) return;
                await ref.read(themeDetailControllerProvider(widget.themeId).notifier).createRootChatNode(title: title);
              },
              child: Text(l10n.newSession),
            ),
          ],
        ),
      ),
    )
```

**改进点**：
- 添加 chat icon（40px，textTertiary）
- 添加引导按钮"新建对话"（CupertinoButton.filled）
- 文案改为 `l10n.emptyTree`（保持原样，但视觉更丰富）

---

### 改动 6：SwipeableRow 左边缘检测

**文件**：lib/ui/core/widgets/swipeable_row.dart

**问题**：右滑（创建分支）与 iOS 系统返回手势（左边缘右滑）冲突
**方案**：在 _onPanUpdate 中检测触摸起始位置，左边缘 20pt 内不拦截水平滑动

**注意**：根据改动 1，右滑已移除，但左滑仍需处理与系统手势的冲突（从左边缘左滑可能触发系统手势）。

```dart
double _panStartX = 0;

// 新增
void _onPanStart(DragStartDetails details) {
  _panStartX = details.globalPosition.dx;
}

void _onPanUpdate(DragUpdateDetails details) {
  // 左边缘 20pt 内，让给系统手势
  if (_panStartX < 20) return;
  // ... 原有逻辑
}
```

需要把 GestureDetector 的 onHorizontalDragUpdate 拆成 onHorizontalDragStart + onHorizontalDragUpdate。

---

### 改动 7：拖拽反馈气泡加主题色

**文件**：theme_detail_screen.dart → _DragHandle → feedback

**现状**：纯白底 + 黑色 shadow
**改为**：左侧加主题色条（3px），暗示"这个节点属于哪个主题"

```dart
feedback: Container(
  decoration: BoxDecoration(
    color: AppColors.surface.withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(10),
    border: Border(
      left: BorderSide(
        color: AppColors.colorForTheme(widget.node.themeId),
        width: 3,
      ),
    ),
    boxShadow: [
      BoxShadow(
        color: CupertinoColors.black.withValues(alpha: 0.2),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Text(widget.node.title, ...),
)
```

---

### 改动 8：重命名对话框取消按钮

**文件**：theme_detail_screen.dart → _showRenameDialog()

**改前**：
```dart
CupertinoDialogAction(
  isDestructiveAction: true,  // 红色，语义错误
  onPressed: () => Navigator.of(ctx).pop(),
  child: Text(l10n.cancel),
),
```

**改后**：
```dart
CupertinoDialogAction(
  onPressed: () => Navigator.of(ctx).pop(),
  child: Text(l10n.cancel),
),
```

去掉 `isDestructiveAction: true`。取消不是破坏性操作。

---

### 改动 9：移除 debugPrint

**文件**：theme_detail_screen.dart → _handleReorder()

**现状**：8 条 `debugPrint('[REORDER] ...')` 未被 kDebugMode 守护
**方案**：全部删除或包裹在 assert 中

**用户反馈**：不要碰，APP publish 后就没问题。
**决定**：保留不动。

---

## 二、确认不做 / 降级处理的项

| 原方案项 | 决定 | 原因 | 归档位置 |
|---------|------|------|----------|
| 递归 _TreeRowView 改拍平 | 降级：加 4 层深度上限 | 当前方案够用，超过 4 层的节点不渲染子节点 | TECH-DEBT.md |
| _withLastMessagePreviews 串行改并行 | 暂不做 | 当前只有进入详情页时加载，且 preview 数据本身就不急需 | TECH-DEBT.md |
| RepaintBoundary | 暂不做 | 4 层深度上限后 widget 数量可控 | TECH-DEBT.md |
| 折叠状态持久化 | 暂不做 | 需要跨 session 存储，优先级低 | TECH-DEBT.md |
| expand/collapse all | 暂不做 | 可以后续迭代 | TECH-DEBT.md |
| ThemeListScreen 改进 | 暂不做 | 用户不认为这是重要页面 | - |

---

## 三、实施顺序

1. **改动 8**（取消按钮语义）— 1 分钟，独立
2. **改动 4**（替换硬编码白色）— 5 分钟，独立
3. **改动 3**（subtitle 用 lastMessagePreview）— 5 分钟
4. **改动 5**（空状态改进）— 3 分钟
5. **改动 6**（左边缘检测）— 10 分钟，SwipeableRow 通用改动
6. **改动 7**（拖拽气泡主题色）— 5 分钟
7. **改动 1 + 2**（Swipe 重新设计 + 长按预览）— 25 分钟，联动改动

预计总工时：约 50 分钟

---

## 四、待确认

1. **SwipeableRow 左滑按钮**：改为"更多"图标（三个点）还是保留"删除"图标？建议用"更多"因为现在左滑弹出的是 action sheet 而不是直接删除。

2. **Action Sheet 样式**：用 `CupertinoActionSheet`（iOS 原生样式）还是自定义样式？

3. **预览卡片**：是 modal popup（点击外部关闭）还是 tooltip 样式（自动消失）？

4. **暗黑模式 token**：现在就定义暗黑模式颜色，还是后续单独做？
