import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
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
                      .saveChatDefaultModel(
                          providerId: providerId, modelId: modelId),
                ),
                // 标题生成模型
                _buildModelTile(
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
                ),
                // 对话总结模型
                _buildModelTile(
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
      final configuredProviders =
          providers.where((p) => p.models.isNotEmpty).toList();

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
              ..._buildProviderActions(provider, onSave, ctx),
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
