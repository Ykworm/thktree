// LLM 配置状态检查 + 跳转引导 helper。
//
// 集中处理三类"死路防护"：
//   - L1-A（showBranchFlow 开头）：summarize 模式解析失败 → 弹 alert 引导设置
//   - L1-B（TitleSuggestionScreen.initState）：title 生成解析失败 → 弹 alert 引导设置
//   - L2（_showModelSelectorAndGenerate 入口）：filter 后空 → 弹 alert 引导设置
//
// 同时把 `_resolveModel` 实例方法 + `_resolveModelForSummary` 顶层函数抽成
// 顶层函数 resolveModelForTitle / resolveModelForSummary，让 helper 之间可互调
// （避免循环引用 + 让 showBranchFlow / TitleSuggestionScreen 都能复用）。
//
// 抽离原则：行为与原实例方法 / 顶层函数保持一致（line 233-285 / 1207-1269），
// 只把 `ref` 替换为 `container`，不修改解析优先级和兜底逻辑。

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thk_tree/data/models/llm_provider_config.dart';

import 'package:thk_tree/data/services/settings_store.dart' show AppSettings;
import 'package:thk_tree/data/stores/llm_config_store.dart' show LlmConfigStore;
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/widgets/thk_alert.dart';
import 'package:thk_tree/ui/features/llm/llm_providers_screen.dart';
import 'package:thk_tree/ui/features/settings/default_model_picker_screen.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// LLM 配置状态分类（用于 [showLlmSetupAlert] 决定跳转目标 + 文案）。
enum LlmSetupStatus {
  /// LLM 已配置齐全，可正常调 LLM。
  ok,

  /// 没有 provider 同时满足「有 apiKey + 有 model」——跳 [LlmProvidersScreen]。
  noProviderConfigured,

  /// 有 provider 配置好但没设置默认标题生成模型——跳 [DefaultModelPickerScreen] (title)。
  noTitleModelConfigured,

  /// 有 provider 配置好但没设置默认对话总结模型——跳 [DefaultModelPickerScreen] (summary)。
  noSummaryModelConfigured,
}

/// 返回所有「apiKey 非空 + 至少有 model 或 selectedModelId」的 provider。
///
/// 这是 L1 拦截 / sheet filter 的唯一可信源。
Future<List<LlmProviderConfig>> configuredProviders(
  ProviderContainer container,
) async {
  final providers = await container.read(llmProvidersProvider.future);
  final configStore = container.read(llmConfigStoreProvider);
  final out = <LlmProviderConfig>[];
  for (final p in providers) {
    final apiKey = await configStore.readApiKey(p.id);
    final hasModels =
        p.models.isNotEmpty || (p.selectedModelId?.isNotEmpty ?? false);
    if (apiKey.isNotEmpty && hasModels) {
      out.add(p);
    }
  }
  return out;
}

/// 解析 (provider, modelId, apiKey) 用于生成标题（widget 端 wrapper，从 container 读 settings / configStore 后调核心函数）。
///
/// 核心实现见 [resolveModelForTitleCore]，可在没有 ProviderContainer 的上下文（如 Riverpod Notifier）使用。
///
/// 优先级（与原 `_resolveModel` 实例方法一致，line 233-285）：
///   1. settings.titleModelProviderId + settings.titleModelModelId
///   2. currentProviderId + currentModelId（来自 chat screen / request）
///   3. settings.llmProvider（legacy enum）+ settings.model
///   4. 遍历 providers 找第一个有 apiKey 的
///
/// modelId 兜底：provider.selectedModelId → provider.models.first
Future<(LlmProviderConfig, String, String)?> resolveModelForTitle(
  ProviderContainer container,
  List<LlmProviderConfig> providers, {
  String? currentProviderId,
  String? currentModelId,
}) {
  return resolveModelForTitleCore(
    settings: container.read(settingsControllerProvider).value,
    providers: providers,
    configStore: container.read(llmConfigStoreProvider),
    currentProviderId: currentProviderId,
    currentModelId: currentModelId,
  );
}

