# Chat Page 面包屑导航优化

> 状态：已实现（freemode，主仓库直接改，未走 worktree）
> 日期：2026-07-11

## 背景与目标

1. 面包屑布局与空间优化：左对齐 / 长 title 换行浪费空间 / tree 深度上限 4 层。
2. 面包屑跳转后 title 显示异常：点面包屑进入新 chat page，标题显示成 `thm_xxx/nd_xxx`（内部 ID）。

## 决策（用户全选推荐项）

- **Q1 title bug**：导航栏标题与面包屑当前段改为**从磁盘节点数据派生**，与"怎么进来的"解耦。
- **Q2 深度计数**：根 = 第 1 层，最深第 4 层；面包屑固定两段（主题 Tab / 主题名）不计入深度。
- **Q3 超限行为**：达最大深度时**禁用分支入口 + 提示**（SwipeableRow 的 onSwipeRight 置 null 即自动隐藏 action）。
- **Q4 换行收敛**：每段长 title 用 **ellipsis 截断**（maxWidth 160 + 单行省略号），配合深度限制压在 ≤3 行。
- 排除左右滑动方案（交互不够简约）。

## 根因分析

### title 显示 ID

- 导航栏主标题：`_displayedTitle ?? widget.title`（`chat_screen.dart:412`）。
- `_displayedTitle` 仅 auto-title 任务完成后才赋值，页面刚加载为 null。
- `widget.title` 来自 router extra；面包屑跳转走 `GoRouter.go(path)` **不传 extra**
  （`thk_breadcrumb_nav.dart:102`），router 缺 extra 时回退到 `'$themeId/$nodeId'`
  （`router.dart:92-94`）→ 显示 `thm_xxx/nd_xxx`。
- 面包屑自身的当前段早已防御性地改用磁盘 `current.title`，但导航栏主标题漏改。

### 深度限制

- 全项目原无任何深度限制。
- 所有新建节点都汇流到 `node_store.createChatNode`（接收 `parentId`），
  是创建侧唯一把关点。
- reparent 侧仅 `node_location_picker`（笔记转对话可改 parentId）会改变深度；
  `reorderNode` 只改同级 sibling，深度不变，无需管。

## 改动清单

### 1. 修复 title bug — `lib/ui/features/chat/chat_screen.dart`

- 新增实例字段 `_currentTitle`，在 `build` 中由 `themeDetailControllerProvider`
  数据派生（当前节点真实 title）：`data.nodes.where(nodeId==widget.nodeId).firstOrNull?.title`。
- 导航栏主标题：`_displayedTitle ?? _currentTitle ?? widget.title`（:412）。
- `_buildCrumbs` 当前段：直接用磁盘 `current.title`（:774，不再依赖 `widget.title`）。
- `_buildCrumbs` 的 `current==null` 兜底：优先 `_currentTitle ?? widget.title`（:735）。

### 2. 深度限制（store 层）— `lib/domain/node.dart` + `lib/data/stores/node_store.dart`

- `domain/node.dart`：
  - `const int kMaxNodeDepth = 4;`
  - `int computeNodeDepth(Map<String,NodeEntity> byId, String nodeId)`（沿 parentId 回溯，防环）。
  - `class MaxNodeDepthExceededException implements Exception`（携带 `depth`）。
- `node_store.createChatNode`：parent 解析后，用 `listNodes(themeId)` 建 byId，
  算 `parentDepth`，若 `parentDepth + 1 > kMaxNodeDepth` 抛 `MaxNodeDepthExceededException`。
  覆盖：子对话 / 分支 / 文档拆分 / 笔记转对话 / 合并创建 全部入口。

### 3. 深度超限 UI 反馈

- `theme_detail_screen._TreeRowView`：用 `computeNodeDepth` 算 `atMaxDepth`，
  达上限时 `onSwipeRight` 置 null（SwipeableRow 自动隐藏 Branch action）（:508）。
- `node_location_picker._selectLocation`：选非 root 父节点时校验深度，
  超限则 `ThkAlert` 提示 `maxNodeDepthReached` 且不选。
- 创建侧 catch（`title_suggestion_screen` 两处、`note_detail_screen` 一处）：
  捕获 `MaxNodeDepthExceededException` 显示 `maxNodeDepthReached` 友好文案，
  不再把内部异常类名抛给用户。

### 4. 面包屑 ellipsis 截断 + 左对齐 — `lib/ui/core/widgets/thk_breadcrumb_nav.dart` + `chat_screen.dart`

- `thk_breadcrumb_nav._segment`：外层 `ConstrainedBox(maxWidth: 160)` + `Text(maxLines:1, overflow: ellipsis)`，长 title 单段截断。
- **左对齐修复（关键）**：面包屑所在的 `Column` 默认 `crossAxisAlignment.center`，
  非 Expanded 的面包屑 `Container` 会收缩到 `Wrap` 内容宽度并**整体横向居中**
  （叠加对称 `padding:16` → 视觉上像 Wrap 居中、浪费右侧空间）。
  - `chat_screen.dart` 面包屑 `Container` 加 `width: double.infinity` + `alignment: Alignment.centerLeft`（强制占满+左对齐）。
  - `thk_breadcrumb_nav` 的 `Wrap` 显式 `alignment: WrapAlignment.start`。
- navBar middle 居中仍为预期行为，不在本次范围。

### 5. i18n

- `app_en.arb` / `app_zh.arb` 新增 `maxNodeDepthReached`（参数 `{max}`）。
- `flutter gen-l10n` 重新生成 `lib/l10n/generated/*`。

## 验证

- `flutter analyze`（8 个改动文件）：0 error。既有 warning 均为历史遗留，非本次引入。
- 手工验收建议：
  - 在 4 层深的节点上确认 Branch 滑动入口消失；
  - 笔记转对话选第 4 层节点作父 → 弹"已达最大层级"；
  - 面包屑点第 3 层节点跳入 → 新页标题为可读 title（非 ID）；
  - 长 title 面包屑段显示省略号，整体 ≤3 行。

## 待确认 / 澄清

- 需求 1.1「面包屑居中」：初判误以为代码已左对齐（只看 `Wrap.alignment` 默认值）。
  实际根因在**外层 `Column` 默认 `crossAxisAlignment.center`**，面包屑 `Container` 收缩居中。
  已按上述 §4 修复（占满+左对齐）。navBar middle 居中属于预期行为，不在此列。
- 已做 HTML 对比 demo：`demo-breadcrumb-align.html`（修复前居中收缩 vs 修复后占满左对齐，可切长/短标题）。
