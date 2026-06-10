# 设计系统（Design System）

> 本文件是 ThkTree 视觉/交互的"宪法"——所有屏幕的设计 token、组件用法、视觉规则都来自这里。
> 修改配色/字体/组件库前必读本文，并在 PR 中说明改动原因。
> 模块级"如何使用"本文 token 的内容在各模块的 [modules/](../modules/) 子文档中描述。

## 0. 设计原则（必读）

ThkTree 全部视觉决策都基于这 7 条原则。改设计前先回看这里。

### 0.1 多彩但和谐
5 套主题色（清新调色板）共享相近明度（L≈60-70%），放在一起不冲突。**不要**临时往里塞新颜色。

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
**绝对解耦**。节点色基于 `nodeId`（5 套 `_NodePalette`），主题色基于 `themeId`（5 套清新调色板）。详见 § 7.1。

### 0.6 iOS-first Cupertino
- 走 `ThkNavBar` / `ThkListTile` / `ThkLargeTitlePage` 等自有组件，不直接用 `CupertinoNavigationBar` 等
- 不引 Material 组件（`uses-material-design: false` 保持）
- 触控热区：圆圈 44×44、拖拽手柄 52×52
- 列表行点击 → `HapticFeedback.selectionClick()`（轻）

### 0.7 视觉层级从字号开始
字号层级（`largeTitle` 34 → `displayTitle` 28 → `headline` 17 → `body` 17 → `subhead` 15 → `footnote` 13 → `caption1` 12）就是视觉层级。**不要**用粗体/颜色强行做层级——先看字号对不对。

---

## Summary

ThkTree 采用 **iOS-first Cupertino** 视觉风格，融合 **清新多彩主题色**（清新调色板 5 色循环分配给主题）和 **serif 大标题**（Cormorant Garamond）形成差异化。设计系统分三层：

1. **设计 Token**（颜色/字体/间距/圆角）—— 全部以静态常量暴露
2. **基础组件**（`ThkNavBar` / `ThkListTile` / `ThkLargeTitlePage` / `SwipeableRow` / `ThkTextField`）—— 来自 `lib/ui/core/widgets/`
3. **模块规则**（节点卡片 5 套配色 / 树形交互 / 拖拽/swipe 颜色策略）—— 见 [modules/themes/visual/](../modules/themes/visual/)

---

## 1. 颜色 Token

### 1.1 主题色循环（清新调色板）

5 套颜色，HSL 同明度（L≈60-70%）放在一起不冲突。按 `themeId.hashCode.abs() % 5` 稳定分配。

| Token | 色值 | HSL | 用途 |
|-------|------|-----|------|
| `skyBlue` | `#38BDF8` | HSL(200, 80%, 60%) | 主题 0 / 节点 0 圆圈 |
| `mint` | `#34D399` | HSL(160, 60%, 55%) | 主题 1 / 节点 0 标题深紫 |
| `lavender` | `#A78BFA` | HSL(260, 70%, 70%) | 主题 2 |
| `coral` | `#FB7185` | HSL(350, 80%, 70%) | 主题 3 |
| `amber` | `#FBBF24` | HSL(35, 85%, 65%) | 主题 4 / 节点 4 圆圈 |

**辅助方法**：
- `AppColors.colorForTheme(themeId)` —— 获取主题色
- `AppColors.tintForTheme(themeId)` —— 主题色的 15% tint（用于 leading icon 背景、书脊线附近背景）

### 1.2 节点色（`_NodePalette`，仅 themes 模块）

节点卡片独有的扩展系统，5 套双色配色（圆圈 + 标题 + 副标题），详见 [theme-detail-design.md §1](../modules/themes/visual/theme-detail-design.md)。

