# Lab 模块（lab）

> 实验室是 ThkTree 的"实验场"——承载新功能 / 高级用户工具 / 第三方集成的试用入口。**当前为占位实现**，子功能候选方案待下一轮单独讨论。
> 维护者：人类 + AI 共同维护。子功能上线时同步更新本 README。

> ⚠️ **AI 改模块前必读**
> 1. **当前为功能块卡片布局**——`LabPlaceholderScreen` 显示功能块卡片（`_FeatureCard`），支持滚动，有子模块路由。任何扩展需要考虑卡片布局的扩展性。
> 2. **子功能候选方案**见 [`docs/_tmp/2026-06-24-lab-tab-brainstorm.md`](../../_tmp/2026-06-24-lab-tab-brainstorm.md)，包含 5 个候选方向（功能市集 / flutter_genui 演示 / etc.）+ 方案 A 锁定理由。
> 3. **功能块卡片设计**——使用 `_FeatureCard` 组件，支持图标、标题、描述和点击跳转。
> 4. 视觉规范与主壳一致（见 [`docs/_shared/design-system.md`](../../_shared/design-system.md)），tab bar 颜色与未选 svg 图标由 `_shared` 决定。

## 1. 职责

| 屏幕 | 职责 |
|------|------|
| **LabPlaceholderScreen** | Lab tab 的功能块卡片布局，顶部 `lab_bg_with_title.png` 覆盖灵动岛 + 功能块卡片（`_FeatureCard`）支持滚动 + 状态栏深色背景 |

## 2. 功能列表

> 完整状态见 [`../../FEATURES.md`](../../FEATURES.md) § 8.

| Feature | 状态 | 最后更新 | 备注 |
|---------|------|----------|------|
| Lab tab 入口 | ✅ 完成 | 2026-07-04 | `LabPlaceholderScreen` 功能块卡片布局 + `lab_bg_with_title.png` 覆盖灵动岛 + 状态栏深色背景 + 支持滚动 |
| 子功能候选 | 📋 待开发 | — | 5 个候选方向见 [brainstorm 草稿](../../_tmp/2026-06-24-lab-tab-brainstorm.md)，需另起 `codex/lab-*` 分支推进 |

## 3. 代码文件

```
lib/ui/features/lab/
└── lab_placeholder_screen.dart   # 143 行：功能块卡片布局（lab_bg_with_title.png 覆盖灵动岛 + _FeatureCard 组件 + 支持滚动）
```

依赖：

- `lib/ui/core/theme/app_colors.dart`（`AppColors.surface`、`AppColors.surfaceMuted`、`AppColors.accent` 等）
- `lib/ui/core/theme/app_icons.dart`（`AppIcons.lab` = `SFIcons.sf_flask`）
- `lib/ui/core/router.dart`（lab branch 注册在 `StatefulShellRoute.indexedStack` 第 4 位）
- `lib/l10n/`（`labTabTitle` / `labTabTitleZh`）
- `assets/background/lab_bg_with_title.png`（顶部背景图，覆盖灵动岛）

## 4. 子文档

| 文档 | 路径 | 说明 |
|------|------|------|
| 子功能 brainstorm 草稿 | [_tmp/2026-06-24-lab-tab-brainstorm.md](../../_tmp/2026-06-24-lab-tab-brainstorm.md) | 5 个子功能候选 + 方案 A 锁定 + 暂缓原因 |
| 本期 changelog | [CHANGELOG/2026-06-28-lab-tab-and-bar-red.md](../../CHANGELOG/2026-06-28-lab-tab-and-bar-red.md) | 入口层落地详情 + 已知风险（顶栏改红 / flutter_svg 依赖体量） |
| Tab bar 决策 | [DECISIONS.md ADR-017](../../DECISIONS.md#adr-017-实验室-tab-上线--tab-bar-结构调整--flutter_svg-引入) | Lab tab 上线 + tab bar 4→5 + flutter_svg 引入（2026-06-29 修订见 ADR 末尾） |

## 5. 关键设计原则

### 5.1 入口层先行

- tab bar 加在主题与设置之间，弱化视觉权重（实验性功能不抢主线）
- 占位屏不引入新组件、不加交互
- 子功能方案敲定前不做任何"先动一下"式微调（避免在 brainstorm 期间污染基线）

### 5.2 与主壳一致的视觉规范

- 顶栏 / 列表 / 按钮 / icon 全部走 [`docs/_shared/design-system.md`](../../_shared/design-system.md) + [`docs/_shared/design-tokens.yaml`](../../_shared/design-tokens.yaml)
- **不在本模块**自创颜色 / 间距 / 字号

## 6. 维护要点

- **子功能新增**：在 `lib/ui/features/lab/` 加 screen + 子路由；本 README § 3 更新文件清单 + § 2 功能表格新增行；`docs/FEATURES.md` § 8 状态从 📋 切到 🔨 / ✅
- **功能块卡片扩展**：如需添加新的功能块，直接在 `LabPlaceholderScreen` 的 `Column` 中添加新的 `_FeatureCard` 组件
- **背景图更新**：如需更换顶部背景图，修改 `assets/background/lab_bg_with_title.png`，确保图片尺寸适合覆盖灵动岛区域
- **状态栏样式**：如需调整状态栏样式，修改 `AnnotatedRegion<SystemUiOverlayStyle>` 中的配置
- **brainstorm 期间**：本 README 与 `docs/FEATURES.md` 的"子功能候选"行**保持 📋 待开发**，不要因为某次探索就把状态切到 🔨

## 7. 相关历史

- **2026-07-04** — Lab page UI 重设计：从占位屏改为功能块卡片布局（`_FeatureCard` 组件），顶部使用 `lab_bg_with_title.png` 覆盖灵动岛区域，状态栏设置深色背景（`#0F1035`）和浅色图标，支持滚动内容。详见 commit `31b201d`
- **2026-06-29** — Lab tab 视觉规范化：tab label 中英文统一为 "Lab"，`LabPlaceholderScreen` 改为白底（`AppColors.surface`）兜底 + 顶部 hint 文字 + 下方 `assets/background/lab_bg_32pt.png` 装饰图（`BoxFit.contain` 保持比例，不撑满）。详见 [CHANGELOG/2026-06-29-lab-tab-white-bg.md](../../CHANGELOG/2026-06-29-lab-tab-white-bg.md)
- **2026-06-28** — Lab tab 入口层落地（占位页 + 资产 + l10n），承接 2026-06-24 brainstorming 暂缓卡的"明日入口"决策
- **2026-06-24** — brainstorming 草稿归档（[_tmp/2026-06-24-lab-tab-brainstorm.md](../../_tmp/2026-06-24-lab-tab-brainstorm.md)），方案 A 锁定（功能市集）+ `flutter_genui` v0.9.2 高度实验性 + 5 个子功能候选 + 暂缓原因
