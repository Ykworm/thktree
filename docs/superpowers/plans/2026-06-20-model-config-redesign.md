# 模型配置页面交互改造实现计划（修订版）

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 重构设置页 LLM 相关区域，新增"大模型"入口；改造 Provider 详情页为可展开式 Context Size 配置（默认 1M）；新建"默认模型配置"页面集中管理三个默认模型选择。

**架构：** 设置页新增"大模型"分组入口，内含"模型提供商"和"默认模型配置"两个子项。Provider 详情页移除勾选框和强制弹窗，改为可展开模型行。默认模型配置页显示三个设置项，点击后弹出模型选择器（按提供商分组，小灰字体分隔）。

**技术栈：** Flutter + Cupertino + Riverpod

---

## 文件清单

| 文件 | 职责 | 操作 |
|------|------|------|
| `lib/data/models/llm_model_config.dart` | 模型配置数据类 | 修改：`fromJson` 默认值从 0 改为 1M |
| `lib/data/services/settings_store.dart` | 设置持久化 | 修改：新增 `chatDefaultProviderId` / `chatDefaultModelId` 字段及读写方法 |
| `lib/ui/features/settings/settings_controller.dart` | 设置状态控制器 | 修改：新增 `saveChatDefaultModel` 方法 |
| `lib/ui/features/settings/settings_screen.dart` | 设置页 UI | 修改：重构 LLM 区域为"大模型"入口 |
| `lib/ui/features/settings/default_model_config_screen.dart` | 默认模型配置页（新建） | 新建：三个默认模型设置项 |
| `lib/ui/features/llm/llm_provider_detail_screen.dart` | Provider 详情页 | 修改：移除勾选框和强制弹窗，改为可展开模型行 |
| `lib/l10n/app_zh.arb` | 中文本地化 | 修改：新增相关文案 |
| `lib/l10n/app_en.arb` | 英文本地化 | 修改：新增相关文案 |

---

## 任务 1：Provider 详情页改造（移除勾选框 + 可展开 Context Size）

**文件：**
- 修改：`lib/ui/features/llm/llm_provider_detail_screen.dart`

**说明：** 移除 `_selectedModelIds` 状态、勾选框 UI、`_promptForContextWindows` 方法及其调用。模型列表改为可展开行，展开后显示 Context Size 选择器（默认 1M）+ 功能说明。获取到的模型默认全部启用。

### 步骤 1：修改 `LlmModelConfig` 默认值（前置依赖）

在 `lib/data/models/llm_model_config.dart` 中：

将 `fromJson` 中 `contextWindow` 的默认值从 `0` 改为 `1000000`：

```dart
contextWindow: json['contextWindow'] as int? ?? 1000000,
```

### 步骤 2：移除 `_selectedModelIds` 状态

1. 删除字段声明：
   ```dart
   Set<String> _selectedModelIds = {};
   ```

2. 删除 `initState` 中的初始化：
   ```dart
   _selectedModelIds = widget.provider!.models.map((m) => m.id).toSet();
   ```

3. 删除模型列表中的勾选逻辑：
   - 删除 `selected` 变量
   - 删除 `CupertinoCheckbox` trailing
   - 删除 `onTap` 中的 `setState` 勾选切换逻辑
   - 将 `CupertinoListTile` 改为仅展示，无交互

### 步骤 3：移除强制弹窗逻辑

1. 删除 `_promptForContextWindows` 方法
2. 删除 `_fetchModels` 中对该方法的调用，改为：
   ```dart
   if (!mounted) return;
   setState(() {
     _fetchedModels = models;
     _isFetchingModels = false;
   });
   ```

### 步骤 4：修改保存逻辑

1. `_saveProvider` 中：
   ```dart
   final selectedModels = _fetchedModels;
   ```

2. `_autoSave` 中：
   ```dart
   final selectedModels = _fetchedModels;
   ```

3. 删除 `_autoSave` 中关于 `_selectedModelIds` 的日志

### 步骤 5：创建可展开模型行组件 `_ExpandableModelTile`

