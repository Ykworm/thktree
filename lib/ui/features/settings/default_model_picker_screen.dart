import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';

class DefaultModelPickerScreen extends ConsumerWidget {
  const DefaultModelPickerScreen({
    super.key,
    required this.title,
    required this.currentProviderId,
    required this.currentModelId,
    required this.onSelected,
  });

  final String title;
  final String? currentProviderId;
  final String? currentModelId;
  final Future<void> Function(String providerId, String modelId) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final providersAsync = ref.watch(llmProvidersProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: ThkNavBar.inline(title: title),
      child: SafeArea(
        child: providersAsync.when(
          data: (providers) {
            final configuredProviders =
                providers.where((provider) => provider.models.isNotEmpty).toList();

            if (configuredProviders.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    l10n.pleaseFetchModels,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            return ThkFillCardPageBody(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                children: [
                  for (final provider in configuredProviders) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Text(
                        provider.name,
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                      ),
                    ),
                    for (int index = 0; index < provider.models.length; index++) ...[
                      _SelectableModelTile(
                        model: provider.models[index],
                        isSelected: provider.id == currentProviderId &&
                            provider.models[index].id == currentModelId,
                        onTap: () async {
                          await onSelected(
                            provider.id,
                            provider.models[index].id,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        },
                      ),
                      if (index < provider.models.length - 1)
                        Container(
                          height: 0.5,
                          margin: const EdgeInsetsDirectional.only(start: 16),
                          color: CupertinoColors.separator.resolveFrom(context),
                        ),
                    ],
                  ],
                ],
              ),
            );
          },
          loading: () => const ThkFillCardPageBody(
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (e, _) => ThkFillCardPageBody(
            child: Center(child: Text(e.toString())),
          ),
        ),
      ),
    );
  }
}

class _SelectableModelTile extends StatelessWidget {
  const _SelectableModelTile({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  final LlmModelConfig model;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ThkListTile(
      title: model.name,
      subtitle: model.id == model.name ? null : model.id,
      trailing: isSelected
          ? Icon(AppIcons.check, color: AppColors.accent, size: 18)
          : null,
      onTap: onTap,
    );
  }
}
