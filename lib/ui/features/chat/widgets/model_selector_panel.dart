import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';

/// 模型选择面板，采用上推布局（面板出现时对话内容上推）。
///
/// 支持按模型名/提供商名搜索过滤。
/// 点击 panel 外部（消息列表 / context bar / 输入框 / 模型按钮 / panel 内
/// 标题栏空白）会关闭 panel，panel 内部 tap 由 panel 自身消化，不会触发
/// 外部 dismiss 行为。panel 不再提供关闭按钮，依靠外部点击完成 dismiss。
class ModelSelectorPanel extends ConsumerStatefulWidget {
  const ModelSelectorPanel({
    super.key,
    required this.currentProviderId,
    required this.currentModelId,
    required this.onModelSelected,
  });

  final String? currentProviderId;
  final String? currentModelId;
  final void Function(String providerId, String modelId) onModelSelected;

  @override
  ConsumerState<ModelSelectorPanel> createState() => _ModelSelectorPanelState();
}

class _ModelSelectorPanelState extends ConsumerState<ModelSelectorPanel> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final providersAsync = ref.watch(llmProvidersProvider);

    return providersAsync.when(
      data: (providers) {
        // 只显示已配置好的提供商：有模型列表或有已选中的模型
        var configuredProviders = providers
            .where((p) =>
                p.models.isNotEmpty ||
                (p.selectedModelId != null &&
                    p.selectedModelId!.isNotEmpty))
            .toList();

        // 搜索过滤
        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          configuredProviders = configuredProviders.map((p) {
            final matchedModels = p.models
                .where((m) =>
                    m.name.toLowerCase().contains(q) ||
                    m.id.toLowerCase().contains(q))
                .toList();
            return (provider: p, matchedModels: matchedModels);
          }).where((e) =>
              e.matchedModels.isNotEmpty ||
              e.provider.name.toLowerCase().contains(q)).toList()
              .map((e) => e.provider).toList();
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * AppSp.sheetHeightSm,
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
                  child: Text(
                    l10n.selectModel,
                    style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                  ),
                ),
                // 搜索栏（始终挂载，避免无结果时被卸载导致焦点跳到输入框）
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: l10n.searchModels,
                    style: CupertinoTheme.of(context).textTheme.textStyle,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Container(
                  height: AppSp.dividerThickness,
                  color: AppColors.border,
                ),
                // 模型列表 / 空状态
                Flexible(
                  child: configuredProviders.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          child: Text(
                            _query.isEmpty ? l10n.pleaseFetchModels : l10n.noModelsFound,
                            textAlign: TextAlign.center,
                            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          shrinkWrap: true,
                          itemCount: configuredProviders.length,
                          itemBuilder: (context, index) {
                            final provider = configuredProviders[index];
                            return _ProviderGroup(
                              provider: provider,
                              currentProviderId: widget.currentProviderId,
                              currentModelId: widget.currentModelId,
                              onModelSelected: widget.onModelSelected,
                              query: _query,
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
    required this.query,
  });

  final LlmProviderConfig provider;
  final String? currentProviderId;
  final String? currentModelId;
  final void Function(String providerId, String modelId) onModelSelected;
  final String query;

  @override
  Widget build(BuildContext context) {
    var models = provider.models;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      models = models
          .where((m) =>
              m.name.toLowerCase().contains(q) ||
              m.id.toLowerCase().contains(q))
          .toList();
    }

    final hasModels = models.isNotEmpty;
    // 没有 models 但有 selectedModelId 时，搜索时也需匹配
    final hasSelectedModel = provider.selectedModelId != null &&
        provider.selectedModelId!.isNotEmpty &&
        (query.isEmpty ||
            provider.selectedModelId!.toLowerCase().contains(query.toLowerCase()));

    if (!hasModels && !hasSelectedModel) return const SizedBox.shrink();

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
          for (final model in models)
            _ModelItem(
              providerId: provider.id,
              model: model,
              isSelected:
                  provider.id == currentProviderId &&
                  model.id == currentModelId,
              onTap: () => onModelSelected(provider.id, model.id),
            )
        else
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
            : AppColors.transparent,
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
