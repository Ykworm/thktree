# 主题模块设计参考

> **修改前先读这里**：本目录是"主题（Theme）"模块的当前态设计参考。涉及节点卡片视觉、对话树渲染、主题色分配、拖拽/swipe 交互时，先读本目录再下手。

## Summary

主题模块是 ThkTree 的"组织容器"——把多条对话（Node）按"主题"分组，主题下形成树形对话网络（多分支、可嵌套）。本目录记录：

- `ThemeListScreen`：主题列表（按主题浏览）
- `ThemeDetailScreen`：主题内对话树（树形节点 + 拖拽排序 + swipe 分支/删除 + 长按重命名）

**核心设计语言**：节点卡片使用 **5 套双色配色**（圆圈 + 标题 + 副标题），基于 `nodeId.hashCode` 稳定分配；拖拽/swipe 颜色跟随主题色（不跟随节点色）。整套设计遵循 [design-system.md](../../../_shared/design-system.md) 的色彩/字体令牌。

---

## 屏幕地图

```
┌──────────────────────────────────────────────────────────┐
│ TabBar:  [主题]   笔记    搜索    设置                      │
└──────────────────────────────────────────────────────────┘
                     │
                     ▼
         ┌─────────────────────────┐
         │ ThemeListScreen          │
         │ ───────────────────      │
         │ 标题: "主题"              │
         │ Trailing: ↻  +           │
         │ ───────────────────      │
         │  ┌────────────────────┐  │
         │  │▎📁 主题 A       > │  │  ← 3px 主题色书脊线
         │  ├────────────────────┤  │
         │  │▎📁 主题 B       > │  │
         │  ├────────────────────┤  │
         │  │▎📁 未分类         > │  │
         │  └────────────────────┘  │
         │   (空: accountTree icon)  │
         └─────────────────────────┘
                     │
                     │ /themes/:themeId/tree
                     ▼
         ┌─────────────────────────┐
         │ ThemeDetailScreen        │
         │ ───────────────────      │
         │ NavBar: ← "主题 A 的会话"  ↻  +
         │ ───────────────────      │
         │ ●  节点 1                  │  ← 空心圆（展开）
         │   来自: 笔记                │
         │      ●  分支 1.1            │  ← depth+1, 缩进 28px
         │      ●  分支 1.2            │
         │ ●  节点 2                  │
         │   来自: 对话                │
         │ ●  节点 3                  │
         │ ───────────────────      │
         │  [长按重命名 | swipe 分支/删除 | 拖拽重排] │
         └─────────────────────────┘
```

**子页面 / 弹层（无新屏幕，但有交互分支）**：

- **新建根节点**：右上 + 按钮 → `CupertinoAlertDialog` 输入标题 → `themeDetailController.createRootChatNode()`
- **长按重命名**：长按节点行 → `CupertinoAlertDialog` 输入新标题 → `nodeStore.updateNodeTitle()` → `refresh()`
- **swipe 右滑（分支）**：`showBranchModeSheet()` → `showBranchFlow(mode, parentTranscript, themeId, parentNodeId)`
- **swipe 左滑（删除）**：`_confirmDeleteNode` 确认对话框（带"同标题其他节点"二次确认）→ `deleteNodeSubtree()`
- **拖拽手柄**（最右侧 ⋮⋮ 图标）：`LongPressDraggable` + 400ms 延迟 + 拖到目标 → `_handleReorder()` 重新计算 `sortOrder`

---

## 共享设计原则

### 1. 路由约定

| 路径 | 屏幕 | 来源 |
|------|------|------|
| `/themes` | ThemeListScreen | go_router Tab |
| `/themes/:themeId/tree` | ThemeDetailScreen | context.push 推入 |
| `/themes/:themeId/nodes/:nodeId` | 进入对话（chat） | context.push，extra=node.title |

主题 ID 使用 `themeId`（string，磁盘目录名），不要误用 `themeTitle` 做路由参数。

### 2. 主题色系统

来自 `AppColors.colorForTheme(themeId) / tintForTheme(themeId)`，5 色循环（skyBlue / mint / lavender / coral / amber），见 [design-system.md](../../../_shared/design-system.md)。

**适用范围**：

