# 设计系统（Design System）

> 本文件是 ThkTree 视觉/交互的"宪法"——所有屏幕的设计 token、组件用法、视觉规则都来自这里。
> 修改配色/字体/组件库前必读本文，并在 PR 中说明改动原因。
> 模块级"如何使用"本文 token 的内容在各模块的 [modules/](../modules/) 子文档中描述。
>
> **v1.1 变更（2026-06-28）**：本文档合并了 iOS-first Cupertino 实现现状（v1.0，见 `design-system-legacy.md`）与 Riviera/Terracotta 品牌目标（见 `design-system-riviera.md`）。关键变更：
> - 5 套主题色循环**重定义**为 Riviera Blue + Terracotta 同明度衍生色
> - NodePalette 5 套**完全保留**
> - Cormorant Garamond 大标题**保留**
> - 新增 §1 品牌概述、§2.1 主品牌色、§5.1 App Icon、§5.2 Tab Bar Icons、§8 响应式、§9 可访问性、§12 文件命名、§13 开发交付、§15 附录

## 0. 设计原则（必读）

ThkTree 全部视觉决策都基于这 7 条原则。改设计前先回看这里。

### 0.1 多彩但和谐
5 套主题色（基于 Riviera Blue + Terracotta 的同明度衍生）共享相近明度（L≈48-55%），放在一起不冲突。**不要**临时往里塞新颜色。

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
**绝对解耦**。节点色基于 `nodeId`（5 套 `NodePalette`，定义在 `AppColors`），主题色基于 `themeId`（5 套 Riviera 衍生色）。

### 0.6 iOS-first Cupertino
- 走 `ThkNavBar` / `ThkListTile` / `ThkLargeTitlePage` 等自有组件，不直接用 `CupertinoNavigationBar` 等
- 不引 Material 组件（`uses-material-design: false` 保持）
- 触控热区：圆圈 44×44、拖拽手柄 52×52
- 列表行点击 → `HapticFeedback.selectionClick()`（轻）

### 0.7 视觉层级从字号开始
字号层级（`largeTitle` 34 → `displayTitle` 28 → `headline` 17 → `body` 17 → `subhead` 15 → `footnote` 13 → `caption1` 12）就是视觉层级。**不要**用粗体/颜色强行做层级——先看字号对不对。

---

## 1. 品牌概述

ThkTree 是一个 AI-native 知识管理应用，核心理念是通过"知识树"的隐喻，帮助用户构建结构化、层级化的思维体系。

**核心价值观**：

- **有机生长** - 知识如树木般自然生长
- **结构化** - 清晰的层级与路径
- **探索性** - 鼓励实验与发现（Lab 功能）
- **AI-native** - 智能辅助，人机协作

**品牌气质**：

- **克制 (Restrained)** - 不过度设计，留白得当
- **有序 (Orderly)** - 结构清晰，逻辑严谨
- **实验性 (Experimental)** - 鼓励探索，包容试错
- **人文 (Humanist)** - 温暖、成熟、有温度
- **理性 (Rational)** - 冷静、专业、可信赖

**美学参考**：

- 巴赫的音乐结构 - 复杂而有序
- 实验室美学 - 简洁、功能性、探索感
- 欧洲现代设计 - 温暖、优雅、克制

---

## 2. 颜色 Token

### 2.1 主品牌色

**Riviera Blue (主品牌色)**

- HEX: `#183451`
- RGB: `24, 52, 81`
- HSL: `HSL(210, 58%, 21%)`
- 用途：主要交互元素、选中状态、强调内容
- 特性：深邃、理性、专业
- 应用场景：选中 Tab Icon、主按钮、链接文字、Logo 中心圆背景

**Terracotta (强调色)**

- HEX: `#A9601C`
- RGB: `169, 96, 28`
- HSL: `HSL(28, 71%, 39%)`
- 用途：强调、Lab 功能、特殊标记
- 特性：温暖、活力、实验性
- 应用场景：Lab 相关功能、重要提示、特殊标签、Logo 下部背景

