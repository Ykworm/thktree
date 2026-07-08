# 设置页深层导航面包屑

> 日期：2026-07-08

## 问题

从设置页进入模型配置流程最深需要 4 层（Settings → LlmSettings → DefaultModelConfig → DefaultModelPicker）。
每层 push 一次 CupertinoPageRoute，返回只能逐层 pop，选完模型后需要 4 次 swipe 或点返回。

## 方案

在每个深层子页面顶部加面包屑导航行：`设置 / 大模型 / 模型配置`。
点击祖先段 → `Navigator.popUntil(name: routeName)` 直接跳回对应页面，不需要逐层返回。

## 改动

- **新建** `lib/ui/core/widgets/thk_breadcrumb_nav.dart`：`BreadcrumbSegment` 数据模型 + `ThkBreadcrumbRow` 面包屑组件
- **新建** 导出到 `lib/ui/core/widgets/widgets.dart`
- **修改** `settings_screen.dart`：`_LlmSettingsEntry` push 设 `RouteSettings(name: 'llm-settings')` + 传 `parentCrumbs`
- **修改** `llm_settings_screen.dart`：接受 `parentCrumbs`，顶部加面包屑，push `DefaultModelConfigScreen` 时设 `RouteSettings(name: 'default-model-config')` + 传 crumbs
- **修改** `default_model_config_screen.dart`：接受 `parentCrumbs`，顶部加面包屑，push `DefaultModelPickerScreen` 时设 `RouteSettings(name: 'model-picker')` + 传 crumbs
- **修改** `default_model_picker_screen.dart`：接受 `parentCrumbs`，顶部加面包屑
- **修改** `llm_providers_screen.dart`：接受 `parentCrumbs`，顶部加面包屑，push `LlmProviderDetailScreen` 时设 `RouteSettings(name: 'provider-detail')` + 传 crumbs（列表项 + trailing `+` 两处入口）
- **修改** `llm_provider_detail_screen.dart`：接受 `parentCrumbs`，顶部加面包屑

## 完整链路

```
设置 → 大模型 → 模型配置 → 选择模型
设置 → 大模型 → 提供商 → 配置（API Key / 模型列表）
```

## 设计决策

- 只用面包屑，不做级联自动 pop（用户希望保留手动控制权）
- 面包屑放在 SafeArea 内、导航栏下方，作为 body 的第一行
- 不影响 go_router，不需要改动路由注册
- 非 Settings 入口（`llm_setup_check.dart`、`router.dart`、`generate_title_screen.dart`）不传 `parentCrumbs`，无 Settings 祖先链路时不显示面包屑
- go_router 路由（`/settings`）的跳转：~~`Navigator.popUntil(route.isFirst)`~~（已废弃，见下方修复）

## 修复（2026-07-08）：点面包屑"设置"返回崩溃 / 返回按钮消失

**现象**：深层页面点面包屑"设置"段，settings page 顶部返回按钮消失，无法退回 tab bar；或栈被 pop 空触发 `currentConfiguration.isNotEmpty` 断言崩溃。

**根因**：
- `/settings` 配 `parentNavigatorKey: root`，是覆盖在 shell 之上的全屏路由，**不是栈底**。`popUntil(route.isFirst)` 会越过它 pop 到 shell。
- `GoRoute.name` 不传到 Page 的 `RouteSettings.name`，`popUntil(name==)` 永不匹配，栈被 pop 空。

**修复**：
- `router.dart`：`/settings` 的 pageBuilder 里 `CupertinoPage(name: 'settings', ...)`（Page 级 name 传到 `route.settings.name`）
- `settings_screen.dart`：parentCrumbs 的"设置"段 routeName 改 `'settings'`（非 `/` 开头，走 name 匹配分支）
- `thk_breadcrumb_nav.dart`：name 匹配分支注释说明 go_router 路由需在 Page 上设 name；isFirst 兜底分支保留带风险注释

**不用 `context.go` 的原因**：会重置整个路由栈，清掉其它 tab 里 push 的详情页。Page name + popUntil 只 pop 上层手动 route，不影响其它 tab。
