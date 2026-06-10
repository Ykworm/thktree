# 主题模块（themes）

> 主题是 ThkTree 的**第一层组织单元**——每个主题是一棵对话树（Theme → Root Node → 嵌套子节点）。本模块覆盖主题列表 + 主题详情（树视图）两个屏幕。
> 维护者：人类 + AI 共同维护。AI 改代码时同步更新 visual/ 文档。

> ⚠️ **AI 改模块前必读**
> 1. **节点色与主题色完全解耦**——节点色走 `lib/ui/core/theme/node_colors.dart`，主题调色板走 `lib/ui/core/theme/app_colors.dart`；改色不是改一个变量。
> 2. **设计文档是 source of truth**——颜色/字号/间距改前先看 [`docs/_shared/design-system.md`](../../_shared/design-system.md)，不要从代码反推规范。
> 3. **树视图操作**（拖拽/分支/删除/重命名）的手势逻辑是 `ThemeDetailController` 唯一的，请勿在 widget 里加状态。
> 4. visual/ 下的截图 + 设计 spec 与代码一同更新，AI 改完代码也要检查 visual 是否需要同步。

## 1. 职责

| 屏幕 | 职责 |
|------|------|
| **ThemeListScreen** | 所有主题的列表视图（CRUD 入口） |
| **ThemeDetailScreen** | 单个主题的**树视图**（节点渲染、拖拽、swipe、分支、删除、重命名） |

## 2. 功能列表

> 完整状态见 [`../../FEATURES.md`](../../FEATURES.md) § 1.

| Feature | 状态 | 最后更新 | 备注 |
|---------|------|----------|------|
| 多主题管理 | ✅ 完成 | 2026-06-06 | ThemeListScreen, ThemeStore, CRUD |
| 树形 Session | ✅ 完成 | 2026-06-06 | 嵌套渲染, parentId |
| 树形节点卡片设计 | 🔨 进行中 | 2026-06-07 | 5 套配色方案，行高 56px |
| 子孙视图过滤 | 🔨 进行中 | — | 基础树已有，过滤未完整 |
| 汇总预览 | 📋 待开发 | — | 未实现 |
| 祖先上下文总结 | 🔨 部分实现 | — | context-summary.md 写入存在 |

## 3. 代码文件

```
lib/ui/features/themes/
├── theme_list_screen.dart          # 149 行：主题列表
├── theme_list_controller.dart      # 28 行：AsyncNotifier<List<Theme>>
├── theme_detail_screen.dart        # 905 行：树视图（最大文件）
└── theme_detail_controller.dart    # 148 行：AsyncNotifier.family<ThemeDetailState, String>
```

依赖：
- `lib/data/stores/theme_store.dart`、`node_store.dart`
- `lib/data/services/session_markdown.dart`（异步加载 lastMessagePreview）
- `lib/ui/core/widgets/`（ThkListTile、ThkNavBar、SwipeableRow）

## 4. 子文档

| 文档 | 路径 | 说明 |
|------|------|------|
| **Visual 索引** | [visual/README.md](visual/README.md) | 视觉设计入口 |
| 主题列表设计 | [visual/theme-list-design.md](visual/theme-list-design.md) | ThemeListScreen 全屏设计 |
| 主题详情设计 | [visual/theme-detail-design.md](visual/theme-detail-design.md) | ThemeDetailScreen + 5 套节点配色 + 所有交互 |

## 5. 关键设计原则

### 5.1 节点色 vs 主题色（**解耦**）

- **节点色**（圆圈/标题/副标题）：由 `nodeId.hashCode.abs() % 5` 稳定分配，5 套 `_NodePalette`（详情见 visual 文档）。同一节点永远同色。
- **主题色**（书脊线/强调）：由 `themeId` 决定（`AppColors.colorForTheme` / `tintForTheme`，5 色循环）。

两者互不影响：换主题色不破坏节点色辨识度。

### 5.2 树形交互

- **层级表达**：纯缩进（`depth × 28px`），无连接线（Apple Notes 风格）。
- **行高**：固定 56px，标题 `maxLines=1` + 省略号。
- **折叠状态**：`_collapsedIds` 仅存 State，**不持久化**。
- **跨父级拖拽**：`onWillAcceptWithDetails` 拒绝（仅同级重排）。
- **删除二次确认**：同标题节点时弹 checkbox 二次确认。

### 5.3 缩略预览

`_withLastMessagePreviews()` 异步从 `session.md` 读取最后一条 user 消息前 40 字，作为节点副标题。

## 6. 维护要点

- **新增屏幕**：在 `lib/ui/features/themes/` 加 screen + controller，并在本 README § 3 更新文件清单。
- **改交互逻辑**：**必须**同步更新 `visual/theme-detail-design.md` 对应章节（设计文档是 source of truth）。
- **5 套配色变更**：在 `theme_detail_screen.dart` 改 `_nodePalettes` 常量，**同时**在 visual 文档更新色值表。
- **AI 改代码时**：AI 识别到变动后应**主动**提醒用户检核 FEATURES.md 状态列是否需更新。

## 7. 相关历史

- **2026-06-07** — 节点卡片重构：从 chevron 改为圆圈 toggle，5 套配色，行高 56px
- **2026-06-07** — 节点圆圈改为所有节点均显示空心圆（叶子节点不可点击），圆圈与标题间距缩至 0px
- **2026-06-07** — visual 文档从 `docs/visual/themes/` 迁至 `docs/modules/themes/visual/`
