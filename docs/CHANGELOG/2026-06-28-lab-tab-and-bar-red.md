# 实验室 tab 上线 + tab bar 改红

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-28 |
| 范围 | 导航（tab bar 结构调整 + bar 改红）+ 实验室模块（占位） |
| 设计文档 | [`docs/_tmp/2026-06-24-lab-tab-brainstorm.md`](../_tmp/2026-06-24-lab-tab-brainstorm.md)（brainstorming 草稿，本期不清理） |
| War Story | （无） |
| 状态 | ✅ 完成（含 1 项已知设计偏差，见 § 已知风险） |

## 背景

P.9 暂缓卡（2026-06-24 brainstorming）保留"明日入口"作为重启起点。本期承接该决策，先把**入口层**落地（tab + 占位页 + 资产 + l10n），子功能（功能市集 / flutter_genui 演示）作为下一轮独立议题再做。

同期还有两项零碎改动借这次合并的窗口一起做：

- 主题 tab 的未选图标用 svg 替换 png（缩放时更清晰）
- 顶栏背景色临时换红（产品视觉试验，下期复盘是否保留）

## 方案

**实验室 tab**——5 个 tab（搜索 / 主题 / 笔记 / **实验室** / 设置），新增 `LabPlaceholderScreen` 占位页 + `AppIcons.lab`（sf_flask）+ 中英 l10n。资产 `lab_selected.png` + `lab_unselect.png` 由 Figma 导出。

**主题 tab 未选图标**——从 png 切换为 svg。`flutter_svg: ^2.0.10` 引入，tab bar 未选态改用 `SvgPicture.asset`。选中态仍用 `flutter_sficon`（保持 SF Symbol 风格一致）。

**顶栏改红**——`lib/ui/core/widgets/thk_nav_bar.dart` 的 bar 背景色临时用 `AppColors.destructive`（#DC2626）。**这是已知设计偏差**，见 § 已知风险。

## 实施内容

### 修改文件（14）

```
assets/icons/lab_selected.png                  # 新增：实验室 tab 选中态
assets/icons/lab_unselect.png                  # 新增：实验室 tab 未选态
assets/icons/theme_unselect.svg                # 新增：主题 tab 未选 svg 图标
integration_test/lab_tab_test.dart             # 新增：实验室 tab 集成测试（4 case）
integration_test/theme_tab_icon_test.dart      # 新增：主题 tab 图标集成测试（4 case）
lib/l10n/app_en.arb                            # 新增 labTabTitle / labTabTitleZh
lib/l10n/app_zh.arb                            # 新增 labTabTitle / labTabTitleZh
lib/l10n/generated/app_localizations.dart      # 重新生成
lib/l10n/generated/app_localizations_en.dart   # 重新生成
lib/l10n/generated/app_localizations_zh.dart   # 重新生成
lib/ui/core/router.dart                        # StatefulShellRoute 加 lab branch + tab 4→5
lib/ui/core/theme/app_icons.dart               # 新增 AppIcons.lab (sf_flask)
lib/ui/core/widgets/thk_nav_bar.dart           # 顶栏背景色临时换 destructive
lib/ui/features/lab/lab_placeholder_screen.dart # 新增：占位页
pubspec.yaml                                   # 新增 flutter_svg: ^2.0.10
```

### 关键改动

**`router.dart` —— 5 个 tab：**

```dart
StatefulShellRoute.indexedStack(
  branches: [
    StatefulShellBranch(... search ...),
    StatefulShellBranch(... topics ...),
    StatefulShellBranch(... notes ...),
    StatefulShellBranch(routes: [
      GoRoute(
        path: '/lab',
        pageBuilder: (context, state) => const CupertinoPage(
          child: LabPlaceholderScreen(),
        ),
      ),
    ]),
    StatefulShellBranch(... settings ...),
  ],
)
```

**`lab_placeholder_screen.dart` —— 占位屏**：

```dart
class LabPlaceholderScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: ThkNavBar(title: AppLocalizations.of(context).labTabTitle),
      child: Center(
        child: Text(AppLocalizations.of(context).labTabTitleZh),
      ),
    );
  }
}
```

