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
- go_router 路由（`/settings`）的跳转：因 `context.go` 在混合栈（go_router + Navigator.push）中行为不可控，改用 `Navigator.popUntil(route.isFirst)` 保守 pop 到栈底
