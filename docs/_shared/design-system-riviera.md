# ThkTree Design System

## 1. 项目概述 (Project Overview)

### 1.1 品牌定位

ThkTree 是一个 AI-native 知识管理应用，核心理念是通过"知识树"的隐喻，帮助用户构建结构化、层级化的思维体系。

**核心价值观**：

- **有机生长** - 知识如树木般自然生长
- **结构化** - 清晰的层级与路径
- **探索性** - 鼓励实验与发现（Lab 功能）
- **AI-native** - 智能辅助，人机协作

### 1.2 品牌气质

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

## 2. 色彩系统 (Color System)

### 2.1 主色调 (Primary Colors)

**Riviera Blue (主品牌色)**

- HEX: `#183451`
- RGB: `24, 52, 81`
- 用途：主要交互元素、选中状态、强调内容
- 特性：深邃、理性、专业
- 应用场景：
  - 选中的 Tab Icon
  - 主要按钮
  - 链接文字
  - Logo 中心圆背景

**Terracotta (强调色)**

- HEX: `#A9601C`
- RGB: `169, 96, 28`
- 用途：强调、Lab 功能、特殊标记
- 特性：温暖、活力、实验性
- 应用场景：
  - Lab 相关功能
  - 重要提示
  - 特殊标签
  - Logo 下部背景

### 2.2 中性色 (Neutral Colors)

**Soft Ivory (背景主色)**

- HEX: `#F3ECDE`
- RGB: `243, 236, 222`
- 用途：主背景、卡片背景

**Sand Linen (次级背景)**

- HEX: `#D4AF83`
- RGB: `212, 175, 131`
- 用途：分隔、次级背景、渐变过渡

**White (纯白)**

- HEX: `#FFFFFF`
- RGB: `255, 255, 255`
- 用途：文字、图标、高对比元素

**Light Gray (浅灰)**

- HEX: `#8B9DAF`
- RGB: `139, 157, 175`
- 用途：未选中状态、辅助文字

**Gray-Blue Glow (灰蓝光晕)**

- HEX: `#7A8FA3`
- RGB: `122, 143, 163`
- 用途：阴影、光晕效果

### 2.3 语义色 (Semantic Colors)

| 语义 | HEX | RGB | 用途 |
|------|-----|-----|------|
| Success | `#4CAF50` | `76, 175, 80` | 成功提示、完成状态 |
| Warning | `#FF9800` | `255, 152, 0` | 警告提示、需注意内容 |
| Error | `#F44336` | `244, 67, 54` | 错误提示、删除操作 |
| Info | `#2196F3` | `33, 150, 243` | 信息提示、帮助说明 |

### 2.4 深色模式 (Dark Mode)

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

---

## 3. 字体系统 (Typography)

### 3.1 字体家族 (Font Families)

**英文字体**

- Primary: SF Pro Display / SF Pro Text
- Fallback: Inter / Helvetica Neue

**中文字体**

- Primary: PingFang SC（苹方-简）
- Fallback: Heiti SC / STHeiti

**等宽字体 (代码)**

- Monospace: SF Mono / Menlo / Consolas

### 3.2 字体层级 (Type Scale)

**H1 - 大标题**

- 字号：28-32pt
- 字重：Bold (700)
- 行高：1.2
- 颜色：Riviera Blue
- 用途：页面主标题

**H2 - 二级标题**

- 字号：24-26pt
- 字重：Semibold (600)
- 行高：1.3
- 颜色：Riviera Blue
- 用途：区块标题

**H3 - 三级标题**

- 字号：20-22pt
- 字重：Semibold (600)
- 行高：1.4
- 颜色：Riviera Blue / 深灰
- 用途：卡片标题、列表标题

**Body - 正文**

- 字号：16-17pt
- 字重：Regular (400)
- 行高：1.5
- 颜色：`#2C3E50`（深灰）
- 用途：主要内容文字

**Body Small - 小正文**

- 字号：14-15pt
- 字重：Regular (400)
- 行高：1.5
- 颜色：`#5A6B7F`（中灰）
- 用途：辅助说明、次要内容

