import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';

/// 弹出模型选择面板（底部弹层）。
///
/// 面板从底部滑入，带半透明遮罩；点击面板外部关闭。选中模型后先关闭弹层，
/// 再回调 [onModelSelected]。键盘弹起时面板自动上移避开搜索框。
Future<void> showModelSelectorSheet({
  required BuildContext context,
  required String? currentProviderId,
  required String? currentModelId,
  required void Function(String providerId, String modelId) onModelSelected,
}) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) {
      // shell 为叠 tab 注入了额外 padding.bottom；弹层若继承会把面板挤扁/顶飞。
      // 用 View 原始 padding 还原系统安全区。
      final view = View.of(ctx);
      final raw = MediaQueryData.fromView(view);
      final mq = MediaQuery.of(ctx);
      return MediaQuery(
        data: mq.copyWith(
          padding: raw.padding,
          viewPadding: raw.viewPadding,
          // 键盘 inset 用引擎原始值，避免被 shell 篡改
          viewInsets: raw.viewInsets,
        ),
        child: Builder(
          builder: (inner) => GestureDetector(
            // 点遮罩关闭；面板本体再拦一层，避免点列表也 pop
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(ctx).pop(),
            child: ColoredBox(
              color: AppColors.scrim.withValues(alpha: 0.35),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(inner).bottom,
                  ),
                  child: GestureDetector(
                    onTap: () {}, // 吞掉面板内点击，不冒泡到遮罩
                    child: ModelSelectorPanel(
                      currentProviderId: currentProviderId,
                      currentModelId: currentModelId,
                      onModelSelected: (providerId, modelId) {
                        Navigator.of(ctx).pop();
                        onModelSelected(providerId, modelId);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// 模型选择面板（作为底部弹层内容，由 [showModelSelectorSheet] 弹出）。
///
/// 支持按模型名/提供商名搜索过滤。点击面板外部（弹层遮罩）关闭，
/// 选中模型后关闭弹层并回调。
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
            .where(
              (p) =>
                  p.models.isNotEmpty ||
                  (p.selectedModelId != null && p.selectedModelId!.isNotEmpty),
            )
            .toList();

        // 搜索过滤
        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          configuredProviders = configuredProviders
              .map((p) {
                final matchedModels = p.models
                    .where(
                      (m) =>
                          m.name.toLowerCase().contains(q) ||
                          m.id.toLowerCase().contains(q),
                    )
                    .toList();
                return (provider: p, matchedModels: matchedModels);
              })
              .where(
                (e) =>
                    e.matchedModels.isNotEmpty ||
                    e.provider.name.toLowerCase().contains(q),
              )
              .toList()
              .map((e) => e.provider)
              .toList();
        }

        // 固定高度白卡贴底：与遮罩/pageBg 分离；Expanded 列表占满剩余空间
        final sheetH =
            MediaQuery.sizeOf(context).height * AppSp.sheetHeightMd;
        return SizedBox(
          height: sheetH,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSp.sheetTopRadius),
              ),
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.elevationShadow,
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // 拖拽指示条
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                // 标题栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    l10n.selectModel,
                    style: CupertinoTheme.of(
                      context,
                    ).textTheme.navTitleTextStyle,
                  ),
                ),
                // 搜索栏（始终挂载，避免无结果时被卸载导致焦点跳到输入框）
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: l10n.searchModels,
                    style: CupertinoTheme.of(context).textTheme.textStyle,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Container(
                  height: AppSp.dividerThickness,
                  color: AppColors.border,
                ),
                // 模型列表 / 空状态
                Expanded(
                  child: configuredProviders.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 24,
                          ),
                          child: Text(
                            _query.isEmpty
                                ? l10n.pleaseFetchModels
                                : l10n.noModelsFound,
                            textAlign: TextAlign.center,
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
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
          .where(
            (m) =>
                m.name.toLowerCase().contains(q) ||
                m.id.toLowerCase().contains(q),
          )
          .toList();
    }

    final hasModels = models.isNotEmpty;
    // 没有 models 但有 selectedModelId 时，搜索时也需匹配
    final hasSelectedModel =
        provider.selectedModelId != null &&
        provider.selectedModelId!.isNotEmpty &&
        (query.isEmpty ||
            provider.selectedModelId!.toLowerCase().contains(
              query.toLowerCase(),
            ));

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
        color: isSelected ? AppColors.accentLight : AppColors.transparent,
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
                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
