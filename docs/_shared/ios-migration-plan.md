# ThkTree iOS UI 迁移计划（Material → Cupertino）

> 本文档是该次重构的**唯一真相源**。所有 PR 落地都必须能映射到本文档某个 Item，并在合并后回到本文档勾选 ✅。
>
> 起草日期：2026-05-30 · 当前阶段：📋 计划已确认，待动手

---

## 0. 背景与目标

ThkTree 当前是 Flutter Material 3 实现，但产品定位是 **iOS-only**（iPhone + iPadOS），目标设备 iPhone 17 / iOS 26。Material 风格 AppBar、FAB、ListTile、Switch、AlertDialog 在 iOS 上"一眼安卓"，需要彻底迁到 Cupertino。

**目标**：以最小代价让所有屏幕看起来"原生 iOS"，保持业务逻辑零改动；不做暗黑模式、不上 Liquid Glass，按 iOS 默认设计语言落地。

**非目标**：
- ❌ Android / Web / 桌面适配
- ❌ Dark Mode（Phase 2 再考虑）
- ❌ Liquid Glass / iOS 26 专属视效
- ❌ 重构 Riverpod 状态层 / 路由 / 数据层
- ❌ 加新功能

---

## 1. 设计基线（已锁定）

| 维度 | 决策 | 备注 |
|---|---|---|
| 顶层 App | `CupertinoApp.router` | 替换 `MaterialApp.router`，保留 go_router |
| 主题 | `CupertinoThemeData`，`brightness: light` | 单一亮色，暂不做 dark |
| 主色 | `CupertinoColors.systemBlue` (#007AFF) | iOS 默认蓝，零品牌色 |
| 字体 | `.SF Pro Text` / `.SF Pro Display` + `PingFang SC` | iOS 系统自带，无需打包 ttf |
| 图标 | SF Symbols（`flutter_sficon`） | 默认 Outline，选中态 Filled |
| 导航栏 | 列表层 Large Title，详情层 Inline Title | 滚动时自动收起 |
| 列表 | inset grouped（圆角分组），分隔线 indent 56 | 替代 ListView+ListTile 直筒列表 |
| 弹层 | `CupertinoAlertDialog`（确认）+ `CupertinoActionSheet`（多选） | 不再用 Material AlertDialog |
| 开关 | `CupertinoSwitch` | 不要 `Switch.adaptive` 折中 |
| 触觉 | `HapticFeedback.selectionClick / lightImpact` | 选中、确认、删除时触发 |
| 页面切换 | `CupertinoPageRoute`（自带右滑返回） | go_router 改 page builder |
| 取消 FAB | 全部移到导航栏右上 `+` | iOS HIG 不存在 FAB |
| `flutter_platform_widgets` | 不引 | iOS-only 项目无需双端分流 |

---

## 2. 工程结构（迁移后）

```
lib/ui/
├── core/
│   ├── theme/
│   │   ├── app_theme.dart            ← NEW · CupertinoThemeData + 文本/颜色 token
│   │   └── app_icons.dart            ← NEW · SF Symbols 常量映射
│   ├── shared/                       ← 沿用，但内部 widget 全部 Cupertino 化
│   │   ├── chat_composer.dart
│   │   ├── chat_list_view.dart
│   │   └── message_bubble.dart
│   ├── widgets/                      ← NEW · iOS 通用件
│   │   ├── thk_nav_bar.dart          ← Large/Inline 双模 NavBar
│   │   ├── thk_list_section.dart     ← inset grouped 分组容器
│   │   ├── thk_list_tile.dart        ← 替代 ListTile，trailing chevron.right
│   │   ├── thk_button.dart           ← filled / tinted / plain 三态
│   │   ├── thk_alert.dart            ← Cupertino AlertDialog 封装
│   │   ├── thk_action_sheet.dart     ← Cupertino ActionSheet 封装
│   │   └── thk_text_field.dart       ← CupertinoTextField + 自动隐藏键盘
│   ├── app_logger.dart               ← 不动
│   ├── app_paths.dart                ← 不动
│   ├── app_services.dart             ← 不动
│   └── router.dart                   ← 改：所有路由换 CupertinoPage
└── features/                         ← 按 PR 3 分批迁移
```

---

## 3. PR 拆分总览

| # | 名称 | 工作量 | 依赖 | 状态 |
|---|---|---|---|---|
| PR 1 | 基建：CupertinoApp + 主题 + SF Symbols | 0.5d | — | ⬜ 待开工 |
| PR 2 | 共享 widget（7 件套） | 1.5d | PR 1 | ⬜ |
| PR 3.1 | SettingsScreen 迁移 | 0.5d | PR 2 | ⬜ |
| PR 3.2 | LlmProvidersScreen + Detail | 0.5d | PR 2 | ⬜ |
| PR 3.3 | ThemeListScreen + Detail | 0.5d | PR 2 | ⬜ |
| PR 3.4 | Notes 三屏 + LocationPicker | 0.5d | PR 2 | ⬜ |
| PR 3.5 | ChatScreen + ModelSelectorPanel | 1d | PR 2 | ⬜ |
| PR 3.6 | SummaryChatScreen | 0.5d | PR 3.5 | ⬜ |
| PR 4 | 体验细节：滑动返回 / 触觉 / 键盘 | 0.5d | PR 3.* 全部完成 | ⬜ |
| PR 5 | 收尾：删 Material import / 测试更新 / analyze | 0.5d | PR 4 | ⬜ |

**总工时**：约 6 个工作日。

---

## 4. PR 详情

### PR 1 · 基建（不动业务代码，肉眼可见 = 字体变 SF + 按钮变蓝）

**目标**：app 能启动，`CupertinoApp.router` 接管，所有页面字体颜色基线变化；视觉违和先不消除。

**任务**：

- [ ] 1.1 `pubspec.yaml`：新增依赖
  - `flutter_sficon: ^x.x.x`（SF Symbols 字体包）
- [ ] 1.2 新建 [lib/ui/core/theme/app_theme.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/core/theme/app_theme.dart)：
  - `CupertinoThemeData` 实例
  - `primaryColor: CupertinoColors.systemBlue`
  - `textTheme.textStyle.fontFamily: '.SF Pro Text'`、`fallback: ['PingFang SC']`
  - 暴露 8 个文本 token（largeTitle / title1 / headline / body / callout / subhead / footnote / caption1）按 iOS HIG 字号
- [ ] 1.3 新建 [lib/ui/core/theme/app_icons.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/core/theme/app_icons.dart)：
  - 把当前用到的 30+ 个 Material Icon 映射到 SF Symbols 名（如 `Icons.chevron_right` → `chevron.right`，`Icons.cloud` → `icloud`）
  - 集中常量，方便日后批量调整粗细
- [ ] 1.4 改 [lib/main.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/main.dart)：
  - 删 `import 'package:flutter/material.dart'`（仅保留 `WidgetsFlutterBinding`，从 `flutter/widgets.dart` 取）
  - `MaterialApp.router` → `CupertinoApp.router`，注入 `AppTheme.light`
  - 保留 `localizationsDelegates`（含 `GlobalCupertinoLocalizations`）
- [ ] 1.5 临时兜底：因为有些子页还在用 `Scaffold/AppBar`，`CupertinoApp` 里它们会缺 `Material` 祖先；在迁完前用 `MaterialApp` → `CupertinoApp + builder: (ctx, child) => Material(child: child)` 做临时 wrapper（PR 5 会移除）

**验收**：
- `flutter run` 可启动
- 所有页面字体变成 SF Pro / PingFang
- `flutter analyze` 0 error

**回滚**：仅一个 commit，`git revert` 即可。

---

### PR 2 · 共享 widget 7 件套（视觉级冲击在这）

**目标**：把 iOS 5 大基础控件 + 2 个高频件统一好，后续 PR 3 只是拼装。

**任务**：

- [ ] 2.1 `ThkNavBar`：
  - 接受 `largeTitle / title / leading / trailing / previousPageTitle` 参数
  - 内部根据 `isLarge` 切换 `CupertinoNavigationBar` vs `CupertinoSliverNavigationBar`
  - 默认背景：`systemBackground` + 滚动时自动 hairline
- [ ] 2.2 `ThkListSection`：
  - 接受 `header / footer / children`
  - 子项之间自动加 hairline divider（indent: 16），最后一项不加
  - 圆角 10，外边距 horizontal 16 vertical 8
  - 背景 `secondarySystemGroupedBackground`
- [ ] 2.3 `ThkListTile`：
  - 标题、副标题、leading icon、trailing（默认 `chevron.right`）
  - 高度 44 标准 / 52 双行
  - 整体可点击，按下时背景 `systemFill` 闪一下
- [ ] 2.4 `ThkButton`：
  - 三档：`filled`（蓝底白字）/ `tinted`（浅蓝底蓝字）/ `plain`（纯蓝字）
  - 标准高度 50 / 紧凑 36
  - destructive 变体：红色
- [ ] 2.5 `ThkAlert`：
  - 包装 `showCupertinoDialog`，API 与现有 `showDialog<T>(...)` 类似
  - 支持 cancel / confirm / destructive 三种 action
- [ ] 2.6 `ThkActionSheet`：
  - 包装 `showCupertinoModalPopup` + `CupertinoActionSheet`
  - 用于：语言选择 / 删除确认 / 节点操作
- [ ] 2.7 `ThkTextField`：
  - 包装 `CupertinoTextField`
  - 默认带 `decoration: BoxDecoration(...)` 圆角 10、`systemFill` 背景
  - 内置 done 键盘 toolbar（iOS 键盘没有 Android 的"完成"按钮）

**验收**：
- 每个 widget 配独立 widget preview（用 `flutter-add-widget-preview` skill）
- 视觉对照 iOS Settings / Notes / Reminders 系统 app 的同类件，肉眼无明显差异

---

### PR 3 · 屏幕迁移（按"风险递增"顺序）

每个子 PR 套路一致：替换 NavBar、替换 ListTile、替换 Dialog、删除 FAB。

#### PR 3.1 SettingsScreen
- [ ] 替换 `Scaffold + AppBar` → `CupertinoPageScaffold + ThkNavBar(largeTitle)`
- [ ] `_LanguageTile / _LlmProvidersEntry / _LogsTile / _PathsTile` → `ThkListSection + ThkListTile`
- [ ] 语言选择 dialog → `ThkActionSheet`
- [ ] LogsTailDialog → 改 `CupertinoPageScaffold` 全屏页（iOS 习惯）

#### PR 3.2 LlmProvidersScreen / LlmProviderDetailScreen
- [ ] 列表页：FAB 删除，`+` 移到 NavBar 右上
- [ ] 详情页：TextField 全部换 `ThkTextField`
- [ ] CheckboxListTile → `ThkListTile + trailing checkmark`（iOS 没有方形 checkbox）
- [ ] 删除按钮 → `ThkButton(destructive)`

#### PR 3.3 ThemeListScreen / ThemeDetailScreen
- [ ] FAB → NavBar 右上 `+`
- [ ] Tree row 的 IconButton → `CupertinoButton(padding: zero)` + SF Symbol
- [ ] CustomPaint 树连接线先保留，颜色取 `separator`
- [ ] 删除节点 dialog（含 Checkbox 确认） → `ThkAlert` + 自定义 content

#### PR 3.4 NoteBrowse / ThemeNoteList / NoteDetail / NoteSelect / NodeLocationPicker
- [ ] `ListTile + Divider` → `ThkListSection + ThkListTile`
- [ ] NoteDetail 的 read/edit toggle 按钮放 NavBar 右上
- [ ] NodeLocationPicker 用 `CupertinoSheetRoute`（iOS 16+ 原生 sheet）替代当前 `showModalBottomSheet`

#### PR 3.5 ChatScreen + ChatComposer + MessageBubble + ModelSelectorPanel ⚠️ 最复杂
- [ ] NavBar 改 inline + 副标题（modelSubtitle 显示模型名）
- [ ] ChatComposer 输入框换 `ThkTextField`，发送按钮 → `CupertinoButton.filled`
- [ ] MessageBubble 颜色：user `systemBlue` / assistant `systemGray6`，圆角 18，气泡尾巴**不画**（iOS 默认无）
- [ ] ContextUsageBar 颜色保留三档（teal/orange/red）
- [ ] ModelSelectorPanel 上推面板保留之前的"上推式布局"决策（参考 important_decision_experience），但容器换 `BackdropFilter` + `systemBackground 80% opacity`

#### PR 3.6 SummaryChatScreen
- [ ] Banner 容器：`secondarySystemBackground` + 圆角 10
- [ ] Action Row：4 个 OutlinedButton → `ThkButton(plain/tinted/filled)` 三档
- [ ] 顶部 close 按钮风格统一

---

### PR 4 · 体验细节

- [ ] 4.1 全局换 `CupertinoPageRoute`：go_router `pageBuilder` 用 `CupertinoPage<T>`
- [ ] 4.2 触觉反馈封装：`HapticService.selection() / impact() / notification()`
  - 接入点：模型选中、语言切换、删除确认、发送消息
- [ ] 4.3 键盘体验：所有 TextField 失焦点击外部隐藏（已有规范，确保 PR 1-3 引入的 `ThkTextField` 默认带）
- [ ] 4.4 SafeArea 检查：刘海/灵动岛/底部 home indicator 不被遮挡

---

### PR 5 · 收尾

- [ ] 5.1 全文搜索 `import 'package:flutter/material.dart'`，删除所有未使用项
  - 例外：`Colors`、`Icons`（如果仍有过渡使用）需逐个评估
- [ ] 5.2 删除 PR 1.5 的 `Material` builder 兜底
- [ ] 5.3 更新 widget tests（`test/ui/`）
  - `ThemeListScreen` test 里 `find.byType(AppBar)` → `find.byType(ThkNavBar)`
  - `ChatComposer` test 中 `FilledButton` → `ThkButton`
- [ ] 5.4 跑 `flutter analyze`，确保 0 warning
- [ ] 5.5 真机过一遍 5 个高频路径：
  1. 新建 Theme → 进入 → 新对话 → 发送消息
  2. Settings → 切换语言 → 验证文案
  3. Settings → LLM Providers → 添加自定义 → 拉取模型 → 选择
  4. 笔记浏览 → 创建笔记 → 编辑 → 保存
  5. 长对话 → 总结 → 创建分支
- [ ] 5.6 commit & tag `v0.2.0-cupertino`

---

## 5. 风险与回滚

| 风险 | 等级 | 应对 |
|---|---|---|
| `CupertinoApp` 缺 `Material` 祖先导致部分子件崩溃 | 高 | PR 1.5 临时 wrapper 兜底，PR 5 移除 |
| SF Symbols 字号与 Material Icons 视觉重量差异，破坏布局 | 中 | PR 1.3 集中映射 + PR 2 视觉对齐 |
| `CupertinoSliverNavigationBar` 与 `CustomScrollView` 强绑定，普通 `ListView` 不兼容 | 中 | `ThkNavBar` 内部用 `NestedScrollView` 桥接 |
| go_router CupertinoPage 切换后老 widget test 中 `Navigator.pop` 行为变化 | 低 | PR 5.3 集中修测 |
| flutter_sficon 包体积 / iOS 启动时间影响 | 低 | 实测对比，必要时改为按需加载子集 |

**回滚策略**：每个 PR 都是独立分支单独 review、单独合并。出现问题直接 `git revert <merge-commit>`，不影响后续 PR 的存量代码。

---

## 6. 当前状态追踪

| 阶段 | 状态 | 完成日期 | 备注 |
|---|---|---|---|
| 计划撰写 | ✅ | 2026-05-30 | 本文档 |
| PR 1 基建 | ⬜ | — | — |
| PR 2 共享件 | ⬜ | — | — |
| PR 3.1 Settings | ⬜ | — | — |
| PR 3.2 LLM | ⬜ | — | — |
| PR 3.3 Themes | ⬜ | — | — |
| PR 3.4 Notes | ⬜ | — | — |
| PR 3.5 Chat | ⬜ | — | — |
| PR 3.6 Summary | ⬜ | — | — |
| PR 4 体验 | ⬜ | — | — |
| PR 5 收尾 | ⬜ | — | — |

> 每完成一个 PR，回到本表勾选 ✅ 并在 commit message 里引用 `Closes ios-migration-plan §3.X`。
