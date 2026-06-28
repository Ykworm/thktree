# 实验室模块（lab）

> 实验室是 ThkTree 的"实验场"——承载新功能 / 高级用户工具 / 第三方集成的试用入口。**当前为占位实现**，子功能候选方案待下一轮单独讨论。
> 维护者：人类 + AI 共同维护。子功能上线时同步更新本 README。

> ⚠️ **AI 改模块前必读**
> 1. **当前为占位屏**——`LabPlaceholderScreen` 仅显示静态文案，没有交互逻辑、没有子模块路由。任何扩展必须先回到 brainstorming 流程。
> 2. **子功能候选方案**见 [`docs/_tmp/2026-06-24-lab-tab-brainstorm.md`](../../_tmp/2026-06-24-lab-tab-brainstorm.md)，包含 5 个候选方向（功能市集 / flutter_genui 演示 / etc.）+ 方案 A 锁定理由。
> 3. **不要直接修改占位屏**——本期目的是"先有位置再有内容"，子功能未敲定前不要先动占位屏文案。
> 4. 视觉规范与主壳一致（见 [`docs/_shared/design-system.md`](../../_shared/design-system.md)），tab bar 颜色与未选 svg 图标由 `_shared` 决定。

## 1. 职责

| 屏幕 | 职责 |
|------|------|
| **LabPlaceholderScreen** | 实验室 tab 的占位屏，显示静态文案 |

## 2. 功能列表

> 完整状态见 [`../../FEATURES.md`](../../FEATURES.md) § 8.

| Feature | 状态 | 最后更新 | 备注 |
|---------|------|----------|------|
| 实验室 tab 入口 | ✅ 完成 | 2026-06-28 | `LabPlaceholderScreen` 占位页 + `AppIcons.lab`（sf_flask）+ 中英 l10n |
| 子功能候选 | 📋 待开发 | — | 5 个候选方向见 [brainstorm 草稿](../../_tmp/2026-06-24-lab-tab-brainstorm.md)，需另起 `codex/lab-*` 分支推进 |

## 3. 代码文件

```
lib/ui/features/lab/
└── lab_placeholder_screen.dart   # 32 行：占位页（ThkNavBar + Center Text）
```

依赖：

- `lib/ui/core/widgets/thk_nav_bar.dart`（顶栏，临时改红，见 [CHANGELOG/2026-06-28](../../CHANGELOG/2026-06-28-lab-tab-and-bar-red.md) § 已知风险）
- `lib/ui/core/theme/app_icons.dart`（`AppIcons.lab` = `SFIcons.sf_flask`）
- `lib/ui/core/router.dart`（lab branch 注册在 `StatefulShellRoute.indexedStack` 第 4 位）
- `lib/l10n/`（`labTabTitle` / `labTabTitleZh`）

## 4. 子文档

| 文档 | 路径 | 说明 |
|------|------|------|
| 子功能 brainstorm 草稿 | [_tmp/2026-06-24-lab-tab-brainstorm.md](../../_tmp/2026-06-24-lab-tab-brainstorm.md) | 5 个子功能候选 + 方案 A 锁定 + 暂缓原因 |
| 本期 changelog | [CHANGELOG/2026-06-28-lab-tab-and-bar-red.md](../../CHANGELOG/2026-06-28-lab-tab-and-bar-red.md) | 入口层落地详情 + 已知风险（顶栏改红 / flutter_svg 依赖体量） |
| Tab bar 决策 | [DECISIONS.md ADR-017](../../DECISIONS.md#adr-017-实验室-tab-上线--tab-bar-结构调整--flutter_svg-引入) | 实验室 tab 上线 + tab bar 4→5 + flutter_svg 引入 |

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
- **占位屏改文案**：通过 l10n 改（`app_en.arb` / `app_zh.arb` 的 `labTabTitle` / `labTabTitleZh`），**不要**在 widget 内写硬编码字符串
- **brainstorm 期间**：本 README 与 `docs/FEATURES.md` 的"子功能候选"行**保持 📋 待开发**，不要因为某次探索就把状态切到 🔨

## 7. 相关历史

- **2026-06-28** — 实验室 tab 入口层落地（占位页 + 资产 + l10n），承接 2026-06-24 brainstorming 暂缓卡的"明日入口"决策
- **2026-06-24** — brainstorming 草稿归档（[_tmp/2026-06-24-lab-tab-brainstorm.md](../../_tmp/2026-06-24-lab-tab-brainstorm.md)），方案 A 锁定（功能市集）+ `flutter_genui` v0.9.2 高度实验性 + 5 个子功能候选 + 暂缓原因