在 `lib/ui/features/llm/llm_provider_detail_screen.dart` 底部新增：

```dart
class _ExpandableModelTile extends StatefulWidget {
  const _ExpandableModelTile({
    required this.model,
    required this.onContextWindowChanged,
  });

  final LlmModelConfig model;
  final ValueChanged<int> onContextWindowChanged;

  @override
  State<_ExpandableModelTile> createState() => _ExpandableModelTileState();
}

class _ExpandableModelTileState extends State<_ExpandableModelTile> {
  bool _isExpanded = false;

  static const _contextWindowOptions = [
    (1000000, '1M'),
    (512000, '512K'),
    (256000, '256K'),
    (128000, '128K'),
    (64000, '64K'),
    (32000, '32K'),
    (16000, '16K'),
    (8000, '8K'),
    (4000, '4K'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentValue = widget.model.contextWindow;
    final hasValue = currentValue > 0;

    return Column(
      children: [
        // 主行：可点击展开
        CupertinoListTile(
          title: Text(widget.model.name),
          subtitle: Text(widget.model.id),
          additionalInfo: Text(
            hasValue ? '${currentValue ~/ 1000}K' : l10n.contextSizeNotSet,
            style: TextStyle(
              color: hasValue ? AppColors.textSecondary : AppColors.accent,
            ),
          ),
          trailing: AnimatedRotation(
            turns: _isExpanded ? 0.25 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(CupertinoIcons.chevron_right, size: 18),
          ),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
        ),
        // 展开区域
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Context Size 选择器
                Row(
                  children: [
                    Text(
                      l10n.contextSize,
                      style: CupertinoTheme.of(context).textTheme.textStyle,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        onPressed: () => _showContextSizePicker(context, l10n),
                        child: Text(
                          hasValue
                              ? _formatContextSize(currentValue)
                              : l10n.contextSizeNotSet,
                          style: TextStyle(
                            color: hasValue ? AppColors.textPrimary : AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 功能说明
                Text(
                  l10n.contextSizeDescription,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        // 分隔线
        Container(
          height: 1,
          color: AppColors.border,
          margin: const EdgeInsets.only(left: 16),
        ),
      ],
    );
  }

  String _formatContextSize(int value) {
    for (final option in _contextWindowOptions) {
      if (option.$1 == value) return option.$2;
    }
    return '${value ~/ 1000}K';
  }

  void _showContextSizePicker(BuildContext context, AppLocalizations l10n) {
    final currentIndex = _contextWindowOptions.indexWhere(
      (o) => o.$1 == widget.model.contextWindow,
    );

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 250,
        color: CupertinoTheme.of(ctx).scaffoldBackgroundColor,
        child: Column(
          children: [
            // 工具栏
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.done),
                  ),
                ],
              ),
            ),
            // Picker
            Expanded(
              child: CupertinoPicker(
                itemExtent: 44,
                scrollController: FixedExtentScrollController(
                  initialItem: currentIndex >= 0 ? currentIndex : 0,
                ),
                onSelectedItemChanged: (index) {
                  widget.onContextWindowChanged(_contextWindowOptions[index].$1);
                },
                children: _contextWindowOptions.map((option) {
                  return Center(
                    child: Text('${option.$2} tokens'),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**注意：** 如果 `AppColors.cardBackground` 不存在，使用 `CupertinoColors.systemGrey6` 或检查现有颜色定义。

### 步骤 6：修改模型列表使用新组件

将模型列表的 `ThkListSection` 中的 `CupertinoListTile` 循环改为使用 `_ExpandableModelTile`：

```dart
if (_fetchedModels.isNotEmpty)
  ThkListSection(
    header: l10n.selectModel,
    children: _fetchedModels.map((model) {
      return _ExpandableModelTile(
        model: model,
        onContextWindowChanged: (newValue) {
          setState(() {
            final index = _fetchedModels.indexWhere((m) => m.id == model.id);
            if (index != -1) {
              _fetchedModels[index] = model.copyWith(contextWindow: newValue);
            }
          });
        },
      );
    }).toList(),
  ),
