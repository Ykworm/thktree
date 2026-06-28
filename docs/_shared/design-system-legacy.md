# 设计系统（Design System）

> 本文件是 ThkTree 视觉/交互的"宪法"——所有屏幕的设计 token、组件用法、视觉规则都来自这里。
> 修改配色/字体/组件库前必读本文，并在 PR 中说明改动原因。
> 模块级"如何使用"本文 token 的内容在各模块的 [modules/](../modules/) 子文档中描述。

## 0. 设计原则（必读）

ThkTree 全部视觉决策都基于这 7 条原则。改设计前先回看这里。

### 0.1 多彩但和谐
5 套主题色（典雅黑金色调）共享相近明度（L≈50-65%），放在一起不冲突。**不要**临时往里塞新颜色。

### 0.2 颜色有归属
每个"主题"拥有自己的颜色（书脊线/icon/指示器跟随）。用户切换主题时，"容器"颜色变化，"内容"（节点色）保持稳定——形成"内容 + 容器"的双层信息架构。

### 0.3 颜色有边界
主题色**只**出现在结构元素上（书脊线/icon/指示器/拖拽气泡边框），**不**铺满：
- ❌ 不用主题色做页面背景
- ❌ 不用主题色做按钮
- ❌ 不用主题色做大色块

### 0.4 中性底座
页面/卡片/文字/按钮的"底座"保持中性（`pageBg` / `surface` / `textPrimary` / `accent`），让主题色和节点色作为"点缀"出现在结构上。

### 0.5 节点色 ≠ 主题色
**绝对解耦**。节点色基于 `nodeId`（5 套 `NodePalette`，定义在 `AppColors`），主题色基于 `themeId`（5 套典雅黑金色调）。

### 0.6 iOS-first Cupertino
- 走 `ThkNavBar` / `ThkListTile` / `ThkLargeTitlePage` 等自有组件，不直接用 `CupertinoNavigationBar` 等
- 不引 Material 组件（`uses-material-design: false` 保持）
- 触控热区：圆圈 44×44、拖拽手柄 52×52
- 列表行点击 → `HapticFeedback.selectionClick()`（轻）

### 0.7 视觉层级从字号开始
字号层级（`largeTitle` 34 → `displayTitle` 28 → `headline` 17 → `body` 17 → `subhead` 15 → `footnote` 13 → `caption1` 12）就是视觉层级。**不要**用粗体/颜色强行做层级——先看字号对不对。

---

## Summary

ThkTree 采用 **iOS-first Cupertino** 视觉风格，融合 **典雅黑金色调**（5 色循环分配给主题）和 **serif 大标题**（Cormorant Garamond）形成差异化。设计系统分三层：

1. **设计 Token**（颜色/字体/间距/圆角）—— 全部以静态常量暴露
2. **基础组件**（`ThkNavBar` / `ThkListTile` / `ThkLargeTitlePage` / `SwipeableRow` / `ThkTextField`）—— 来自 `lib/ui/core/widgets/`
3. **模块规则**（节点卡片 5 套配色 / 树形交互 / 拖拽/swipe 颜色策略）—— 见 [modules/themes/visual/](../modules/themes/visual/)

---

## 1. 颜色 Token

### 1.1 主题色循环（典雅黑金色调）

5 套颜色，低饱和度暖灰调，放在一起不冲突。按 `themeId.hashCode.abs() % 5` 稳定分配。

| Token | 色值 | HSL | 用途 |
|-------|------|-----|------|
| `champagneGold` | `#C4A77D` | HSL(36, 33%, 63%) | 主题 0 图标 |
| `warmGray` | `#8E8B82` | HSL(42, 4%, 53%) | 主题 1 图标 |
| `dustyRose` | `#A89090` | HSL(0, 10%, 61%) | 主题 2 图标 |
| `sageGray` | `#8B9080` | HSL(80, 7%, 53%) | 主题 3 图标 |
| `slateBlue` | `#6B7B8E` | HSL(210, 14%, 49%) | 主题 4 图标 |

**辅助方法**：
- `AppColors.colorForTheme(themeId)` —— 获取主题色
- `AppColors.tintForTheme(themeId)` —— 主题色的 15% tint（用于背景）

### 1.2 节点色（`NodePalette`，`AppColors` 内公开类）

节点卡片独有的扩展系统，5 套配色（圆圈 + 标题 + 副标题），典雅黑金色调，详见 [theme-detail-design.md §1](../modules/themes/visual/theme-detail-design.md)。

| Index | 圆圈 | 标题 | 副标题 | 风格 |
|-------|------|------|--------|------|
| 0 | 暖金 `#B8A07A` | 深灰 `#4A4A4A` | 棕灰 `#8B7355` | 温暖 |
| 1 | 灰绿 `#7A8B7A` | 深绿灰 `#3D4A3D` | 中绿灰 `#6B7B6B` | 沉稳 |
| 2 | 灰紫 `#8B7A8B` | 深紫灰 `#4A3D4A` | 中紫灰 `#7B6B7B` | 优雅 |
| 3 | 灰粉 `#8B7A7A` | 深粉灰 `#4A3D3D` | 中粉灰 `#7B6B6B` | 细腻 |
| 4 | 灰蓝 `#7A7A8B` | 深蓝灰 `#3D3D4A` | 中蓝灰 `#6B6B7B` | 冷静 |