**`thk_nav_bar.dart` —— 临时改红**：

```dart
// 临时：本期试验性改动，下期决定是否回滚
backgroundColor: AppColors.destructive,  // 临时顶栏色
```

**`app_icons.dart` —— 新增 lab**：

```dart
static const lab = SFIcons.sf_flask;
```

## 验证

| 类别 | 状态 |
|---|---|
| `flutter analyze` | ✅ 无错（增量） |
| 集成测试 | ✅ 8 个 testWidgets 全绿（lab_tab_test 4 case + theme_tab_icon_test 4 case） |
| 场景覆盖（手工） | ① 启动后 tab bar 显示 5 个 tab ② 切换实验室 tab → 显示占位页 ③ 切换主题 tab → 未选图标用 svg 渲染 ④ 顶栏背景色为红色 |

## 文档同步

`context-sync` 同步至：

- `docs/FEATURES.md` § 8 新增实验室模块行 + 最近变更倒序首行
- `docs/DECISIONS.md` 新增 ADR-017
- `docs/_shared/design-system.md` §5.2 Tab Bar Icons 表格新增 Lab 行
- `docs/_shared/design-tokens.yaml` §8 icons 新增 lab + themeUnselectSvg 两条
- `docs/modules/lab/README.md` 新建
- 本 CHANGELOG

## 已知风险（留给后续决定）

- **顶栏改红与 design-system §2.4 destructive 约束冲突**：`AppColors.destructive`（#DC2626）在 [`docs/_shared/design-system.md` §2.4](../_shared/design-system.md) + [`docs/_shared/design-tokens.yaml` §1](../_shared/design-tokens.yaml) + `docs/_shared/design-system-legacy.md` 都明确定义为"危险操作（删除按钮）"。本次临时用来给顶栏上色属于**借用语义**——视觉上没问题，但与 token 设计意图冲突。后续需要：
  - 选项 A：保留 destructive 用法 → 需在 `docs/_shared/design-system.md` §2.4 注明"destructive 也可用于顶栏强调"（拓宽语义）
  - 选项 B：回滚到 surface 中性色 → 顶栏改回中性
  - 选项 C：新增 `accentBar` token → destructive 留作"危险操作专用"，顶栏色独立
  - **当前选择**：保留 A 状态（含风险），下期 product review 时决定
- **`flutter_svg` 依赖体量评估**：`flutter_svg: ^2.0.10` 是首次引入，会增加 release 包体积（预估 1-2MB）。当前仅用于 1 个 svg 图标（`theme_unselect.svg`），ROI 不高。后续如引入更多 svg 资源则可接受；如果仅 1-2 个，可考虑 `flutter_gen` 改回 png@3x
- **lab 占位实现**：`LabPlaceholderScreen` 仅显示静态文字，无交互、无子模块路由。子功能候选（功能市集 / flutter_genui 演示 / etc.）见 [brainstorm 草稿](../_tmp/2026-06-24-lab-tab-brainstorm.md)，**不**在本期范围
- **design-system §5.2 中性色未列 Lab**：本期仅在 Tab Bar Icons 表格新增 Lab 行的"图形 / 未选中 / 选中"信息，顶栏色未在 design-system 单独说明（避免污染规范文档），详见上条 § 已知风险

## 关联

- [`docs/_tmp/2026-06-24-lab-tab-brainstorm.md`](../_tmp/2026-06-24-lab-tab-brainstorm.md) — brainstorming 草稿（**本期不清理**，作为下次重启入口）
- [`docs/DECISIONS.md`](../DECISIONS.md) ADR-017 — 实验室 tab 上线 + tab bar 结构调整 + flutter_svg 引入
- [`docs/modules/lab/README.md`](../modules/lab/README.md) — lab 模块说明（新建）
- [`docs/_shared/design-system.md`](../_shared/design-system.md) §5.2 — Tab Bar Icons 表格
- [`docs/_shared/design-tokens.yaml`](../_shared/design-tokens.yaml) §8 — icons
