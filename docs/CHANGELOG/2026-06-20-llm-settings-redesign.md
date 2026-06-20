# LLM 设置链路 UI 收敛:大模型入口 + 子页视觉回收 + 默认模型选择页

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-20 |
| 范围 | settings 模块 + llm 模块(LLM 设置链路 UI 重组) |
| 设计文档 | [`docs/_tmp/2026-06-20-llm-subpages-selection-page.md`](../_tmp/2026-06-20-llm-subpages-selection-page.md) |
| 状态 | ✅ 完成 |

## 背景

设置页里 LLM 相关的入口散布在多个 Tab(LLM Provider、Default Model、Backup、Restore、Language),用户找不到一个统一的"大模型"设置入口。同时:

- `LlmProvidersScreen` 和 `DefaultModelConfigScreen` 原本更接近"卡片式设置页"视觉;
- 后来被改成"普通整页列表"后,虽然削弱了顶部留白感,但**视觉语言被改坏**,页面显得不够大方;
- `DefaultModelConfigScreen` 内部用 `CupertinoActionSheet` 选模型,但模型选择有 6 个 Provider × N 个 Model,层级和信息量都**更适合独立页面**,而不是 sheet。

## 根因

旧版 UI 三处独立设计,没有共享同一套"子页"视觉语言:

1. **入口缺失** — 设置页没有"大模型"聚合入口,LLM Provider 和 Default Model 散落在不同 section,用户需要分别找;
2. **视觉碎片化** — 多个子页各自决定自己的"页面填满方式"(有的 fill card,有的 list,有的 sheet),没有统一收敛;
3. **承载工具不当** — `CupertinoActionSheet` 是为"少量 option 的快速选择"设计的,把它套在"6 个 Provider × N 个 Model"上,信息密度和交互都不合适。

## 方案

走 **方案 1:统一子页视觉 + 独立单选页**。三步走:

### 第 1 步:新增"大模型"聚合入口页

设置页加 `_LlmSettingsEntry` 入口项(icon: `cloud`,subtitle: "N 个模型"),点击后 push 到 `LlmSettingsScreen`。

`LlmSettingsScreen`(新文件,71 行)用 `CupertinoNavigationBar` + `ThkFillCardPageBody` 布局,内部两个连续列表项:
- `模型提供商` → 跳 `LlmProvidersScreen`
- `默认模型配置` → 跳 `DefaultModelConfigScreen`

### 第 2 步:子页视觉统一

`LlmProvidersScreen` 和 `DefaultModelConfigScreen` 统一用 `ThkFillCardPageBody` 模式:
- NavBar 下方保留顶部留白(`ThkFillCardPageBody.topSpacing = 12`)
- 白色 pane 填满剩余 body
- pane 内部用连续列表项 + `0.5px` 分隔线,避免"上方一小块白卡 + 下方大片留白"
- `LlmProvidersScreen` 列表项若没有可信品牌资产,**不展示占位 icon**(`leading: null`)
- 保持 `inline title`,不用 `large title`

### 第 3 步:默认模型选择改独立单选页

新增 `DefaultModelPickerScreen`(131 行),替代原来的 `CupertinoActionSheet`:

- 点击 `聊天默认模型` / `标题生成模型` / `对话总结模型` → push 到 `DefaultModelPickerScreen`
- 新页面按 provider 分组展示模型(`provider name` 作为 group header,`LlmModelConfig` 作为 tile)
- 当前选中的模型项显示 `check` icon + accent 颜色,未选中项**不显示 chevron**(语义:单选 `option list`,不是导航)
- 用户点选模型后 `await onSelected(...)` 立即保存,然后 `Navigator.pop(true)` 返回上一页
- 提供商还没拉取模型列表时(`configuredProviders.isEmpty`),显示"请先获取模型"提示

## 实施内容

### 新增文件(2 个)

```
lib/ui/features/settings/llm_settings_screen.dart               # 71 行 · 大模型聚合入口页
lib/ui/features/settings/default_model_picker_screen.dart       # 131 行 · 单选 option list 模型选择页
```

### 修改文件(4 个)

```
lib/ui/features/settings/settings_screen.dart                   # 新增 _LlmSettingsEntry · LLM 入口项(从原 LLM 散落 section 抽出)
lib/ui/features/llm/llm_providers_screen.dart                   # 改用 ThkFillCardPageBody + inline title · 列表项 leading=null
lib/ui/features/settings/default_model_config_screen.dart       # 改用 ThkFillCardPageBody + inline title · _openModelPicker 改 push 到 DefaultModelPickerScreen
lib/l10n/generated/app_localizations_*.dart                      # 新增 llmSettings key(zh: 大模型 / en: LLM)
```

### 关键改动

**`lib/ui/features/settings/llm_settings_screen.dart` — 新增聚合入口页:**