**Caption - 说明文字**

- 字号：12-13pt
- 字重：Regular (400)
- 行高：1.4
- 颜色：`#8B9DAF`（浅灰）
- 用途：时间戳、标签、提示文字

**Button Text - 按钮文字**

- 字号：16-17pt
- 字重：Medium (500)
- 行高：1.0
- 颜色：根据按钮类型
- 用途：按钮内文字

### 3.3 字体使用原则

- **层级清晰** - 通过字号、字重、颜色区分信息层级
- **可读性优先** - 正文字号不小于 16pt
- **对比适度** - 避免过多字重变化
- **中英文协调** - 中文字号略大于英文（+1-2pt）
- **行高舒适** - 正文行高 1.5，标题行高 1.2-1.4

---

## 4. 间距系统 (Spacing System)

### 4.1 基础网格

- 基础单位：8px
- 所有间距都是 8 的倍数

### 4.2 间距规范

| 名称 | 数值 | 单位数 | 用途 |
|------|------|--------|------|
| 超小间距 (XS) | 4px | 0.5 | 紧密相关元素、图标与文字 |
| 小间距 (S) | 8px | 1 | 列表项内部、标签间距 |
| 中间距 (M) | 16px | 2 | 段落间距、卡片内边距 |
| 大间距 (L) | 24px | 3 | 区块间距、卡片外边距 |
| 超大间距 (XL) | 32px | 4 | 页面区块间距 |
| 特大间距 (XXL) | 48px | 6 | 页面顶部/底部边距 |

### 4.3 安全区域 (Safe Area)

**iPhone**

- 顶部：状态栏高度 + 16px
- 底部：Home Indicator 高度 + 16px
- 左右：16px

**iPad**

- 顶部：状态栏高度 + 24px
- 底部：24px
- 左右：24px（竖屏）/ 32px（横屏）

---

## 5. 图标系统 (Icon System)

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

### 5.2 Tab Bar Icons

**规格**

- 尺寸：28x28pt (@1x)
- 线宽：2-3px
- 风格：线性图标 (Line Icons)
- 圆角：2px（线条端点）

**图标列表**

1. **Search (搜索)**
   - 图形：放大镜
   - 未选中：Light Gray (`#8B9DAF`)
   - 选中：Riviera Blue (`#183451`) + 底部下划线

2. **Topics (主题树)**
   - 图形：简化的树形节点结构
   - 未选中：Light Gray
   - 选中：Riviera Blue + 底部下划线

3. **Notes (笔记)**
   - 图形：记事本
   - 未选中：Light Gray
   - 选中：Riviera Blue + 底部下划线

4. **Settings (设置)**
   - 图形：齿轮
   - 未选中：Light Gray
   - 选中：Riviera Blue + 底部下划线

**选中状态**

- 颜色：Riviera Blue
- 下划线：2px 高，24px 宽，圆角 1px
- 位置：图标下方 4px

### 5.3 功能图标 (UI Icons)

**规格**

- 尺寸：20x20pt / 24x24pt
- 线宽：2px
- 风格：线性，简洁

**常用图标**

- 导航：返回、前进、关闭、菜单
- 操作：添加、删除、编辑、分享
- 状态：完成、错误、警告、信息
- 功能：收藏、点赞、评论、更多

**设计原则**

- **一致性** - 统一线宽、圆角、视觉重量
- **清晰性** - 24x24pt 下清晰可辨
- **简洁性** - 去除不必要的细节
- **语义性** - 符合用户认知习惯

---

## 6. 组件规范 (Component Specifications)

### 6.1 按钮 (Buttons)

**Primary Button (主按钮)**

- 背景色：Riviera Blue
- 文字色：White
- 圆角：12px
- 高度：48pt
- 内边距：16px（左右）
- 字体：16pt Medium
- 阴影：`0 2px 8px rgba(24, 52, 81, 0.2)`

状态：

- **Normal**：如上
- **Pressed**：背景色 80% 透明度
- **Disabled**：背景色 40% 透明度，文字色 60% 透明度