/// 解析 (provider, modelId, apiKey) 用于生成标题（核心纯函数，接受裸数据）。
///
/// 设计点：这个函数不接 container / ref / widgetRef，让 Riverpod Notifier 内可以调用
/// （Notifier 自己的 ref 调 `ref.read(settingsControllerProvider).value` / `ref.read(llmConfigStoreProvider)`
/// 后传入），同时 widget 端有 [resolveModelForTitle] 作为便捷 wrapper。
///
/// 优先级（与原 `_resolveModel` 实例方法一致，line 233-285）：
///   1. settings.titleModelProviderId + settings.titleModelModelId
///   2. currentProviderId + currentModelId（来自 chat screen / request）
///   3. settings.llmProvider（legacy enum）+ settings.model
///   4. 遍历 providers 找第一个有 apiKey 的
///
/// modelId 兜底：provider.selectedModelId → provider.models.first
Future<(LlmProviderConfig, String, String)?> resolveModelForTitleCore({
  required AppSettings? settings,
  required List<LlmProviderConfig> providers,
  required LlmConfigStore configStore,
  String? currentProviderId,
  String? currentModelId,
}) async {
  // 1. titleModelProviderId + titleModelModelId
  String? providerId = settings?.titleModelProviderId;
  String? modelId = settings?.titleModelModelId;

  // 2. currentProviderId + currentModelId 兜底
  if (providerId == null || modelId == null) {
    providerId = currentProviderId;
    modelId = currentModelId;
  }

  LlmProviderConfig? provider;
  if (providerId != null) {
    for (final p in providers) {
      if (p.id == providerId) {
        provider = p;
        break;
      }
    }
  }

  // 4. 兜底：遍历 providers 找第一个有 apiKey 的
  if (provider == null) {
    for (final p in providers) {
      final apiKey = await configStore.readApiKey(p.id);
      if (apiKey.isNotEmpty) {
        provider = p;
        providerId = p.id;
        break;
      }
    }
  }

  if (provider == null) return null;

  // modelId 兜底：selectedModelId → models.first
  String? effectiveModelId = modelId;
  if (effectiveModelId == null ||
      !provider.models.any((m) => m.id == effectiveModelId)) {
    effectiveModelId = provider.selectedModelId;
    if (effectiveModelId == null && provider.models.isNotEmpty) {
      effectiveModelId = provider.models.first.id;
    }
  }
  if (effectiveModelId == null) return null;

  // 最后再查一次 apiKey（确保最终选中的 provider 有 key）
  final apiKey = await configStore.readApiKey(provider.id);
  if (apiKey.isEmpty) return null;

  return (provider, effectiveModelId, apiKey);
}

/// 解析 (provider, modelId, apiKey) 用于 LLM 总结。
///
/// 优先级（与原 `_resolveModelForSummary` 顶层函数一致，line 1207-1269）：
///   1. settings.summaryModelProviderId + settings.summaryModelModelId
///   2. currentProviderId + currentModelId
///   3. settings.llmProvider（legacy enum）+ settings.model
///   4. 遍历 providers 找第一个有 apiKey 的
Future<(LlmProviderConfig, String, String)?> resolveModelForSummary(
  ProviderContainer container,
  List<LlmProviderConfig> providers, {
  String? currentProviderId,
  String? currentModelId,
}) async {
  // 1. summaryModelProviderId + summaryModelModelId
  final settings = container.read(settingsControllerProvider).value;
  String? providerId = settings?.summaryModelProviderId;
  String? modelId = settings?.summaryModelModelId;

  // 2. currentProviderId + currentModelId 兜底
  if (providerId == null || modelId == null) {
    providerId = currentProviderId;
    modelId = currentModelId;
  }

  // 3. 归一化：保证 providerId + modelId 在 providers 列表中有效
  LlmProviderConfig? provider;
  if (providerId != null) {
    for (final p in providers) {
      if (p.id == providerId) {
        provider = p;
        break;
      }
    }
  }

  final configStore = container.read(llmConfigStoreProvider);
  if (provider == null) {
    for (final p in providers) {
      final apiKey = await configStore.readApiKey(p.id);
      if (apiKey.isNotEmpty) {
        provider = p;
        providerId = p.id;
        break;
      }
    }
  }

  if (provider == null) return null;

  String? effectiveModelId = modelId;
  if (effectiveModelId == null ||
      !provider.models.any((m) => m.id == effectiveModelId)) {
    effectiveModelId = provider.selectedModelId;
    if (effectiveModelId == null && provider.models.isNotEmpty) {
      effectiveModelId = provider.models.first.id;
    }
  }
  if (effectiveModelId == null) return null;

  final apiKey = await configStore.readApiKey(provider.id);
  if (apiKey.isEmpty) return null;

  return (provider, effectiveModelId, apiKey);
}

