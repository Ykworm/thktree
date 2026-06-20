import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/settings/default_model_picker_screen.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// 默认模型配置页
///
/// 展示三个默认模型设置项（聊天 / 标题生成 / 对话总结）。
/// 每个设置项点击后弹出按提供商分组的模型选择器。
class DefaultModelConfigScreen extends ConsumerWidget {
  const DefaultModelConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsControllerProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.defaultModelConfig),
      ),
      child: SafeArea(
        child: settingsAsync.when(
          data: (_) => ThkFillCardPageBody(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: 3,
              separatorBuilder: (context, index) => Container(
                height: 0.5,
                margin: const EdgeInsetsDirectional.only(start: 16),
                color: CupertinoColors.separator.resolveFrom(context),
              ),
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildModelTile(
                      context: context,
                      ref: ref,
                      title: l10n.chatDefaultModel,
                      settingsAsync: settingsAsync,
                      getProviderId: (s) => s.chatDefaultProviderId,
                      getModelId: (s) => s.chatDefaultModelId,
                      onSave: (providerId, modelId) => ref
                          .read(settingsControllerProvider.notifier)
                          .saveChatDefaultModel(
                              providerId: providerId, modelId: modelId),
                    );
                  case 1:
                    return _buildModelTile(
                      context: context,
                      ref: ref,
                      title: l10n.titleModelTitle,
                      settingsAsync: settingsAsync,
                      getProviderId: (s) => s.titleModelProviderId,
                      getModelId: (s) => s.titleModelModelId,
                      onSave: (providerId, modelId) => ref
                          .read(settingsControllerProvider.notifier)
                          .saveTitleModel(
                              providerId: providerId, modelId: modelId),
                    );
                  case 2:
                    return _buildModelTile(
                      context: context,
                      ref: ref,
                      title: l10n.summaryModelTitle,
                      settingsAsync: settingsAsync,
                      getProviderId: (s) => s.summaryModelProviderId,
                      getModelId: (s) => s.summaryModelModelId,
                      onSave: (providerId, modelId) => ref
                          .read(settingsControllerProvider.notifier)
                          .saveSummaryModel(
                              providerId: providerId, modelId: modelId),
                    );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          loading: () => const ThkFillCardPageBody(
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (e, st) => ThkFillCardPageBody(
            child: Center(child: Text(e.toString())),
          ),
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
    final providersAsync = ref.watch(llmProvidersProvider);

    return settingsAsync.when(
      data: (settings) {
        final providerId = getProviderId(settings);
        final modelId = getModelId(settings);
        final subtitle = _resolveModelSubtitle(
          l10n: l10n,
          providersAsync: providersAsync,
          providerId: providerId,
          modelId: modelId,
        );

        return ThkListTile(
          title: title,
          subtitle: subtitle,
          onTap: () => _openModelPicker(
            context: context,
            title: title,
            providerId: providerId,
            modelId: modelId,
            onSave: onSave,
          ),
        );
      },
      loading: () => ThkListTile(
        title: title,
        trailing: const CupertinoActivityIndicator(),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  String _resolveModelSubtitle({
    required AppLocalizations l10n,
    required AsyncValue<List<LlmProviderConfig>> providersAsync,
    required String? providerId,
    required String? modelId,
  }) {
    if (providerId == null || modelId == null) return l10n.notSet;

    final providers = providersAsync.value;
    if (providers == null) return modelId;

    final provider = providers.where((item) => item.id == providerId).firstOrNull;
    if (provider == null) return modelId;

    final model = provider.models.where((item) => item.id == modelId).firstOrNull;
    if (model == null) return '${provider.name} · $modelId';

    return '${provider.name} · ${model.name}';
  }

  void _openModelPicker({
    required void Function(String? providerId, String? modelId) onSave,
    required BuildContext context,
    required String title,
    required String? providerId,
    required String? modelId,
  }) {
    Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => DefaultModelPickerScreen(
          title: title,
          currentProviderId: providerId,
          currentModelId: modelId,
          onSelected: (nextProviderId, nextModelId) async {
            onSave(nextProviderId, nextModelId);
          },
        ),
      ),
    );
  }
}
