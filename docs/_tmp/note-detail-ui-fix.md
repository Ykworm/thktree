# NoteDetailScreen UI 修复 + GptMarkdown 主题修复

> 目标：修复笔记详情页所有 UI 问题，包括 GptMarkdown 标题样式、导航栏、内容区布局、overflow menu 样式。
> 方法：全局修复 GptMarkdown 主题 + 重构导航栏 + 内容区布局修复 + 网格底栏替换 ActionSheet。

---

## 问题清单与状态

### 问题 1：GptMarkdown 标题样式失效（根因）
- **现象**：`# 标题` 渲染为正文大小
- **根因**：CupertinoApp 不提供 Material text theme
- **状态**：✅ 已修复（main.dart GptMarkdownTheme）

### 问题 2：h1 标题下方自动插入横线
- **现象**：`# 逻辑` 下方多了一条分隔线
- **根因**：`GptMarkdownThemeData.autoAddDividerLineAfterH1` 默认 true
- **修复**：设置为 false
- **状态**：✅ 已修复

### 问题 3：导航栏标题冗余
- **状态**：✅ 已修复

### 问题 4：操作按钮过多 + 样式不够直观
- **修复**：CupertinoActionSheet → 网格底栏
- **状态**：✅ 已修复

### 问题 5：反击号高亮颜色异常
- **状态**：✅ 已修复

### 问题 6：内容区未填满页面
- **现象**：只有文字部分有背景色，下方大片空白
- **根因**：`Container` 包裹 `SingleChildScrollView`，高度随内容收缩
- **修复**：用 `Column` + `Expanded` 让 Container 撑满父容器
- **状态**：⏳ 待实现

---

## 已完成改动
- `lib/main.dart` — GptMarkdownTheme（h1/h2/h3 + highlightColor）
- `lib/ui/features/notes/note_detail_screen.dart` — 导航栏去掉标题 + "..." 按钮

---

## 已完成改动（本轮）

### 改动 1：关闭 h1 自动横线（`lib/main.dart`）
```dart
autoAddDividerLineAfterH1: false,
```

### 改动 2：内容区填满页面（`note_detail_screen.dart` → `_buildBody`）
将非编辑态的返回值从：
```dart
return Container(
  color: AppColors.surface,
  child: SingleChildScrollView(...),
);
```
改为：
```dart
return Column(
  children: [
    Expanded(
      child: Container(
        color: AppColors.surface,
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: GptMarkdown(
            _body,
            style: TextStyle(fontSize: 17, height: 1.6),
          ),
        ),
      ),
    ),
  ],
);
```

### 改动 3：新建 ThkGridBottomSheet（WeChat/备忘录风格网格底栏）

**文件**：`lib/ui/core/widgets/thk_grid_bottom_sheet.dart`（新建）
**导出**：`lib/ui/core/widgets/widgets.dart` 添加 export

**数据模型**：
```dart
class GridAction {
  const GridAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
}
```

**Widget 结构**：
- `showModalBottomSheet` + `ClipRRect(topLeft: 16, topRight: 16)`
- 背景 `AppColors.surface`
- `Column`：
  - Section 1：`GridView.count(crossAxisCount: 4)` — 主操作（复制、重命名）
  - 8px 灰色间隔条
  - Section 2：`GridView.count(crossAxisCount: 4)` — destructive 操作（删除）
  - 取消按钮：全宽、居中、顶部分隔线

**每个 action item**：
- `GestureDetector` > `Column`
- 圆形图标容器（44px，背景色 10% opacity tint）
- `Text` 标签（12px，`AppColors.textPrimary`）

**静态方法**：
```dart
static Future<void> show({
  required BuildContext context,
  required List<GridAction> actions,
  List<GridAction>? destructiveActions,
  String cancelLabel = '取消',
})
```

### 改动 4：替换 _showMoreActions（`note_detail_screen.dart`）
```dart
ThkGridBottomSheet.show(
  context: context,
  actions: [
    GridAction(label: l10n.copy, icon: AppIcons.copy, color: AppColors.accent, onPressed: _copyAll),
    GridAction(label: l10n.renameNote, icon: AppIcons.edit, color: AppColors.textSecondary, onPressed: _renameNote),
  ],
  destructiveActions: [
    GridAction(label: l10n.delete, icon: AppIcons.delete, color: CupertinoColors.systemRed, onPressed: _deleteNote),
  ],
);
```

---

## Test Plan

- `# 标题` 渲染为大号 h1，下方无横线
- 内容区背景填满整个页面（无底部空白）
- 点击 "..." 弹出网格底栏，圆形图标 + 文字
- Copy/Rename/Delete 回调正常
- 取消按钮关闭底栏
- 删除图标为红色
- 深色/浅色模式均正常

---

## Assumptions
- `ThkActionSheet` 保持不动
- 使用 AppIcons 已有 SF Symbols 图标
- 圆形图标背景色 = action color × 10% opacity
- 3 个 action 用单行 4 列 grid

---

## 追加改动：MarkdownToolbar 修复 + 增强

### 问题 7：标题按钮逻辑 bug
- **现象**：多次点击标题按钮，行首变成 `## ## ## ## ...`
- **原因**：`_insertAtLineStart('## ', '')` 不检测当前行是否已有标题前缀
- **修复**：实现标题级别循环切换逻辑：
  - 无前缀 → `## ` (h2) — 默认 h2，因为 h2 是笔记正文最常用的标题级别
  - `## ` → `### ` (h3)
  - `### ` → `# ` (h1)
  - `# ` → 移除前缀（取消标题）
  - `#### ` 等未知级别 → 重置为 `## `
- **循环顺序**：无 → h2 → h3 → h1 → 无（参考 Notion/Typora 默认行为）
- **实现位置**：修改 `MarkdownToolbar._insertAtLineStart` 方法，约 20 行代码
- **状态**：✅ 已修复

### 问题 8：缺少表格插入按钮
- **修复**：新增表格按钮，点击插入 3x3 markdown 表格模板：
  ```
  | 列1 | 列2 | 列3 |
  | --- | --- | --- |
  |  |  |  |
  |  |  |  |
  ```
- **状态**：✅ 已修复

### 问题 9：图片插入（暂不实现）
- **状态**：📝 待实现（另建文档跟踪）

---

## 完成状态

1. 关闭 h1 自动横线（main.dart）
2. 内容区填满页面（note_detail_screen.dart）
3. ThkGridBottomSheet 网格底栏（新建 widget）
4. 替换 _showMoreActions 使用网格底栏
5. 标题按钮循环切换逻辑（markdown_toolbar.dart）
6. 表格插入按钮（markdown_toolbar.dart）