| 元素 | 颜色来源 | 说明 |
|------|----------|------|
| 主题列表左侧书脊线（3px） | `colorForTheme(themeId)` | 每个主题一种 |
| `ThkListTile.leading` 图标背景 | `tintForTheme(themeId)` | 浅色 15% tint |
| `ThkListTile.leading` 图标颜色 | `colorForTheme(themeId)` | |
| 节点卡片圆圈 / 标题 / 副标题 | **5 套 `_NodePalette`（基于 nodeId hash）** | **不跟主题色** |
| DragTarget hover 背景 | `tintForTheme(themeId)` | 跟主题色 |
| 拖拽指示线 | `colorForTheme(themeId)` | 跟主题色 |
| swipe 左滑（删除） | `destructiveRed` | 系统语义色 |
| swipe 右滑（分支） | `colorForTheme(themeId)` | 跟主题色 |

**关键差异**：节点卡片用 5 套**节点级**配色（双色调色板，圆圈+标题+副标题），跟主题色解耦；列表/拖拽/swipe 用**主题级**色。

### 3. 节点配色系统（`_NodePalette`）

5 套双色配色方案（见 [theme-detail-design.md 第 1 节](theme-detail-design.md)），通过 `nodeId.hashCode.abs() % 5` 稳定分配：

| Index | 圆圈 | 标题 | 副标题 | 风格 |
|-------|------|------|--------|------|
| 0 | 电蓝 `#3B82F6` | 深紫 `#1E1B4B` | 靛蓝 `#6366F1` | electric |
| 1 | 翠绿 `#10B981` | 深玫瑰 `#881337` | 珊瑚 `#EA580C` | 暖色 |
| 2 | 紫罗兰 `#8B5CF6` | 深青 `#134E4A` | 海蓝 `#0369A1` | 冷色 |
| 3 | 热粉 `#EC4899` | 深靛 `#312E81` | 翡翠 `#0D9488` | 粉冷对比 |
| 4 | 琥珀 `#FBBF24` | 深板岩 `#0F172A` | 紫蓝 `#7C3AED` | 复古 |

**配色规则**：

- 同一节点每次打开颜色一致（hash 稳定）
- 标题/副标题颜色均为深色，白底对比度 ≥ 4.5:1（WCAG AA）
- 圆圈颜色作 12×12 视觉标记 + 2px border + 浅色底（alpha 0.15）
- **不**做运行时动态生成；预设 5 套够用

### 4. 状态管理

| Provider | 类型 | 触发位置 | 用途 |
|----------|------|----------|------|
| `themeListControllerProvider` | `AsyncNotifier<List<ThemeEntity>>` | ThemeListScreen 顶部 | 主题列表数据源 |
| `themeDetailControllerProvider(themeId)` | `AsyncNotifierProvider.autoDispose.family` | ThemeDetailScreen | 主题内节点树（按 themeId 隔离） |

**刷新约定**：

| 场景 | 调用的方法 | 是否触发磁盘 reindex |
|------|-----------|---------------------|
| 进入主题详情 | `build()` | 是（`reindexThemesFromDisk` + `reindexNodesFromDisk`） |
| NavBar 右上 ↻ 按钮 | `refresh()` | 是 |
| 拖拽重排后 | `refreshNodesOnly()` | **否**（仅刷内存顺序） |
| 新建/删除节点 | `state = AsyncData(await _load())` | 是 |
| 重命名节点 | `refresh()`（从 rename dialog 调） | 是 |

### 5. 跨屏刷新契约

- 主题详情页内的操作（新建/删除/重命名/拖拽）**只**调自己的 `themeDetailControllerProvider` 方法，详情页自动刷新
- 主题列表与详情之间的跨屏刷新：删除/重命名**不**回写主题列表（不修改 theme.title），所以列表无需监听
- 如果未来有"重命名主题"功能，列表侧需要手动调 `ref.invalidate(themeListControllerProvider)`

### 6. 国际化文案（l10n 关键 key）