**Secondary Button (次按钮)**

- 背景色：Transparent
- 边框：2px solid Riviera Blue
- 文字色：Riviera Blue
- 圆角：12px
- 高度：48pt
- 内边距：16px（左右）
- 字体：16pt Medium

**Text Button (文字按钮)**

- 背景色：Transparent
- 文字色：Riviera Blue
- 字体：16pt Medium
- 下划线：无

### 6.2 输入框 (Input Fields)

**Text Input**

- 背景色：White
- 边框：1px solid `#D4AF83`
- 圆角：8px
- 高度：48pt
- 内边距：12px（左右）
- 字体：16pt Regular
- 占位符颜色：`#8B9DAF`

状态：

- **Normal**：如上
- **Focus**：边框色 Riviera Blue，边框宽度 2px
- **Error**：边框色 `#F44336`
- **Disabled**：背景色 `#F3ECDE`，文字色 `#8B9DAF`

### 6.3 卡片 (Cards)

**Standard Card**

- 背景色：White
- 圆角：16px
- 内边距：16px
- 阴影：`0 2px 12px rgba(0, 0, 0, 0.08)`
- 边框：无

**Elevated Card (悬浮卡片)**

- 背景色：White
- 圆角：16px
- 内边距：20px
- 阴影：`0 4px 20px rgba(0, 0, 0, 0.12)`

### 6.4 列表项 (List Items)

**Standard List Item**

- 高度：64pt（单行）/ 80pt（双行）
- 内边距：16px（左右）
- 分隔线：1px solid `#E5E5E5`，左边距 16px
- 结构：
  - 左侧：图标 (24x24pt) + 8px 间距
  - 中间：标题 (16pt) + 副标题 (14pt，可选)
  - 右侧：箭头 / Badge / 开关

### 6.5 徽章 (Badges)

**Count Badge (数字徽章)**

- 背景色：Terracotta
- 文字色：White
- 字体：12pt Bold
- 圆角：10px（圆形）
- 最小尺寸：20x20pt
- 内边距：4px（左右）

**Status Badge (状态徽章)**

- 背景色：根据状态 (Success/Warning/Error)
- 文字色：White
- 字体：12pt Medium
- 圆角：4px
- 高度：24pt
- 内边距：8px（左右）

### 6.6 导航栏 (Navigation Bar)

**Top Navigation Bar**

- 高度：44pt（内容）+ 状态栏高度
- 背景色：Soft Ivory / White
- 底部边框：1px solid `#E5E5E5`
- 元素：
  - 左侧：返回按钮 / Logo (32pt)
  - 中间：标题 (17pt Semibold)
  - 右侧：操作按钮 (1-2 个)

**Tab Bar**

- 高度：49pt + Home Indicator 高度
- 背景色：White
- 顶部边框：1px solid `#E5E5E5`
- 模糊效果：半透明模糊（iOS 标准）

### 6.7 面包屑 (Breadcrumbs)

**结构**

- 字体：14pt Regular
- 颜色：`#8B9DAF`（未选中）/ Riviera Blue（当前）
- 分隔符：`/` 或 `>`
- 间距：8px

**截断规则**：

- 最多显示 3 层
- 超过 3 层显示：`主题 > ... > 当前`
- 点击可展开完整路径

---

## 7. 层级结构设计 (Hierarchy Design)

### 7.1 4层结构定义

```
Level 0: Theme (主题)
  └─ Level 1: Chat L1 (一级对话)
      └─ Level 2: Chat L2 (二级对话)
          └─ Level 3: Chat L3 (三级对话)
```

### 7.2 视觉层级

| 层级 | 圆形尺寸 | 字体 | 颜色 | Badge |
|------|---------|------|------|-------|
| Level 0 - Theme | 64pt | 18pt Semibold | Riviera Blue | Terracotta（显示子节点数） |
| Level 1 - Chat L1 | 56pt | 17pt Semibold | Riviera Blue (90% 透明度) | Terracotta (80% 透明度) |
| Level 2 - Chat L2 | 48pt | 16pt Medium | Riviera Blue (70% 透明度) | Terracotta (60% 透明度) |
| Level 3 - Chat L3 | 40pt | 15pt Regular | Riviera Blue (50% 透明度) | 无（已是最深层） |

