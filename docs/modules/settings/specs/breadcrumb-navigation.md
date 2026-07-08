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

每个页面 push 时设 `RouteSettings(name:)` 用于面包屑跳转定位。

| 页面 | routeName | 路由类型 |
|------|-----------|----------|
| SettingsScreen (go_router) | `/settings` | go_router 管理，面包屑跳转用 `popUntil(route.isFirst)` |
| LlmSettingsScreen | `llm-settings` | Navigator.push |
| LlmProvidersScreen | `providers-list` | Navigator.push |
| LlmProviderDetailScreen | `provider-detail` | Navigator.push |
| DefaultModelConfigScreen | `default-model-config` | Navigator.push |
| DefaultModelPickerScreen | `model-picker` | Navigator.push |

## 跳转实现

`ThkBreadcrumbRow._popToRoute` 按 routeName 分流：

- **以 `/` 开头（go_router 路由）**：`Navigator.popUntil((route) => route.isFirst)` — 保守处理，pop 到栈底保留 go_router 的根页面
- **其他（Navigator.push 路由）**：`Navigator.popUntil((route) => route.settings.name == routeName)` — 精确匹配 RouteSettings.name

## 改动文件

1. **新建** `lib/ui/core/widgets/thk_breadcrumb_nav.dart` — BreadcrumbSegment + ThkBreadcrumbRow
2. **修改** `lib/ui/features/settings/settings_screen.dart` — _LlmSettingsEntry push 加 RouteSettings + parentCrumbs
3. **修改** `lib/ui/features/settings/llm_settings_screen.dart` — 面包屑 + push 加 RouteSettings + parentCrumbs（两条链路）
4. **修改** `lib/ui/features/settings/default_model_config_screen.dart` — 面包屑 + push 加 RouteSettings + parentCrumbs
5. **修改** `lib/ui/features/settings/default_model_picker_screen.dart` — 面包屑（接收 parentCrumbs）
6. **修改** `lib/ui/features/llm/llm_providers_screen.dart` — 面包屑 + push 加 RouteSettings + parentCrumbs（两处入口）
7. **修改** `lib/ui/features/llm/llm_provider_detail_screen.dart` — 面包屑（接收 parentCrumbs）

## 不在此次范围

- go_router 路由层级改动
- 级联自动 pop（用户明确不要）
- `llm_setup_check.dart` / `router.dart` / `generate_title_screen.dart` 中的非 Settings 入口 — 这些入口无 Settings 祖先链路，无需面包屑