| Key | 用途 | 屏幕 |
|-----|------|------|
| `themesTabLabel` | TabBar 标签 | 列表 |
| `newTheme` | 新建主题对话框标题 | 列表 |
| `noThemesYet` | 空状态文案 | 列表 |
| `treeTitle(themeTitle)` | 详情 NavBar 标题 | 详情 |
| `emptyTree` | 树空状态文案 | 详情 |
| `renameNode` | 重命名对话框标题 | 详情 |
| `enterNewTitle` | 重命名 placeholder | 详情 |
| `deleteItem` | 删除确认标题 | 详情 |
| `deleteConfirm(title)` | "确认删除 [title]?" | 详情 |
| `deleteDescWithChildren(n)` | "会同时删除 n 个子节点" | 详情 |
| `deleteDescOnly` | "无子节点" | 详情 |
| `keptSameTitleNodes(n)` | "有 n 个同标题节点保留" | 详情 |
| `deleteUnderstand` | 二次确认 checkbox 文案 | 详情 |
| `swipeDelete` | 左滑按钮文案 | 详情 |
| `swipeBranch` | 右滑按钮文案 | 详情 |
| `newSession` | 新建根节点对话框标题 | 详情 |
| `titleHint` | 标题 placeholder | 列表/详情通用 |
| `sourceTypeSelectedText` | 节点副标题：选中文本 | 详情 |
| `sourceTypeConversation` | 节点副标题：对话 | 详情 |
| `sourceTypeSummary` | 节点副标题：摘要 | 详情 |
| `sourceTypeNote` | 节点副标题：笔记 | 详情 |
| `deletedCount(n)` | 删除成功 toast | 详情 |
| `deleteFailed(reason)` | 删除失败 toast | 详情 |
| `branchFailed(reason)` | 分支失败 toast | 详情 |
| `targetNodeId(id)` | 调试模式显示 nodeId | 详情 |
| `cancel` / `create` / `save` / `delete` / `OK` | 通用按钮 | 全局 |

---

## 子文档索引

| 文档 | 范围 | 行数预估 |
|------|------|----------|
| [theme-list-design.md](theme-list-design.md) | ThemeListScreen 全部 + ThemeListController | ~250 行 |
| [theme-detail-design.md](theme-detail-design.md) | ThemeDetailScreen 全部 + 节点卡片视觉 + 5 套配色 + 拖拽/swipe/重命名/删除 | ~900 行 |

---

## 实现文件清单

| 文件 | 角色 | 大小 |
|------|------|------|
| `lib/ui/features/themes/theme_list_screen.dart` | 主题列表屏幕 | 149 行 |
| `lib/ui/features/themes/theme_list_controller.dart` | 主题列表 controller（listThemes / createTheme / reindex） | 28 行 |
| `lib/ui/features/themes/theme_detail_screen.dart` | 主题详情屏幕 + _NodePalette + _TreeRowView + _DragHandle + 拖拽/swipe/重命名/删除 | 906 行 |
| `lib/ui/features/themes/theme_detail_controller.dart` | 主题详情 controller（load / refresh / refreshNodesOnly / CRUD） | 148 行 |
| `lib/ui/features/notes/note_browse_screen.dart` | 共享 `localizedThemeTitle()` 工具（"未分类"本地化） | — |
| `lib/ui/core/shared/title_suggestion_screen.dart` | 智能命名建议弹层（重命名时调用） | — |
| `lib/ui/core/widgets/widgets.dart` | `ThkNavBar` / `ThkListTile` / `ThkTextField` / `SwipeableRow` 等共享 widget | — |
| `lib/ui/core/theme/app_colors.dart` | 设计令牌（含 `colorForTheme` / `tintForTheme`） | — |
| `lib/ui/core/theme/app_theme.dart` | 字体/字号（`AppTheme.body` / `caption1`） | — |
| `lib/ui/core/theme/app_icons.dart` | 图标（`folder` / `accountTree` / `back` / `add` / `refresh` 等） | — |

---

## Test Plan

1. **主题列表**
   - 0 个主题：空状态（accountTree icon + noThemesYet）
   - 1+ 个主题：每个 ThkListTile 显示 themeId 哈希分配的书脊线色
   - + 按钮：弹 CupertinoAlertDialog 输入标题 → 创建后列表自动刷新
   - ↻ 按钮：重新从磁盘索引（不创建新主题）
   - 调试模式 subtitle 显示 themeId

