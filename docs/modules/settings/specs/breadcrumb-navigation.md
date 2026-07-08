# 面包屑导航 — Settings 深层页面快速退出

## 问题

从设置页进入模型配置流程最深需要 4 层（Settings → LlmSettings → DefaultModelConfig → DefaultModelPicker），每层 push 一次 CupertinoPageRoute。返回只能逐层 pop，选完模型后需要 4 次 swipe 或点返回。

## 方案

在每个子页面顶部加面包屑导航行：`设置 / 大模型 / 默认模型 / 选择聊天模型`

- 面包屑是水平排列的一行小字，灰色，用 `/` 分隔
- 当前页不可点击，祖先页可点击
- 点击祖先段 → `Navigator.popUntil(name: routeName)` 直接跳回
- 不需要改 go_router，不需要改 ThkNavBar

## 数据流

每个页面接收 `List<BreadcrumbSegment> parentCrumbs`，加上自己的 segment 后展示，再传给子页面：

```
SettingsScreen._LlmSettingsEntry
  push LlmSettingsScreen(parentCrumbs: [设置])
    push DefaultModelConfigScreen(parentCrumbs: [设置, 大模型])
      push DefaultModelPickerScreen(parentCrumbs: [设置, 大模型, 模型配置])
```

## RouteSettings 命名

每个页面 push 时设 `RouteSettings(name:)` 用于面包屑跳转定位。go_router 路由则在 pageBuilder 的 Page 上设 `name`。

| 页面 | routeName | 路由类型 |
|------|-----------|----------|
| SettingsScreen (go_router) | `settings` | go_router，pageBuilder 的 `CupertinoPage(name: 'settings')` |
| LlmSettingsScreen | `llm-settings` | Navigator.push |
| LlmProvidersScreen | `providers-list` | Navigator.push |
| LlmProviderDetailScreen | `provider-detail` | Navigator.push |
| DefaultModelConfigScreen | `default-model-config` | Navigator.push |
| DefaultModelPickerScreen | `model-picker` | Navigator.push |

## 跳转实现

`ThkBreadcrumbRow._popToRoute` 按 routeName 分流：

- **以 `/` 开头（仅真正位于 navigator 栈底的路由，如 tab 根）**：`Navigator.popUntil((route) => route.isFirst)` — 当前无面包屑使用此分支
- **其他（RouteSettings.name 匹配）**：`Navigator.popUntil((route) => route.settings.name == routeName)` — 精确匹配，停在目标页

> go_router 路由走 name 匹配分支时，必须在 pageBuilder 返回的 **Page** 上设 `name`（如 `CupertinoPage(name: 'settings', ...)`），不能只给 `GoRoute` 设 `name` —— `GoRoute.name` 不会传到 navigator Page 的 `RouteSettings.name`。详见下方「已知陷阱」。

## 改动文件

1. **新建** `lib/ui/core/widgets/thk_breadcrumb_nav.dart` — BreadcrumbSegment + ThkBreadcrumbRow
2. **修改** `lib/ui/features/settings/settings_screen.dart` — _LlmSettingsEntry push 加 RouteSettings + parentCrumbs
3. **修改** `lib/ui/features/settings/llm_settings_screen.dart` — 面包屑 + push 加 RouteSettings + parentCrumbs（两条链路）
4. **修改** `lib/ui/features/settings/default_model_config_screen.dart` — 面包屑 + push 加 RouteSettings + parentCrumbs
5. **修改** `lib/ui/features/settings/default_model_picker_screen.dart` — 面包屑（接收 parentCrumbs）
6. **修改** `lib/ui/features/llm/llm_providers_screen.dart` — 面包屑 + push 加 RouteSettings + parentCrumbs（两处入口）
7. **修改** `lib/ui/features/llm/llm_provider_detail_screen.dart` — 面包屑（接收 parentCrumbs）

## 已知陷阱（2026-07-08 修复）

1. **`/settings` 不是 navigator 栈底**
   `/settings` 配了 `parentNavigatorKey: _rootNavigatorKey`，是覆盖在 StatefulShellRoute（tab bar）之上的全屏路由。栈为 `[shell, /settings, LlmSettings, ...]`，`/settings.isFirst = false`。早期用 `popUntil(route.isFirst)` 想跳回 settings，实际会越过 /settings 一直 pop 到 shell，把 settings 也弹掉（用户表现：settings 返回按钮消失，退不回 tab bar）。

2. **`GoRoute.name` ≠ Page 的 `RouteSettings.name`**
   go_router 的 `GoRoute.name` 只用于 `goNamed`/`pushNamed`，**不会**传到 navigator Page 的 `RouteSettings.name`。曾给 GoRoute 设 `name: 'settings'` 后用 `popUntil(name == 'settings')`，predicate 永不匹配，栈被 pop 空，触发 go_router `currentConfiguration.isNotEmpty` 断言崩溃。修复：在 pageBuilder 的 `CupertinoPage` 上显式设 `name: 'settings'`（Page 级 name 会传到 `route.settings.name`）。

3. **不用 `context.go('/settings')`**
   会重置整个路由栈，副作用是清掉其它 tab 里 push 的详情页。Page name + popUntil 只 pop 上层手动 route，不影响其它 tab。

## 不在此次范围

- go_router 路由层级改动
- 级联自动 pop（用户明确不要）
- `llm_setup_check.dart` / `router.dart` / `generate_title_screen.dart` 中的非 Settings 入口 — 这些入口无 Settings 祖先链路，无需面包屑