```dart
class LlmSettingsScreen extends StatelessWidget {
  const LlmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.llmSettings),  // zh: 大模型 / en: LLM
      ),
      child: SafeArea(
        child: ThkFillCardPageBody(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: 2,
            separatorBuilder: (context, index) => Container(
              height: 0.5,
              margin: const EdgeInsetsDirectional.only(start: 16),
              color: CupertinoColors.separator.resolveFrom(context),
            ),
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return ThkListTile(
                    title: l10n.llmProvidersTitle,
                    backgroundColor: AppColors.surface,
                    onTap: () => Navigator.push(... LlmProvidersScreen ...),
                  );
                case 1:
                  return ThkListTile(
                    title: l10n.defaultModelConfig,
                    backgroundColor: AppColors.surface,
                    onTap: () => Navigator.push(... DefaultModelConfigScreen ...),
                  );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
```

**`lib/ui/features/settings/default_model_picker_screen.dart` — 核心选中态(关键 diff):**

```dart
class _SelectableModelTile extends StatelessWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return ThkListTile(
      title: model.name,
      subtitle: model.id == model.name ? null : model.id,
      // 单选语义:仅当前选中项显示 check icon,未选中项不显示 chevron
      trailing: isSelected
          ? Icon(AppIcons.check, color: AppColors.accent, size: 18)
          : null,
      onTap: onTap,
    );
  }
}
```

```dart
// onTap 逻辑:点选 → 保存 → 立即 pop 返回
onTap: () async {
  await onSelected(
    provider.id,
    provider.models[index].id,
  );
  if (!context.mounted) return;
  Navigator.of(context).pop(true);
},
```

**`lib/ui/features/llm/llm_providers_screen.dart` — 列表项丢占位 icon:**

```dart
class _ProviderTile extends StatelessWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    // ...
    return ThkListTile(
      title: provider.name,
      subtitle: modelText,
      leading: null,  // 没有可信品牌资产,不展示占位 icon
      onTap: onTap,
    );
  }
}
```

**`lib/ui/features/settings/settings_screen.dart` — 新增 LLM 入口项:**

```dart
class _LlmSettingsEntry extends ConsumerWidget {
  const _LlmSettingsEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final providersAsync = ref.watch(llmProvidersProvider);

    final subtitle = providersAsync.when(
      data: (providers) => l10n.modelCount(providers.length),
      loading: () => l10n.loadingSettings,
      error: (_, _) => l10n.noModels,
    );

    return ThkListTile(
      leading: const Padding(
        padding: EdgeInsets.only(bottom: 1.5),
        child: Icon(AppIcons.cloud),
      ),
      title: l10n.llmSettings,
      subtitle: subtitle,
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => const LlmSettingsScreen(),
          ),
        );
      },
    );
  }
}
```

## 验证

| 类别 | 状态 |
|---|---|
| 视觉回收(子页填满 body) | ✅ 三个子页(LLM 设置 / 模型提供商 / 默认模型配置)视觉一致,白色 pane 填满 body,无"上方小块 + 下方大片留白" |
| 入口聚合 | ✅ 设置页 → "大模型" 入口项 → push 到 LlmSettingsScreen,显示当前 provider 数量 |
| 默认模型选择交互 | ✅ 点选 → 立即保存 + pop,选中项显示 check icon,未选中项无 chevron |
| Provider 未拉取模型时降级 | ✅ DefaultModelPickerScreen 显示"请先获取模型"提示,不崩溃 |
| `flutter analyze` | ✅ 无新增 error |
| 回归(旧 CupertinoActionSheet 路径) | ✅ 旧 LLM 入口路径已替换,无残留 |

## 已知风险(留给后续决定)

- `LlmSettingsScreen` 仍有两层 push(设置页 → LLM 设置 → 子页),若未来 LLM 相关设置项增加到 5+,可考虑改成"tab 切换"或"单页可滚动"。当前 2 项,导航深度合理。
- `DefaultModelPickerScreen` 不带搜索栏;若 provider × model 数量爆发(>50),需补搜索。当前 6 provider × ~10 model 量级,不需要。

## 关联

- [docs/_tmp/2026-06-20-llm-subpages-selection-page.md](../_tmp/2026-06-20-llm-subpages-selection-page.md) — 原始设计意图(39 行)
- [docs/_tmp/2026-06-20-model-config-redesign.md](../_tmp/2026-06-20-model-config-redesign.md) — 同日 chat 模块的模型配置 redesign 草稿
- [docs/FEATURES.md § 5 LLM 模块](../FEATURES.md#5-llm-模块llm) — 功能行"LLM Provider 管理"已更新为 2026-06-20
- [docs/FEATURES.md § 6 设置模块](../FEATURES.md#6-设置模块settings) — 功能行"设置页"已更新为 2026-06-20