2. **主题详情**
   - 树空：emptyTree 文案
   - 树非空：所有根节点按 sortOrder 升序排列
   - 缩进：每层 28px
   - 圆圈：所有节点都显示 12×12 圆圈（无子节点也显示但不可点）
   - 圆圈颜色：5 套配色基于 nodeId hash 稳定
   - 展开/折叠：AnimatedContainer 200ms 切换空心↔实心
   - 副标题（sourceLabel）：按 sourceType 显示对应本地化文案
   - NavBar ↻：重新从磁盘索引
   - NavBar +：弹 CupertinoAlertDialog 创建根节点

3. **节点交互**
   - **点击行**：`/themes/:themeId/nodes/:nodeId` 进入对话
   - **长按行**：弹重命名对话框 → 保存后调 `refresh()`，副标题/列表自动更新
   - **swipe 左滑**：弹删除确认对话框（带子树提示）→ 确认后 `deleteNodeSubtree` + toast
   - **swipe 右滑**：弹分支模式选择 → showBranchFlow 创建新分支
   - **拖拽手柄**（长按 400ms 触发）：
     - 拖到同父级其他节点：触发 `_handleReorder`，重新计算 sortOrder
     - 拖到不同父级：**不允许**（onWillAcceptWithDetails 拒绝 `parentId` 不同的拖拽）
     - 拖动时显示 280×max 圆角气泡（surface + 黑色 20% shadow）
     - 拖到无效区域：自动回弹（`onDraggableCanceled`）
   - **同标题删除确认**：当有同标题节点不在子树内时，弹确认 checkbox，未勾选时"删除"按钮 disabled

4. **状态管理**
   - `themeListControllerProvider`：仅一个全局实例
   - `themeDetailControllerProvider(themeId)`：按 themeId 隔离，autoDispose（离开屏幕后销毁）
   - 拖拽后用 `refreshNodesOnly` 而不是 `refresh`，避免不必要的磁盘 reindex

5. **跨屏刷新**
   - 主题详情页内的 CRUD 不影响主题列表
   - 重命名节点不修改 theme.title，列表无需刷新

6. **性能**
   - 100+ 节点列表滑动顺畅（ListView.separated + 56px 固定行高）
   - 拖拽气泡动画 60fps

7. **设计令牌合规**
   - `rg "CupertinoColors.white|CupertinoColors.systemBackground|CupertinoColors.label|CupertinoColors.tertiaryLabel" lib/ui/features/themes/` 返回 0（除 systemRed / destructiveRed / systemBlue 这种系统语义色）
   - 节点圆圈/标题/副标题颜色用 `_NodePalette` 常量
   - 拖拽/swipe 颜色用 `colorForTheme` / `tintForTheme`

---

## Assumptions

- `uses-material-design: false` 保持不变
- 折叠状态（`_collapsedIds`）不持久化，每次进入主题详情页默认全部展开
- `AppColors.colorForTheme(themeId)` 和 `_NodePalette` 互不耦合：主题色用于"容器层"（列表/拖拽/swipe），节点色用于"内容层"（卡片视觉）
- 节点拖拽**不允许跨父级**（不实现 move-to-parent），仅支持同父级重排
- `LongPressDraggable` 400ms 延迟是手感调试结果，不要轻易改
- 节点 `sourceType` 只有 4 个枚举值：`selectedText` / `conversation` / `summary` / `note`；其他值副标题不显示
- 调试模式（`kDebugMode`）下 ThkListTile subtitle 显示 themeId，节点删除对话框显示 nodeId——release 模式隐藏
- 节点 `lastMessagePreview` 异步加载（不影响首屏渲染），来自 `session.md` 最后一条 user 消息的前 40 字
- 删除节点子树时，"同标题"判定基于 `node.title` 完全匹配
- 不做深色模式适配

---

## 相关历史

- **2026-06-07**：原 `docs/visual/conversation-tree-design-plan.md`（单点重构方案）重构为模块设计参考（README + 2 子文档）
  - 原内容：节点卡片重构方案（5 套配色 + 圆圈交互 + 拖拽/swipe 颜色 + Test Plan）
  - 新位置：本目录 [README.md](README.md) + [theme-detail-design.md 第 1 节-4](theme-detail-design.md)
- **2026-06-06**：`docs/visual/warm-minimal-design-plan.md`：暖色调 → 蓝靛渐变视觉重构（已实施；色彩令牌已合入 [`../../../_shared/design-system.md`](../../../_shared/design-system.md)）