### 7.3 导航模式

**渐进式导航 (Progressive Navigation)**

- 每次只显示 1-2 层
- 点击节点进入下一层
- 面包屑显示当前路径

**树形可视化 (Tree Visualization)**

- 在 Topics Tab 显示完整树形结构
- 可折叠/展开
- 视觉缩进表示层级

---

## 8. 响应式设计 (Responsive Design)

### 8.1 断点 (Breakpoints)

| 设备 | 宽度 |
|------|------|
| iPhone SE | 375pt 宽 |
| iPhone 标准 | 390pt 宽 |
| iPhone Plus | 428pt 宽 |
| iPad 竖屏 | 768pt 宽 |
| iPad 横屏 | 1024pt 宽 |

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

## 9. 动效规范 (Animation Guidelines)

### 9.1 时长 (Duration)

- **快速**：200ms（开关、选中状态）
- **标准**：300ms（页面过渡、弹窗）
- **慢速**：500ms（复杂动画、加载）

### 9.2 缓动函数 (Easing)

- `ease-out`：元素进入 `(0.25, 0.1, 0.25, 1.0)`
- `ease-in`：元素退出 `(0.42, 0.0, 1.0, 1.0)`
- `ease-in-out`：循环动画 `(0.42, 0.0, 0.58, 1.0)`
- `spring`：弹性效果（iOS 标准弹簧动画）

### 9.3 常用动画

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

## 10. 可访问性 (Accessibility)

### 10.1 颜色对比度

- 正文文字：至少 4.5:1
- 大标题：至少 3:1
- 图标：至少 3:1

### 10.2 字体大小

- 最小字号：12pt (Caption)
- 推荐正文：16-17pt
- 支持动态字体：iOS Dynamic Type

### 10.3 触摸目标

- 最小尺寸：44x44pt
- 推荐尺寸：48x48pt
- 间距：至少 8pt

### 10.4 VoiceOver 支持

- 所有交互元素添加 Accessibility Label
- 图标添加语义描述
- 复杂组件提供 Accessibility Hint

---

## 11. 设计原则 (Design Principles)

### 11.1 核心原则

1. **简洁至上 (Simplicity First)**
   - 去除不必要的装饰
   - 每个元素都有明确目的
   - 留白是设计的一部分

2. **结构清晰 (Clear Structure)**
   - 信息层级分明
   - 视觉引导明确
   - 逻辑路径清晰

3. **有机生长 (Organic Growth)**
   - 避免机械感、网格感
   - 自然的曲线和流动
   - 渐进式展开

4. **温暖人文 (Warm & Humanist)**
   - 温暖的色调
   - 舒适的间距
   - 有温度的交互

5. **克制优雅 (Restrained Elegance)**
   - 不过度设计
   - 细节精致
   - 品质感

### 11.2 设计禁忌

**❌ 避免：**

- 东方画风（水墨、国画风格）
- 锯齿边缘
- 穿孔效果
- 奇怪的虚线
- 机械的扇形分割
- 过多的渐变和阴影
- 花哨的动画

**✅ 追求：**

- 现代欧洲设计感
- 清晰的线条
- 自然的形态
- 克制的装饰
- 流畅的动画

---

## 12. 文件命名规范 (File Naming Convention)

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

## 13. 开发交付 (Development Handoff)

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

## 14. 版本历史 (Version History)

### v1.0 (2026-06-08)

- ✅ 完成 App Icon 设计
- ✅ 完成 Tab Icons 设计
- ✅ 定义色彩系统
- ✅ 定义字体系统
- ✅ 定义间距系统
- ✅ 定义组件规范
- ✅ 完成 4 层结构设计
- ⏸️ 启动页动画（待定）

---

## 15. 附录 (Appendix)

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

### 15.3 联系方式

如有设计相关问题，请联系设计团队。