**规则**：
- 同一 `nodeId` 每次打开颜色一致（`hashCode.abs() % 5` 稳定）
- 标题/副标题颜色均为深色，在 `surface` 卡片上对比度 ≥ 4.5:1（WCAG AA）
- **不**运行时动态生成；预设 5 套够用
- 节点色与主题色**完全解耦**
- 典雅黑金色调：低饱和度、暖灰调，与主题列表配色协调

### 1.5 文字色

| Token | 色值 | 用途 |
|-------|------|------|
| `textPrimary` | `#1E293B` | Slate 900，标题/正文 |
| `textSecondary` | `#64748B` | Slate 500，辅助信息 |
| `textTertiary` | `#94A3B8` | Slate 400，placeholder/disabled |

### 1.6 结构色

| Token | 色值 | 用途 |
|-------|------|------|
| `border` | `#E2E8F0` | Slate 200，分隔线/卡片描边 |
| `destructive` | `#DC2626` | 危险操作（删除按钮） |

### 1.7 系统语义色（来自 CupertinoColors）

**不**在 `AppColors` 里，直接引用 `CupertinoColors.*`（仅限以下系统语义色）：

- `CupertinoColors.systemBlue` —— iOS 通用交互色（拖拽指示线、swipe 右滑）
- `CupertinoColors.systemRed` / `destructiveRed` —— 危险
- `CupertinoColors.systemGreen` —— 成功状态（已收入 `AppColors.success`）
- `CupertinoColors.separator` —— iOS 原生分隔线
- `CupertinoColors.white` / `black` / `transparent` —— 基础色

**已收拢到 `AppColors` 的颜色**（不再直接引用 `CupertinoColors`）：
- `CupertinoColors.label` → `AppColors.textPrimary`
- `CupertinoColors.secondaryLabel` → `AppColors.textSecondary`
- `CupertinoColors.tertiaryLabel` → `AppColors.textTertiary`
- `CupertinoColors.systemBackground` → `AppColors.surface`

> ⚠️ 设计 token 合规检查：`rg "CupertinoColors\.(label|secondaryLabel|tertiaryLabel|systemBackground)" lib/ui/features/` 应返回 0 命中。

---

## 2. 字体 Token

字体分两族：

- **Serif Display**：Cormorant Garamond（`assets/fonts/`）—— 大标题专用，营造"文学/笔记"质感
- **Sans Text**：`.SF Pro Text` + `PingFang SC` fallback —— 通用正文/UI

| Token | 字体 | 字号 | 字重 | 用途 |
|-------|------|------|------|------|
| `largeTitle` | Cormorant Garamond | 34 | w600 | 屏幕大标题（Large Title） |
| `displayTitle` | Cormorant Garamond | 28 | w600 | 二级显示标题 |
| `title1` | .SF Pro Display | 28 | w700 | Modal 标题 |
| `headline` | .SF Pro Text | 17 | w600 | 列表项主标题 |
| `body` | .SF Pro Text | 17 | w400 | 正文 |
| `callout` | .SF Pro Text | 16 | w400 | 强调正文 |
| `subhead` | .SF Pro Text | 15 | w400 | 次要正文 |
| `footnote` | .SF Pro Text | 13 | w400 | 注释/时间戳 |
| `caption1` | .SF Pro Text | 12 | w400 | 节点卡片副标题/来源标签 |

---

## 3. 间距与圆角

| 用途 | 数值 |
|------|------|
| 屏幕内边距 | 16 |
| 列表项垂直内边距 | 12 |
| 卡片圆角 | 12 |
| 按钮圆角 | 10 |
| 拖拽气泡圆角 | 10 |
| 树节点缩进步进 | 28 |
| 树节点行高 | 56 |
| 圆圈热区 | 44×44 |
| 拖拽手柄热区 | 52×52 |
| 大标题到内容间距 | 16 |
| 区块间分隔线粗细 | 0.5 |

---

## 4. 基础组件（`lib/ui/core/widgets/`）

| 组件 | 角色 | 关键属性 |
|------|------|---------|
| `ThkNavBar.inline` | iOS 风格内联导航栏 | title / leading / trailing |
| `ThkLargeTitlePage` | Large Title 滚动容器 | title / trailing / slivers |
| `ThkListTile` | 列表项 | leading / title / subtitle / trailing |
| `SwipeableRow` | 滑动手势容器 | onSwipeLeft / onSwipeRight / labels |
| `ThkTextField` | Cupertino 风格输入框 | controller / placeholder / autofocus |
| `ThkButton` | 通用按钮 | variant (primary/secondary/destructive) |

**使用约定**：
- 所有 NavBar 走 `ThkNavBar`，**不**直接用 `CupertinoNavigationBar`
- 所有 Large Title 页面走 `ThkLargeTitlePage`，统一滚动行为
- 列表项**不**用 `CupertinoListTile`，统一 `ThkListTile`（保证 leading/trailing 行为一致）

---

## 5. 动画

| 场景 | duration | curve |
|------|----------|-------|
| 圆圈展开/折叠 | 200ms | `easeInOut` |
| 拖拽手柄 scale | 120ms | `easeOut` |
| 列表刷新 | 200ms | `easeInOut` |
| 弹层出现 | 250ms | `easeOut` |

---

## 6. 触控反馈

- 列表行点击：`HapticFeedback.selectionClick()`（轻）
- 拖拽开始：`HapticFeedback.mediumImpact()`（中）