| Index | 圆圈 | 标题 | 副标题 | 风格 |
|-------|------|------|--------|------|
| 0 | 电蓝 `#3B82F6` | 深紫 `#1E1B4B` | 靛蓝 `#6366F1` | electric |
| 1 | 翠绿 `#10B981` | 深玫瑰 `#881337` | 珊瑚 `#EA580C` | 暖色 |
| 2 | 紫罗兰 `#8B5CF6` | 深青 `#134E4A` | 海蓝 `#0369A1` | 冷色 |
| 3 | 热粉 `#EC4899` | 深靛 `#312E81` | 翡翠 `#0D9488` | 粉冷对比 |
| 4 | 琥珀 `#FBBF24` | 深板岩 `#0F172A` | 紫蓝 `#7C3AED` | 复古 |

**规则**：
- 同一 `nodeId` 每次打开颜色一致（`hashCode.abs() % 5` 稳定）
- 标题/副标题颜色均为深色，在 `surface` 卡片上对比度 ≥ 4.5:1（WCAG AA）
- **不**运行时动态生成；预设 5 套够用
- 节点色与主题色**完全解耦**

### 1.3 全局强调色（Indigo）

| Token | 色值 | 用途 |
|-------|------|------|
| `accent` | `#6366F1` | 通用交互色（按钮、链接、focus） |
| `accentLight` | `#EEF2FF` | accent 10% tint（hover 背景、chip 背景） |
| `accentDeep` | `#4F46E5` | pressed 态 |

### 1.4 Surface 层

| Token | 色值 | 用途 |
|-------|------|------|
| `pageBg` | `#F8FAFC` | Slate 50，页面底色 |
| `surface` | `#FFFFFF` | 纯白，卡片/弹层 |
| `surfaceMuted` | `#F1F5F9` | Slate 100，二级区块 |

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

**不**在 `AppColors` 里，全部直接引用 `CupertinoColors.*`：

- `CupertinoColors.systemBlue` —— iOS 通用交互色（拖拽指示线、swipe 右滑）
- `CupertinoColors.systemRed` / `destructiveRed` —— 危险
- `CupertinoColors.label` / `secondaryLabel` / `tertiaryLabel` —— 仅在需要 iOS 动态色（深色模式）时使用

> ⚠️ 设计 token 合规检查：`rg "CupertinoColors.white|CupertinoColors.systemBackground|CupertinoColors.label|CupertinoColors.tertiaryLabel" lib/ui/features/` 应只命中系统语义色（systemRed/systemBlue/destructiveRed），其余必须用 `AppColors.*`。

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
- 危险操作前：`HapticFeedback.heavyImpact()`（重）—— 当前未使用，预留

---

## 7. 关键设计原则（详细）

### 7.1 节点色 vs 主题色（绝对解耦）

| 维度 | 节点色 | 主题色 |
|------|--------|--------|
| 数量 | 5 套 | 5 套 |
| Key | `nodeId.hashCode.abs()` | `themeId.hashCode.abs()` |
| 应用对象 | 节点卡片（圆圈/标题/副标题） | 主题容器（书脊线/拖拽/swipe） |
| 决策时间 | 节点创建时 | 主题创建时 |
| 详见 | [theme-detail-design.md §1](../modules/themes/visual/theme-detail-design.md) | 本文 § 1.1 |

**为什么解耦**：用户切换主题时，节点内容（视觉记忆点）应该保持稳定；用户在不同主题下看同一个节点，节点色不变，但"容器"色变——形成"内容 + 容器"的双层信息架构。

### 7.2 颜色有边界

主题色**只**出现在结构元素上：
- 3px 主题色书脊线（主题列表/笔记列表）
- 主题色 leading icon 背景（folder icon 背景）
- 主题色 tint 背景（hover 态）
- 主题色拖拽气泡边框

主题色**不**铺满：
- ❌ 不用主题色做页面背景
- ❌ 不用主题色做按钮
- ❌ 不用主题色做节点卡片大色块

### 7.3 中性底座

页面/卡片/文字/按钮的"底座"保持中性（`pageBg` / `surface` / `textPrimary` / `accent`），让主题色和节点色作为"点缀"出现在结构上。

---

## 8. 不做的事