> 现状代码仍使用 `AppColors.accent: #6366F1`（Indigo）作为主品牌色，迁移到 Riviera Blue 是独立代码迁移工单。

### 2.2 中性色

| Token | HEX | 用途 | 目标 |
|-------|-----|------|------|
| `pageBg` | `#F8FAFC` | Slate 50，页面底色 | 目标迁移至 Soft Ivory `#F3ECDE` |
| `surface` | `#FFFFFF` | 纯白，卡片/弹层 | 保持 |
| `surfaceMuted` | `#F1F5F9` | Slate 100，二级区块 | 保持 |
| `white` | `#FFFFFF` | iOS 原生 | 保持 |
| `transparent` | - | 透明 | 保持 |

**中性补充（来自 Riviera 体系，仅备查）**：

| 名称 | HEX | 用途 |
|------|-----|------|
| Soft Ivory | `#F3ECDE` | 主背景、卡片背景（Riviera 目标态） |
| Sand Linen | `#D4AF83` | 分隔、次级背景、渐变过渡 |
| Light Gray | `#8B9DAF` | 未选中状态、辅助文字 |
| Gray-Blue Glow | `#7A8FA3` | 阴影、光晕效果 |

### 2.3 文字色

| Token | HEX | 用途 | 目标 |
|-------|-----|------|------|
| `textPrimary` | `#1E293B` | Slate 900，标题/正文 | 目标 `#2C3E50` |
| `textSecondary` | `#64748B` | Slate 500，辅助信息 | 目标 `#5A6B7F` |
| `textTertiary` | `#94A3B8` | Slate 400，placeholder/disabled | 目标 `#8B9DAF` |

### 2.4 结构色

| Token | HEX | 用途 |
|-------|-----|------|
| `border` | `#E2E8F0` | Slate 200，分隔线/卡片描边 |
| `destructive` | `#DC2626` | 危险操作（删除按钮） |
| `success` | `#34C759` | 成功状态（对应 systemGreen） |
| `onSurface` | `#FFFFFF` | 卡片上前景色（白色） |

### 2.5 主题色循环（Riviera 衍生）

5 套颜色，基于 Riviera Blue + Terracotta 的同明度衍生（饱和度 12-60%、明度 48-55%），放在一起不冲突。按 `themeId.hashCode.abs() % 5` 稳定分配。

| Index | Token | HEX | HSL | 推导 | 风格 |
|-------|-------|-----|-----|------|------|
| 0 | `terracottaWarm` | `#C28256` | HSL(28, 60%, 50%) | Terracotta 高明度版 | 暖金 |
| 1 | `warmNeutral` | `#998A75` | HSL(40, 12%, 50%) | 暖灰中性 | 沉稳 |
| 2 | `roseClay` | `#B08378` | HSL(10, 25%, 55%) | Terracotta→Rose 偏移 | 细腻 |
| 3 | `sageMist` | `#6B8A7E` | HSL(150, 12%, 48%) | Riviera→Sage 偏移 | 沉静 |
| 4 | `rivieraMist` | `#5F7CA0` | HSL(210, 25%, 50%) | Riviera 亮版 | 冷色 |

**辅助方法**：

- `AppColors.colorForTheme(themeId)` —— 获取主题色
- `AppColors.tintForTheme(themeId)` —— 主题色的 15% tint（用于背景）

**重构要点**：

- 保留 `colorForTheme` / `tintForTheme` 签名不变
- 保持 `hashCode.abs() % 5` 分配策略
- 饱和度统一控制在 12-60%、明度 48-55%（明度收敛，遵循 §0.1 多彩但和谐）
- 代码侧 token 待迁移工单同步更新

### 2.6 节点色（`NodePalette`，`AppColors` 内公开类）

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