```

### 步骤 7：新增本地化文案

在 `lib/l10n/app_zh.arb` 中新增：
```json
"contextSize": "上下文大小",
"@contextSize": {
  "description": "模型配置页-上下文大小标签"
},
"contextSizeDescription": "用于计算剩余可用 token，影响长对话的截断策略。如 Claude 等模型无需设置。",
"@contextSizeDescription": {
  "description": "模型配置页-上下文大小功能说明"
},
"contextSizeNotSet": "未设置",
"@contextSizeNotSet": {
  "description": "模型配置页-上下文大小未设置状态"
}
```

在 `lib/l10n/app_en.arb` 中新增：
```json
"contextSize": "Context Size",
"@contextSize": {
  "description": "Model config page - context size label"
},
"contextSizeDescription": "Used to calculate remaining available tokens. Affects truncation strategy for long conversations. Models like Claude do not need this.",
"@contextSizeDescription": {
  "description": "Model config page - context size description"
},
"contextSizeNotSet": "Not set",
"@contextSizeNotSet": {
  "description": "Model config page - context size not set state"
}
```

运行 `flutter gen-l10n` 生成本地化代码。

### 步骤 8：验证编译

运行：`flutter analyze lib/data/models/llm_model_config.dart lib/ui/features/llm/llm_provider_detail_screen.dart`
预期：无错误

### 步骤 9：Commit

```bash
git add lib/data/models/llm_model_config.dart lib/ui/features/llm/llm_provider_detail_screen.dart lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated/
git commit -m "feat: Provider 详情页改为可展开式 Context Size 配置，默认 1M"
```

---

## 任务 2：新增"聊天默认模型"数据层支持

**文件：**
- 修改：`lib/data/services/settings_store.dart`
- 修改：`lib/ui/features/settings/settings_controller.dart`

**说明：** 在 `AppSettings` 和 `SettingsStore` 中新增 `chatDefaultProviderId` 和 `chatDefaultModelId` 字段，支持持久化存储。在 `SettingsController` 中新增保存方法。

### 步骤 1：修改 `AppSettings` 添加字段

在 `lib/data/services/settings_store.dart` 中：
1. 构造函数参数列表新增：
   ```dart
   this.chatDefaultProviderId,
   this.chatDefaultModelId,
   ```
2. 字段声明新增：
   ```dart
   final String? chatDefaultProviderId;
   final String? chatDefaultModelId;
   ```
3. `copyWith` 参数新增：
   ```dart
   String? chatDefaultProviderId,
   String? chatDefaultModelId,
   ```
4. `copyWith` 返回对象新增：
   ```dart
   chatDefaultProviderId: chatDefaultProviderId ?? this.chatDefaultProviderId,
   chatDefaultModelId: chatDefaultModelId ?? this.chatDefaultModelId,
   ```

### 步骤 2：修改 `SettingsStore` 添加持久化

1. 新增常量：
   ```dart
   static const _keyChatDefaultProviderId = 'chat_default_provider_id';
   static const _keyChatDefaultModelId = 'chat_default_model_id';
   ```
2. 在 `load()` 方法中读取：
   ```dart
   final chatDefaultProviderId = await _secureStorage.read(key: _keyChatDefaultProviderId);
   final chatDefaultModelId = await _secureStorage.read(key: _keyChatDefaultModelId);
   ```
3. 在 `load()` 返回的 `AppSettings` 中新增参数：
   ```dart
   chatDefaultProviderId: chatDefaultProviderId,
   chatDefaultModelId: chatDefaultModelId,
   ```
4. 新增保存方法：
   ```dart
   Future<void> saveChatDefaultModel({String? providerId, String? modelId}) async {
     if (providerId == null || modelId == null) {
       await _secureStorage.delete(key: _keyChatDefaultProviderId);
       await _secureStorage.delete(key: _keyChatDefaultModelId);
     } else {
       await _secureStorage.write(key: _keyChatDefaultProviderId, value: providerId);
       await _secureStorage.write(key: _keyChatDefaultModelId, value: modelId);
     }
   }
   ```

### 步骤 3：修改 `SettingsController` 添加保存方法

在 `lib/ui/features/settings/settings_controller.dart` 中新增：
```dart
Future<void> saveChatDefaultModel({String? providerId, String? modelId}) async {
  final store = ref.read(settingsStoreProvider);
  await store.saveChatDefaultModel(providerId: providerId, modelId: modelId);
  state = AsyncData(await store.load());
}
```

### 步骤 4：验证编译

运行：`flutter analyze lib/data/services/settings_store.dart lib/ui/features/settings/settings_controller.dart`
预期：无错误

### 步骤 5：Commit

```bash
git add lib/data/services/settings_store.dart lib/ui/features/settings/settings_controller.dart
git commit -m "feat: 新增聊天默认模型数据层支持"
```

---

## 任务 3：设置页重构为"大模型"入口 + 新建默认模型配置页

**文件：**
- 修改：`lib/ui/features/settings/settings_screen.dart`
- 新建：`lib/ui/features/settings/default_model_config_screen.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_en.arb`

**说明：** 设置页 LLM 相关区域重构为"大模型"入口，点击后进入新页面显示"模型提供商"和"默认模型配置"两个选项。"默认模型配置"点击进入新页面，显示三个默认模型设置项（聊天 / Title 生成 / 对话总结）。每个设置项点击后弹出模型选择器，按提供商分组显示（小灰字体分隔）。

### 步骤 1：新增本地化文案

在 `lib/l10n/app_zh.arb` 中新增：
```json
"llmSettings": "大模型",
"@llmSettings": {
  "description": "设置页-大模型入口标题"
},
"modelProviders": "模型提供商",
"@modelProviders": {
  "description": "大模型页面-模型提供商选项"
},
"defaultModelConfig": "默认模型配置",
"@defaultModelConfig": {
  "description": "大模型页面-默认模型配置选项"
},
"chatDefaultModel": "聊天默认模型",
"@chatDefaultModel": {
  "description": "默认模型配置页-聊天默认模型标题"
},
"titleModel": "标题生成模型",
"@titleModel": {
  "description": "默认模型配置页-标题生成模型标题"
},
"summaryModel": "对话总结模型",
"@summaryModel": {
  "description": "默认模型配置页-对话总结模型标题"
},
"notSet": "未设置",
"@notSet": {
  "description": "通用-未设置状态"
}
```

在 `lib/l10n/app_en.arb` 中新增：
```json
"llmSettings": "LLM",
"@llmSettings": {
  "description": "Settings - LLM entry title"
},
"modelProviders": "Model Providers",
"@modelProviders": {
  "description": "LLM page - model providers option"
},
"defaultModelConfig": "Default Model Config",
"@defaultModelConfig": {
  "description": "LLM page - default model config option"
},
"chatDefaultModel": "Chat Default Model",
"@chatDefaultModel": {
  "description": "Default model config page - chat default model title"
},
"titleModel": "Title Model",
"@titleModel": {
  "description": "Default model config page - title model title"
},
"summaryModel": "Summary Model",
"@summaryModel": {
  "description": "Default model config page - summary model title"
},
"notSet": "Not set",
"@notSet": {
  "description": "Generic - not set state"
}
```

运行 `flutter gen-l10n` 生成本地化代码。

### 步骤 2：新建 `DefaultModelConfigScreen`

创建 `lib/ui/features/settings/default_model_config_screen.dart`：

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/ui/features/llm/llm_providers_controller.dart';
import 'package:thk_tree/l10n/app_localizations.dart';
import 'package:thk_tree/ui/theme/app_colors.dart';

class DefaultModelConfigScreen extends ConsumerWidget {
  const DefaultModelConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsControllerProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.defaultModelConfig),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: Text(l10n.defaultModelConfig.toUpperCase()),
              children: [
                // 聊天默认模型
                _buildModelTile(
                  context: context,
                  ref: ref,
                  title: l10n.chatDefaultModel,
                  settingsAsync: settingsAsync,
                  getProviderId: (s) => s.chatDefaultProviderId,
                  getModelId: (s) => s.chatDefaultModelId,
                  onSave: (providerId, modelId) => ref
                      .read(settingsControllerProvider.notifier)
                      .saveChatDefaultModel(providerId: providerId, modelId: modelId),
                ),
                // 标题生成模型
                _buildModelTile(
                  context: context,
                  ref: ref,
                  title: l10n.titleModel,
                  settingsAsync: settingsAsync,
                  getProviderId: (s) => s.titleModelProviderId,
                  getModelId: (s) => s.titleModelModelId,
                  onSave: (providerId, modelId) => ref
                      .read(settingsControllerProvider.notifier)
                      .saveTitleModel(providerId: providerId, modelId: modelId),
                ),
                // 对话总结模型
                _buildModelTile(
                  context: context,
                  ref: ref,
                  title: l10n.summaryModel,
                  settingsAsync: settingsAsync,
                  getProviderId: (s) => s.summaryModelProviderId,
                  getModelId: (s) => s.summaryModelModelId,
                  onSave: (providerId, modelId) => ref
                      .read(settingsControllerProvider.notifier)
                      .saveSummaryModel(providerId: providerId, modelId: modelId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelTile({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required AsyncValue<AppSettings> settingsAsync,
    required String? Function(AppSettings) getProviderId,
    required String? Function(AppSettings) getModelId,
    required void Function(String? providerId, String? modelId) onSave,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return settingsAsync.when(
      data: (settings) {
        final providerId = getProviderId(settings);
        final modelId = getModelId(settings);
        final hasValue = providerId != null && modelId != null;

        return CupertinoListTile(
          title: Text(title),
          subtitle: hasValue ? Text(modelId) : Text(l10n.notSet),
          trailing: const Icon(CupertinoIcons.chevron_right),
          onTap: () => _showModelPicker(context, ref, onSave),
        );
      },
      loading: () => CupertinoListTile(
        title: Text(title),
        trailing: const CupertinoActivityIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showModelPicker(
    BuildContext context,
    WidgetRef ref,
    void Function(String? providerId, String? modelId) onSave,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final providersAsync = ref.read(llmProvidersProvider);

    providersAsync.whenData((providers) {
      final configuredProviders = providers
          .where((p) => p.models.isNotEmpty)
          .toList();

      if (configuredProviders.isEmpty) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            content: Text(l10n.pleaseFetchModels),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.close),
              ),
            ],
          ),
        );
        return;
      }

      showCupertinoModalPopup(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(l10n.selectModel),
          actions: [
            for (final provider in configuredProviders)
              ..._buildProviderActions(provider, onSave, context),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
        ),
      );
    });
  }

  List<Widget> _buildProviderActions(
    LlmProviderConfig provider,
    void Function(String? providerId, String? modelId) onSave,
    BuildContext context,
  ) {
    final actions = <Widget>[];

    // 提供商名称作为小标题（灰色小字）
    actions.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          provider.name,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    for (final model in provider.models) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () {
            onSave(provider.id, model.id);
            Navigator.of(context).pop();
          },
          child: Text(model.name),
        ),
      );
    }

    return actions;
  }
}
```

