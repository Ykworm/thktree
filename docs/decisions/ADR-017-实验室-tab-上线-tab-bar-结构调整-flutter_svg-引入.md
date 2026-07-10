## ADR-017: 实验室 tab 上线 + tab bar 结构调整 + flutter_svg 引入

2026-06-28 决定。三项独立但同窗合并的高阶决策：(1) 实验室 tab 入口上线，(2) tab bar 4→5 结构调整，(3) `flutter_svg` 首次引入。

(1) **实验室 tab 上线**——承接 P.9 暂缓卡（[docs/_tmp/2026-06-24-lab-tab-brainstorm.md](_tmp/2026-06-24-lab-tab-brainstorm.md)）的"明日入口"决策，本期先落地入口层（tab + 占位页 + 资产 + l10n），子功能（功能市集 / flutter_genui 演示）作为下一轮独立议题再起 `codex/lab-*` 分支推进。理由：tab 入口是"先有位置再有内容"的低风险占位，子功能涉及方案 A/B/C 选型 + `flutter_genui` v0.9.2 高度实验性 + 5 个子功能候选，混在一起做会拖慢合并节奏。先上入口、可回滚（删 branch + 资产）= 低风险；先上子功能 = 风险不可控。子功能启动条件：(a) 入口使用率数据支持（埋点后再决定）；或 (b) 有具体 use case 明确要做的子功能。

(2) **tab bar 结构调整 4→5**——加在主题与设置之间。5 个 tab 顺序：搜索 / 主题 / 笔记 / **实验室** / 设置。顺序考虑：实验室是"实验性 / 非主线"功能，放在笔记（主线最后一项）与设置（系统）之间，弱化视觉权重 + 物理上距离主功能远，避免用户频繁误触。影响范围：`lib/ui/core/router.dart`（StatefulShellRoute 加 StatefulShellBranch，parentNavigatorKey + pageBuilder + CupertinoPage） + 所有引用 `_tabIndex` 的 widget（如果有）需重新映射 + iOS 底部安全区适配（5 tab 比 4 tab 横向间距略紧，可接受）。

(3) **`flutter_svg` 引入**——本期仅 1 个 svg 资源（`assets/icons/theme_unselect.svg`）用于主题 tab 未选图标。理由：svg 矢量缩放在 iPhone 6 Plus 等大屏 + 后续 iPad 适配时比 png 清晰；当前 Figma 导出流程原生支持 svg。代价：release 包体积增加（预估 1-2MB），`flutter_svg` 自带 libxml2 解析。后续决策点：如果 svg 资源长期保持 1-2 个，需重新评估 ROI（可能换回 png@3x + `flutter_gen`）。

**顶栏改红（已知设计偏差）**：同期在 `lib/ui/core/widgets/thk_nav_bar.dart` 临时把 bar 背景色换为 `AppColors.destructive`（#DC2626），与 [`docs/_shared/design-system.md` §2.4](_shared/design-system.md) 的"destructive = 危险操作（删除按钮）"约束冲突——本次属于借用语义。**不在本 ADR 范围**（属于 UI 试验性改动），详见 [CHANGELOG/2026-06-28-lab-tab-and-bar-red.md](CHANGELOG/2026-06-28-lab-tab-and-bar-red.md) § 已知风险 + [docs/FEATURES.md](FEATURES.md) 最近变更条目。下期 product review 时决定保留 / 回滚 / 新增 `accentBar` token。

影响范围：`lib/ui/core/router.dart`（StatefulShellRoute 加 lab branch） + `lib/ui/core/theme/app_icons.dart`（新增 `AppIcons.lab` = `SFIcons.sf_flask`） + `lib/ui/features/lab/lab_placeholder_screen.dart`（新增占位页） + `lib/l10n/app_en.arb` + `lib/l10n/app_zh.arb`（新增 `labTabTitle` / `labTabTitleZh` key） + `assets/icons/lab_selected.png` + `assets/icons/lab_unselect.png`（Figma 导出） + `assets/icons/theme_unselect.svg`（Figma 导出） + `pubspec.yaml`（新增 `flutter_svg: ^2.0.10`） + `integration_test/lab_tab_test.dart`（新增，4 case：tab 显示 / 切换 / 占位页内容 / 选中态图标）+ `integration_test/theme_tab_icon_test.dart`（新增，4 case：未选 svg 渲染 / 选中 SF Symbol / 切换保持 / 渲染性能）。

实施要点：tab 接入走 `StatefulShellRoute.indexedStack` + `StatefulShellBranch` + `parentNavigatorKey: rootNavigatorKey`（与 settings 一致），`pageBuilder` 用 `CupertinoPage` 而非 `NoTransitionPage`（保持 push 动画）。l10n key 命名遵循 `labTabTitle`（英文显示用，枚举风）+ `labTabTitleZh`（中文显示用，备注）——`ThemeStore` / 主题相关本地化历史遗留，实际仅 1 个 key 双语。占位页用 `ThkNavBar` + `Center(Text(...))`，不引入新组件。集成测试遵循 `createTestApp(locale: Locale('zh'))` + `pumpAndSettle` + `find.byType(SvgPicture)` + `find.byWidgetPredicate(...)` 模式（与既有 `theme_chat_e2e_test.dart` 一致）。

### ADR-017 修订（2026-06-29）：tab label 统一 + 占位屏视觉规范化

2026-06-29 决定。两项细节修订，不改变 ADR-017 的三项主决策。

**tab label 统一**——中英文均使用 "Lab"。`app_zh.arb::labTabLabel` 由 "实验室" 改为 "Lab"（与 `app_en.arb` 对齐）。原因：英文原生就是 "Lab"，中文 "实验室" 在 30pt tab 横向约束下字宽过大、视觉失衡；统一 "Lab" 后 5 个 tab 字宽更接近。

**占位屏视觉规范化**——`LabPlaceholderScreen` 用 `AppColors.surface` 兜底（light #FFFFFF / dark #0F172A），顶部展示 `l10n.labEmptyHint` 占位文案，下方居中展示 `assets/background/lab_bg_32pt.png` 装饰图（`BoxFit.contain` 保持比例，不撑满）。原因：原 `ThkNavBar + Center Text` 视觉单薄；借助 ADR-017 引入的 `lab_bg_32pt.png` 资产做装饰，同时 `AppColors.surface` dark #0F172A 让暗色模式继承一致。放弃之前的 "`Image.asset + Positioned.fill` 当整页 background" 方案——窄屏拉伸变形，违背装饰图设计意图。

影响范围：`lib/l10n/app_zh.arb` + `lib/l10n/generated/app_localizations_zh.dart` + `lib/ui/features/lab/lab_placeholder_screen.dart`（重写 build 为 `Column` 布局）+ `integration_test/lab_tab_test.dart`（断言同步 `find.text('Lab')`）。

实施要点：构建走 `CupertinoPageScaffold(backgroundColor: AppColors.surface)` + `SafeArea(Column([顶部 hint Padding + 下方 Expanded(Align.topCenter, Image.asset)]))`；`BoxFit.contain` 保持原比例，居顶对齐让图片从导航栏下方自然过渡。详见 [CHANGELOG/2026-06-29-lab-tab-white-bg.md](CHANGELOG/2026-06-29-lab-tab-white-bg.md)。