### 2.7 系统语义色（来自 CupertinoColors）

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

### 2.8 深色模式（目标态）

**背景色**

- 主背景：`#1A2332`（深蓝灰）
- 次级背景：`#243447`
- 卡片背景：`#2D3E52`

**文字色**

- 主文字：`#F3ECDE`（Soft Ivory）
- 次级文字：`#8B9DAF`
- 禁用文字：`#5A6B7F`

**强调色**

- 主色：`#4A8FD9`（更亮的蓝色）
- 强调色：`#D4AF83`（Sand Linen，保持温暖）

> 当前深色模式未启用，本节为 Riviera 体系下的目标态。

---

## 3. 字体 Token

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

**字体选型原则**：

- **大标题 serif 保留**：Cormorant Garamond 提供文学/笔记质感，是品牌差异化锚点
- **正文 sans 为主**：SF Pro Text 通用、清晰、平台原生
- **中英协调**：中文 PingFang SC 作为 fallback，字号略大于英文（+1-2pt）
- **层级清晰**：通过字号、字重区分信息层级，避免过多字重变化

---

## 4. 间距与圆角

### 4.1 当前值

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

### 4.2 间距命名（基础网格 8px）

所有间距以 8px 为基础单位，使用 XS-XXL 命名与 §4.1 数值映射：

| 名称 | 数值 | 单位数 | 映射 §4.1 | 用途 |
|------|------|--------|----------|------|
| XS | 4px | 0.5 | - | 紧密相关元素、图标与文字 |
| S | 8px | 1 | - | 列表项内部、标签间距 |
| M | 16px | 2 | 屏幕内边距、大标题到内容 | 段落间距、卡片内边距 |
| L | 24px | 3 | - | 区块间距、卡片外边距 |
| XL | 32px | 4 | - | 页面区块间距 |
| XXL | 48px | 6 | - | 页面顶部/底部边距 |

### 4.3 安全区域

**iPhone**

- 顶部：状态栏高度 + 16px
- 底部：Home Indicator 高度 + 16px
- 左右：16px

**iPad**

- 顶部：状态栏高度 + 24px
- 底部：24px
- 左右：24px（竖屏）/ 32px（横屏）

---

## 5. 图标系统

### 5.1 App Icon

**规格**

- 尺寸：1024x1024px
- 格式：PNG（无透明度）
- 圆角：由系统自动添加

**设计结构**

- 背景：三色分区（Soft Ivory / Sand Linen / Terracotta）
- 主体：白色同心圆环树形结构
- 中心：Riviera Blue 圆形背景
- 文字："Thk" 白色，位于 Terracotta 区域
- 特殊元素：右上角保留"lab branch"细节

**设计原则**

- **高识别度** - 小尺寸下清晰可辨
- **有机形态** - 避免机械感、扇形分割
- **结构感** - 同心圆暗示层级与路径
- **温暖感** - 暖色调，人文气质