### 步骤 3：修改设置页，重构为"大模型"入口

在 `lib/ui/features/settings/settings_screen.dart` 中：

1. 找到现有的 LLM 相关设置项（Title 生成模型、对话总结模型等）
2. 移除这些独立的设置项
3. 新增"大模型"入口：

```dart
// 大模型入口
CupertinoListTile(
  title: Text(l10n.llmSettings),
  trailing: const Icon(CupertinoIcons.chevron_right),
  onTap: () {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const LlmSettingsScreen(),
      ),
    );
  },
),
```

### 步骤 4：新建 `LlmSettingsScreen`

创建 `lib/ui/features/settings/llm_settings_screen.dart`：

```dart
import 'package:flutter/cupertino.dart';
import 'package:thk_tree/l10n/app_localizations.dart';
import 'package:thk_tree/ui/features/llm/llm_providers_screen.dart';
import 'package:thk_tree/ui/features/settings/default_model_config_screen.dart';

class LlmSettingsScreen extends StatelessWidget {
  const LlmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.llmSettings),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              children: [
                // 模型提供商
                CupertinoListTile(
                  title: Text(l10n.modelProviders),
                  trailing: const Icon(CupertinoIcons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => const LlmProvidersScreen(),
                      ),
                    );
                  },
                ),
                // 默认模型配置
                CupertinoListTile(
                  title: Text(l10n.defaultModelConfig),
                  trailing: const Icon(CupertinoIcons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => const DefaultModelConfigScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### 步骤 5：验证编译

运行：`flutter analyze lib/ui/features/settings/settings_screen.dart lib/ui/features/settings/llm_settings_screen.dart lib/ui/features/settings/default_model_config_screen.dart`
预期：无错误

### 步骤 6：Commit

```bash
git add lib/ui/features/settings/settings_screen.dart lib/ui/features/settings/llm_settings_screen.dart lib/ui/features/settings/default_model_config_screen.dart lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated/
git commit -m "feat: 设置页重构为大模型入口，新增默认模型配置页"
```

---

## 任务 4：聊天页 fallback 到默认模型

**文件：**
- 修改：`lib/ui/features/chat/chat_screen.dart`

**说明：** 在聊天页中，当用户未选择模型时，fallback 到设置中的"聊天默认模型"。

### 步骤 1：修改模型选择逻辑

找到聊天页中确定当前使用模型的逻辑，在 fallback 链中增加"聊天默认模型"：
1. 用户显式选择的模型（最高优先级）
2. 设置中的 `chatDefaultProviderId` + `chatDefaultModelId`
3. 第一个有 key 的 provider 的第一个模型（现有 fallback）

需要读取 `settingsControllerProvider` 获取 `chatDefaultProviderId` 和 `chatDefaultModelId`。

### 步骤 2：验证编译

运行：`flutter analyze lib/ui/features/chat/chat_screen.dart`
预期：无错误

### 步骤 3：Commit

```bash
git add lib/ui/features/chat/chat_screen.dart
git commit -m "feat: 聊天页未选择模型时 fallback 到默认模型"
```

---

## 自检

### 规格覆盖度检查

| 规格需求 | 对应任务 | 状态 |
|---------|---------|------|
| 获取模型后不再弹出 Context Size 选择弹窗 | 任务 1 | 已覆盖 |
| 模型列表不显示勾选框，仅展示 | 任务 1 | 已覆盖 |
| 每个模型行可展开，显示 Context Size 选择器 + 说明 | 任务 1 | 已覆盖 |
| Context Size 默认值为 1M | 任务 1 | 已覆盖 |
| 保存提供商时所有模型正确保存 | 任务 1 | 已覆盖 |
| 设置页出现"大模型"入口 | 任务 3 | 已覆盖 |
| 大模型页面包含"模型提供商"和"默认模型配置" | 任务 3 | 已覆盖 |
| 默认模型配置页包含三个设置项 | 任务 3 | 已覆盖 |
| 模型选择器按提供商分组（小灰字体） | 任务 3 | 已覆盖 |
| 聊天页 fallback 到默认模型 | 任务 4 | 已覆盖 |

### 占位符扫描

- 无 "待定"、"TODO"、"后续实现" 等占位符
- 所有步骤包含具体代码或命令
- 无 "类似任务 N" 的重复引用

### 类型一致性检查

- `LlmModelConfig.copyWith(contextWindow:)` — 任务 1 内部一致
- `SettingsStore.saveChatDefaultModel` — 任务 2 和任务 3 一致
- `AppSettings.chatDefaultProviderId` / `chatDefaultModelId` — 任务 2、3、4 一致

---

## 执行交接

计划已完成并保存到 `docs/superpowers/plans/2026-06-20-model-config-redesign.md`。

**两种执行方式：**

**1. 子代理驱动（推荐）** - 每个任务调度一个新的子代理，任务间进行审查，快速迭代

**2. 内联执行** - 在当前会话中使用 executing-plans 执行任务，批量执行并设有检查点

**选哪种方式？**
