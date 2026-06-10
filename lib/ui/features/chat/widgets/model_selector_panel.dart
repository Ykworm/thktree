import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';

/// 模型选择面板，采用上推布局（面板出现时对话内容上推）。
class ModelSelectorPanel extends ConsumerWidget {
  const ModelSelectorPanel({
    super.key,
    required this.currentProviderId,
    required this.currentModelId,
    required this.onModelSelected,
    required this.onClose,
  });

  final String? currentProviderId;
  final String? currentModelId;
  final void Function(String providerId, String modelId) onModelSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final providersAsync = ref.watch(llmProvidersProvider);

    return providersAsync.when(
      data: (providers) {
        // 只显示已配置好的提供商：有模型列表或有已选中的模型
        final configuredProviders = providers
            .where((p) =>
                p.models.isNotEmpty ||
                (p.selectedModelId != null &&
                    p.selectedModelId!.isNotEmpty))
            .toList();

        if (configuredProviders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                l10n.pleaseFetchModels,
                textAlign: TextAlign.center,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.35,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: CupertinoTheme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: AppColors.border,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        l10n.selectModel,
                        style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: onClose,
                        child: const Icon(
                          CupertinoIcons.xmark,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  color: AppColors.border,
                ),
                // 模型列表
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    shrinkWrap: true,
                    itemCount: configuredProviders.length,
                    itemBuilder: (context, index) {
                      final provider = configuredProviders[index];
                      return _ProviderGroup(
                        provider: provider,
                        currentProviderId: currentProviderId,
                        currentModelId: currentModelId,
                        onModelSelected: onModelSelected,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }
}

class _ProviderGroup extends StatelessWidget {
  const _ProviderGroup({
    required this.provider,
    required this.currentProviderId,
    required this.currentModelId,
    required this.onModelSelected,
  });

  final LlmProviderConfig provider;
  final String? currentProviderId;
  final String? currentModelId;
  final void Function(String providerId, String modelId) onModelSelected;

  @override
  Widget build(BuildContext context) {
    final hasModels = provider.models.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题：提供商名称
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            provider.name,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        if (hasModels)
          // 模型列表项
          for (final model in provider.models)
            _ModelItem(
              providerId: provider.id,
              model: model,
              isSelected:
                  provider.id == currentProviderId &&
                  model.id == currentModelId,
              onTap: () => onModelSelected(provider.id, model.id),
            )
        else
          // 没有 models 但有 selectedModelId，显示该模型
          _ModelItem(
            providerId: provider.id,
            model: LlmModelConfig(
              id: provider.selectedModelId!,
              name: provider.selectedModelId!,
              contextWindow: 0,
            ),
            isSelected:
                provider.id == currentProviderId &&
                provider.selectedModelId == currentModelId,
            onTap: () =>
                onModelSelected(provider.id, provider.selectedModelId!),
          ),
      ],
    );
  }
}

class _ModelItem extends StatelessWidget {
  const _ModelItem({
    required this.providerId,
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  final String providerId;
  final LlmModelConfig model;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: isSelected
            ? AppColors.accentLight
            : CupertinoColors.transparent,
        padding: const EdgeInsets.fromLTRB(32, 10, 16, 10),
        child: Row(
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  CupertinoIcons.checkmark,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
            Expanded(
              child: Text(
                model.name,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