完整资产：[App Icon](https://a.lovart.ai/artifacts/agent/xN8LSwXVxo7R3wve.png)

### 5.2 Tab Bar Icons

**规格**

- 尺寸：28x28pt (@1x)
- 线宽：2-3px
- 风格：线性图标 (Line Icons)
- 圆角：2px（线条端点）

**图标列表**

| Tab | 图形 | 未选中 | 选中 |
|-----|------|--------|------|
| Search | 放大镜 | Light Gray | Riviera Blue + 底部下划线 |
| Topics | 简化的树形节点结构 | Light Gray | Riviera Blue + 底部下划线 |
| Notes | 记事本 | Light Gray | Riviera Blue + 底部下划线 |
| Settings | 齿轮 | Light Gray | Riviera Blue + 底部下划线 |

**选中状态**

- 颜色：Riviera Blue
- 下划线：2px 高，24px 宽，圆角 1px
- 位置：图标下方 4px

完整资产：[Tab Icons](https://a.lovart.ai/artifacts/agent/NEpSlTqrElKHiBHq.png)

### 5.3 UI Icons（`AppIcons`）

UI 操作图标集中定义在 `lib/ui/core/theme/app_icons.dart`，通过 SF Symbol 名称引用，详见 [design-tokens.yaml §8](../_shared/design-tokens.yaml)。

主要分类：

- **通用操作**：add / close / check / delete / edit / copy / refresh / search / more
- **导航**：back / chevronRight / chevronLeft
- **通信/聊天**：send / stop / chat / forum / modelSelector
- **内容/文件**：note / folder / download / share / star
- **设置/提供商**：settings / extensionIcon / cloud
- **树/分支**：accountTree / callSplit / branch / sparkles

**UI 图标规范**：

- 尺寸：20x20pt / 24x24pt
- 线宽：2px
- 风格：线性，简洁
- 设计原则：一致性 / 清晰性 / 简洁性 / 语义性

---

## 6. 基础组件（`lib/ui/core/widgets/`）

| 组件 | 角色 | 关键属性 |
|------|------|---------|
| `ThkNavBar.inline` | iOS 风格内联导航栏 | title / leading / trailing |
| `ThkLargeTitlePage` | Large Title 滚动容器 | title / trailing / slivers |
| `ThkListTile` | 列表项 | leading / title / subtitle / trailing / themeId |
| `ThkListSection` | 列表容器 | - |
| `SwipeableRow` | 滑动手势容器 | onSwipeLeft / onSwipeRight / labels |
| `ThkTextField` | Cupertino 风格输入框 | controller / placeholder / autofocus |
| `ThkButton` | 通用按钮 | variant (primary/secondary/destructive) |
| `ThkAlert` | 轻量提示弹窗 | message / defaultAction |
| `ThkActionSheet` | 操作选择弹窗 | - |
| `MarkdownToolbar` | Markdown 格式工具栏 | - |

**使用约定**：

- 所有 NavBar 走 `ThkNavBar`，**不**直接用 `CupertinoNavigationBar`
- 所有 Large Title 页面走 `ThkLargeTitlePage`，统一滚动行为
- 列表项**不**用 `CupertinoListTile`，统一 `ThkListTile`（保证 leading/trailing 行为一致）
- 颜色应用：现状用 §2.4 结构色（`accent` / `destructive`）；迁移后用 §2.1 主品牌色

**按钮规范（来自 Riviera 体系，备查）**：

- **Primary Button**：背景色 Riviera Blue、文字 White、圆角 12px、高度 48pt、阴影 `0 2px 8px rgba(24, 52, 81, 0.2)`
- **Secondary Button**：背景 Transparent、边框 2px solid Riviera Blue、文字 Riviera Blue、圆角 12px
- **Text Button**：背景 Transparent、文字 Riviera Blue、字号 16pt Medium

---

## 7. 动效

### 7.1 组件级动画

| 场景 | duration | curve |
|------|----------|-------|
| 圆圈展开/折叠 | 200ms | `easeInOut` |
| 拖拽手柄 scale | 120ms | `easeOut` |
| 列表刷新 | 200ms | `easeInOut` |
| 弹层出现 | 250ms | `easeOut` |

### 7.2 全局动效规范

**时长**

- 快速：200ms（开关、选中状态）
- 标准：300ms（页面过渡、弹窗）
- 慢速：500ms（复杂动画、加载）

**缓动函数**

- `ease-out`：元素进入 `(0.25, 0.1, 0.25, 1.0)`
- `ease-in`：元素退出 `(0.42, 0.0, 1.0, 1.0)`
- `ease-in-out`：循环动画 `(0.42, 0.0, 0.58, 1.0)`
- `spring`：弹性效果（iOS 标准弹簧动画）

**页面过渡**

- 类型：滑动 (Slide)
- 方向：从右到左（进入）/ 从左到右（返回）
- 时长：300ms
- 缓动：`ease-out`

**弹窗**

- 类型：缩放 + 淡入 (Scale + Fade)
- 初始：`scale(0.9)`, `opacity(0)`
- 结束：`scale(1.0)`, `opacity(1)`
- 时长：300ms
- 缓动：`ease-out`

**加载指示器**

- 类型：旋转 (Rotate)
- 速度：1 秒/圈
- 缓动：`linear`

---

## 8. 响应式设计

### 8.1 断点

| 设备 | 宽度 |
|------|------|
| iPhone SE | 375pt |
| iPhone 标准 | 390pt |
| iPhone Plus | 428pt |
| iPad 竖屏 | 768pt |
| iPad 横屏 | 1024pt |

### 8.2 适配规则

**字体缩放**

- iPhone SE：基准字号 -1pt
- iPhone 标准：基准字号
- iPhone Plus：基准字号 +1pt
- iPad：基准字号 +2pt

**间距缩放**

- iPhone：基准间距
- iPad：基准间距 × 1.5

**布局调整**

- iPhone：单列布局
- iPad 竖屏：单列或双列
- iPad 横屏：双列或三列

---

## 9. 可访问性

### 9.1 颜色对比度

- 正文文字：至少 4.5:1
- 大标题：至少 3:1
- 图标：至少 3:1

### 9.2 字体大小

- 最小字号：12pt (Caption)
- 推荐正文：16-17pt
- 支持动态字体：iOS Dynamic Type

### 9.3 触摸目标

- 最小尺寸：44x44pt
- 推荐尺寸：48x48pt
- 间距：至少 8pt

### 9.4 VoiceOver 支持

- 所有交互元素添加 Accessibility Label
- 图标添加语义描述
- 复杂组件提供 Accessibility Hint

---

## 10. 触控反馈

- 列表行点击：`HapticFeedback.selectionClick()`（轻）
- 拖拽开始：`HapticFeedback.mediumImpact()`（中）
- 危险操作前（预留）：`HapticFeedback.heavyImpact()`（重）

---

## 11. 4 层结构（备选方案，未启用）

> ⚠️ **状态：未启用，仅作为备选方案记录。** 当前节点视觉以 §2.6 `NodePalette` 5 套色为主。本节来自 `design-system-riviera.md`，仅作设计参考。

### 11.1 4 层结构定义

```
Level 0: Theme (主题)
  └─ Level 1: Chat L1 (一级对话)
      └─ Level 2: Chat L2 (二级对话)
          └─ Level 3: Chat L3 (三级对话)
```

### 11.2 视觉层级

| 层级 | 圆形尺寸 | 字体 | 颜色 | Badge |
|------|---------|------|------|-------|
| Level 0 - Theme | 64pt | 18pt Semibold | Riviera Blue | Terracotta（显示子节点数） |
| Level 1 - Chat L1 | 56pt | 17pt Semibold | Riviera Blue (90%) | Terracotta (80%) |
| Level 2 - Chat L2 | 48pt | 16pt Medium | Riviera Blue (70%) | Terracotta (60%) |
| Level 3 - Chat L3 | 40pt | 15pt Regular | Riviera Blue (50%) | 无 |

### 11.3 为何不启用

- **与 §0.1 多彩但和谐 冲突**：仅靠 Riviera Blue 透明度区分层级，丢失了 NodePalette 的色相丰富度
- **可读性下降**：50% 透明度的圆圈在浅背景上对比度不足
- **回退路径**：若未来决定简化为"主色 + 透明度"模型，可平滑切换

---

## 12. 文件命名规范

### 12.1 图片资源

格式：`{component}_{variant}_{size}@{scale}.png`

示例：

- `icon_search_default@2x.png`
- `icon_search_selected@3x.png`
- `button_primary_normal@2x.png`
- `logo_app_1024.png`

### 12.2 颜色命名

格式：`{semantic_name} / {color_name}`

示例：

- `primary_blue` (Riviera Blue)
- `accent_terracotta` (Terracotta)
- `background_ivory` (Soft Ivory)
- `text_primary`
- `text_secondary`

### 12.3 组件命名

格式：`{Component}{Variant}`

示例：

- `ButtonPrimary`
- `ButtonSecondary`
- `CardStandard`
- `CardElevated`
- `ListItemStandard`

---

## 13. 开发交付

### 13.1 设计文件

- Figma / Sketch 源文件
- 切图资源 (@1x, @2x, @3x)
- 图标字体（可选）
- 设计规范文档（本文档）

### 13.2 代码资源

- 颜色定义 (Swift / Kotlin)
- 字体定义
- 间距常量
- 组件样式

### 13.3 协作流程

1. **设计评审** - 设计师与开发者对齐
2. **资源交付** - 提供完整设计资源
3. **开发实现** - 开发者按规范实现
4. **视觉还原** - 设计师验收还原度
5. **迭代优化** - 根据反馈调整

---

## 14. 版本历史

### v1.0 (2026-06-08)

- 完成 App Icon 设计
- 完成 Tab Icons 设计
- 定义色彩系统（5 套典雅黑金色调主题 + 5 套 NodePalette）
- 定义字体系统（Cormorant Garamond + SF Pro Text）
- 定义间距与圆角
- 定义基础组件库（ThkNavBar / ThkListTile / ThkButton 等）
- 定义动效与触控反馈

### v1.1 (2026-06-28) — 增量修正

- 增补 §1 品牌概述（来自 `design-system-riviera.md` §1）
- 新增 §2.1 主品牌色（Riviera Blue + Terracotta）
- **重定义** §2.5 主题色循环为 Riviera/Terracotta 衍生色（饱和度 12-60%、明度 48-55%）
- 中性色/文字色标注"目标迁移值"
- 新增 §2.8 深色模式（目标态）
- 间距新增 §4.2 XS-XXL 命名（基础网格 8px）
- 新增 §5.1 App Icon、§5.2 Tab Bar Icons 详细规范
- 新增 §7.2 全局动效规范（fast/standard/slow + 缓动函数 + 页面过渡）
- 新增 §8 响应式设计（5 断点 + 字体/间距/布局适配）
- 新增 §9 可访问性（对比度/字号/触摸目标/VoiceOver）
- 新增 §11 4 层结构（备选，未启用）
- 新增 §12 文件命名规范
- 新增 §13 开发交付
- 新增 §15 附录
- **完全保留** NodePalette 5 套、Thk 组件库、Cormorant Garamond 大标题、iOS-first Cupertino 原则

---

## 15. 附录

### 15.1 设计资产链接

- **App Icon**: https://a.lovart.ai/artifacts/agent/xN8LSwXVxo7R3wve.png
- **Tab Icons**: https://a.lovart.ai/artifacts/agent/NEpSlTqrElKHiBHq.png
- **配色方案**: https://a.lovart.ai/artifacts/agent/OqXBVQOFaV2m3muN.png
- **设计规范文档**: https://a.lovart.ai/artifacts/agent/9mstksbHgMIThDip.png
- **UI 组件库**: https://a.lovart.ai/artifacts/agent/c4LwtKn7TuEmvJkP.png
- **界面示例**: https://a.lovart.ai/artifacts/agent/bOd9nH860z2OwziA.png
- **4 层结构设计**: https://a.lovart.ai/artifacts/agent/jzb5pD3yJkActyZ6.png

### 15.2 参考资料

- **Apple Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/
- **Material Design**: https://material.io/design
- **iOS Design Themes**: https://developer.apple.com/design/human-interface-guidelines/ios/overview/themes/

### 15.3 完整规范

- 完整 Riviera 设计系统：`docs/_shared/design-system-riviera.md`
- 旧版本快照（v1.0 完整版）：`docs/_shared/design-system-legacy.md`