/// 解析对话用的 (providerId, modelId)。
///
/// 用于分支创建、笔记转对话等需要"聊天模型"的场景。
///
/// 优先级：
///   1. 会话自带的 [sessionProviderId] / [sessionModelId]
///   2. [lastUsedChatProviderId] / [lastUsedChatModelId]（最后使用的模型）
///   3. [chatDefaultProviderId] / [chatDefaultModelId]（全局默认）
///   4. 遍历 providers 找第一个有 model 的
(String providerId, String modelId) resolveChatModel({
  String? sessionProviderId,
  String? sessionModelId,
  String? lastUsedChatProviderId,
  String? lastUsedChatModelId,
  String? chatDefaultProviderId,
  String? chatDefaultModelId,
  List<LlmProviderConfig>? providers,
}) {
  String? providerId = sessionProviderId;
  String? modelId = sessionModelId;

  // 2. lastUsed（最后使用的模型）
  if (providerId == null || modelId == null) {
    providerId ??= lastUsedChatProviderId;
    modelId ??= lastUsedChatModelId;
  }

  // 3. chatDefault（全局默认）
  if (providerId == null || modelId == null) {
    providerId ??= chatDefaultProviderId;
    modelId ??= chatDefaultModelId;
  }

  // 4. 兜底：第一个有 model 的 provider
  if (providerId == null || modelId == null) {
    if (providers != null) {
      for (final p in providers) {
        if (p.models.isNotEmpty) {
          providerId ??= p.id;
          modelId ??= p.models.first.id;
          break;
        }
      }
    }
  }

  return (providerId ?? '', modelId ?? '');
}

/// 检查「用于对话总结」的 LLM 配置状态。
///
/// - [LlmSetupStatus.noProviderConfigured]：没有任何 provider 满足「有 apiKey + 有 model」
/// - [LlmSetupStatus.noSummaryModelConfigured]：有 provider 配置好但解析不出 summary 模型
/// - [LlmSetupStatus.ok]：解析成功
Future<LlmSetupStatus> checkLlmSetupForSummarize({
  required ProviderContainer container,
  String? currentProviderId,
  String? currentModelId,
}) async {
  final providers = await container.read(llmProvidersProvider.future);
  if ((await configuredProviders(container)).isEmpty) {
    return LlmSetupStatus.noProviderConfigured;
  }
  // 只检查显式配置的 summary model，不回退到 currentProviderId/modelId 或 legacy
  final settings = container.read(settingsControllerProvider).value;
  if (settings?.summaryModelProviderId == null || settings?.summaryModelModelId == null) {
    return LlmSetupStatus.noSummaryModelConfigured;
  }
  // 验证配置的 provider/model 仍然存在且有 apiKey
  final configStore = container.read(llmConfigStoreProvider);
  LlmProviderConfig? provider;
  for (final p in providers) {
    if (p.id == settings!.summaryModelProviderId) {
      provider = p;
      break;
    }
  }
  if (provider == null) return LlmSetupStatus.noSummaryModelConfigured;
  final apiKey = await configStore.readApiKey(provider.id);
  if (apiKey.isEmpty) return LlmSetupStatus.noSummaryModelConfigured;
  return LlmSetupStatus.ok;
}