- ❌ **不做深色模式**（`kDebugMode` 下不验证暗色）
- ❌ **不做运行时主题色动态生成**（5 套预设够用）
- ❌ **不用 Cupertino 默认色**（`CupertinoColors.activeBlue` / `systemBackground` 等）替换 token
- ❌ **不用 Material 组件**（`uses-material-design: false` 保持）
- ❌ **不做 iPad 横屏特殊布局**（最大宽度 800px 居中是唯一响应式）

---

## 9. 设计变更记录

| 日期 | 变更 | 状态 |
|------|------|------|
| 2026-04 | 初版：清新多彩调色板 + 节点卡片 5 套 `_NodePalette` | 已实施 |
| 2026-06-06 | 暖色调 → 蓝靛渐变视觉重构 | 已实施，token 已合入本文 |
| 2026-06-07 | `themes` 模块设计参考从单点重构方案迁移为模块化文档树 | 已实施 |

> 详细重构历史见 [docs/CHANGELOG/](../CHANGELOG/)。

---

## 10. 相关源码

- `lib/ui/core/theme/app_colors.dart` —— 颜色 token 实现
- `lib/ui/core/theme/app_theme.dart` —— 字体/主题配置
- `lib/ui/core/widgets/` —— 基础组件库
- `lib/ui/core/theme/app_icons.dart` —— 图标 token（参考用，不在本文展开）

---

## 11. 组件约定（细节版）

> § 4 列了组件清单，本节展开"什么时候用什么"。

### 11.1 NavBar 与 Large Title 怎么选

- **页面有滚动内容** → 用 `ThkLargeTitlePage`（自带大标题 + slivers）
- **页面是表单/详情/弹层** → 用 `ThkNavBar.inline`（不带大标题，单纯导航）
- **永远不要**直接用 `CupertinoNavigationBar`（不统一滚动行为）

### 11.2 列表项

- 永远用 `ThkListTile`
- leading：图标（`AppIcons.*`）或 4 字母首字母 chip（不要用头像图片占位）
- trailing：chevron / 数字 / 开关 / 垃圾桶（按场景）
- 长按列表项触发操作 → 包 `SwipeableRow`

### 11.3 滑动操作（SwipeableRow）

| 方向 | 颜色 | 触发 | 适用 |
|------|------|------|------|
| 左滑 | `destructive` (#DC2626) + 垃圾桶 | 删除 | 主题/节点/笔记 |
| 右滑 | `systemBlue` + 分支 icon | 创建分支 | 节点 |

**规则**：
- 左滑必须二次确认（弹 dialog）
- 滑动距离阈值 60px，触发后 commit 即生效
- 不带 undo 提示（删除是"硬"操作）

### 11.4 按钮（ThkButton）

| variant | 用途 | 颜色 |
|---------|------|------|
| `primary` | 主操作（保存、确认） | `accent` (#6366F1) 白字 |
| `secondary` | 次要操作（取消、更多） | `surfaceMuted` + `textPrimary` |
| `destructive` | 危险操作（删除、清空） | `destructive` (#DC2626) 白字 |

**规则**：
- 一个页面最多 1 个 `primary` 按钮
- `destructive` 必须二次确认
- 按钮文案用动词（"保存"/"删除"），不用名词

### 11.5 输入框（ThkTextField）

- placeholder 用 `textTertiary` 色
- focus 时边框变 `accent`
- error 时边框变 `destructive` + 下方一行 `footnote` 色错误说明

### 11.6 拖拽

- 触发：`LongPressDraggable`，400ms
- 拖拽时原始位置半透明（`opacity 0.3`）
- 拖拽气泡：圆角 10、白色 surface、`accent` 边框
- 放下目标高亮：背景 `accentLight` (#EEF2FF)
- 拖拽开始 → `HapticFeedback.mediumImpact()`

### 11.7 弹层与 Modal

- 用 `CupertinoActionSheet`（多选项）
- 用 `CupertinoAlertDialog`（确认/警告）
- 用 `showCupertinoModalPopup`（自定义内容）
- 弹层出现动画 250ms `easeOut`

### 11.8 空态/错误态

- 居中图标 + 一行 `headline` 色标题 + 一行 `subhead` 色说明 + `primary` 按钮（如可恢复）
- 不要用 emoji 表情（保持专业感）