/// 检查「用于生成标题」的 LLM 配置状态。
///
/// - [LlmSetupStatus.noProviderConfigured]：没有任何 provider 满足「有 apiKey + 有 model」
/// - [LlmSetupStatus.noTitleModelConfigured]：有 provider 配置好但解析不出 title 模型
/// - [LlmSetupStatus.ok]：解析成功
Future<LlmSetupStatus> checkLlmSetupForTitle({
  required ProviderContainer container,
  String? currentProviderId,
  String? currentModelId,
}) async {
  final providers = await container.read(llmProvidersProvider.future);
  if ((await configuredProviders(container)).isEmpty) {
    return LlmSetupStatus.noProviderConfigured;
  }
  // 只检查显式配置的 title model，不回退到 currentProviderId/modelId 或 legacy
  final settings = container.read(settingsControllerProvider).value;
  if (settings?.titleModelProviderId == null || settings?.titleModelModelId == null) {
    return LlmSetupStatus.noTitleModelConfigured;
  }
  // 验证配置的 provider/model 仍然存在且有 apiKey
  final configStore = container.read(llmConfigStoreProvider);
  LlmProviderConfig? provider;
  for (final p in providers) {
    if (p.id == settings!.titleModelProviderId) {
      provider = p;
      break;
    }
  }
  if (provider == null) return LlmSetupStatus.noTitleModelConfigured;
  final apiKey = await configStore.readApiKey(provider.id);
  if (apiKey.isEmpty) return LlmSetupStatus.noTitleModelConfigured;
  return LlmSetupStatus.ok;
}

/// 弹出 LLM 未配置 alert，根据 [status] 跳不同设置页。
///
/// status == ok 时不弹（无副作用）。
///
/// defaultAction 按钮文案即跳转目标 picker / 列表页的标题（用户决策：
/// 复用 `llmProvidersTitle` / `titleModelTitle` / `summaryModelTitle`，
/// alert 文案直接告诉用户要去哪个页面）。
Future<void> showLlmSetupAlert({
  required BuildContext context,
  required LlmSetupStatus status,
  required ProviderContainer container,
}) async {
  if (status == LlmSetupStatus.ok) return;
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;

  String message;
  String defaultLabel;
  VoidCallback onDefault;

  switch (status) {
    case LlmSetupStatus.noProviderConfigured:
      message = l10n.pleaseFetchModels;
      defaultLabel = l10n.llmProvidersTitle;
      onDefault = () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => const LlmProvidersScreen(),
          ),
        );
      };
      break;
    case LlmSetupStatus.noTitleModelConfigured:
      message = l10n.pleaseConfigureTitleModel;
      defaultLabel = l10n.titleModelTitle;
      onDefault = () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => DefaultModelPickerScreen(
              title: l10n.titleModelTitle,
              currentProviderId: null,
              currentModelId: null,
              onSelected: (providerId, modelId) async {
                await container
                    .read(settingsControllerProvider.notifier)
                    .saveTitleModel(
                      providerId: providerId,
                      modelId: modelId,
                    );
              },
            ),
          ),
        );
      };
      break;
    case LlmSetupStatus.noSummaryModelConfigured:
      message = l10n.pleaseConfigureSummaryModel;
      defaultLabel = l10n.summaryModelTitle;
      onDefault = () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => DefaultModelPickerScreen(
              title: l10n.summaryModelTitle,
              currentProviderId: null,
              currentModelId: null,
              onSelected: (providerId, modelId) async {
                await container
                    .read(settingsControllerProvider.notifier)
                    .saveSummaryModel(
                      providerId: providerId,
                      modelId: modelId,
                    );
              },
            ),
          ),
        );
      };
      break;
    case LlmSetupStatus.ok:
      return;
  }

  // 总结功能：不能取消，只有一个按钮（跳转设置页）
  // 标题生成：可以取消（用户可以在标题页右上角按钮进入设置页）
  final bool isSummary = status == LlmSetupStatus.noSummaryModelConfigured;
  await ThkAlert.show(
    context: context,
    message: message,
    defaultAction: defaultLabel,
    onDefault: onDefault,
    cancelAction: isSummary ? null : l10n.cancel,
    barrierDismissible: !isSummary,
  );
}
