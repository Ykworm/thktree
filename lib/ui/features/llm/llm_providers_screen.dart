import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/llm/llm_provider_detail_screen.dart';


/// LLM 提供商列表页面
class LlmProvidersScreen extends ConsumerWidget {
  const LlmProvidersScreen({super.key, this.parentCrumbs = const []});

  final List<BreadcrumbSegment> parentCrumbs;

  static const _ownCrumb = BreadcrumbSegment(label: '提供商', routeName: 'providers-list');

  List<BreadcrumbSegment> get _crumbs => [...parentCrumbs, _ownCrumb];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final providersAsync = ref.watch(llmProvidersProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.llmProvidersTitle),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            final result = await Navigator.of(context).push<bool>(
              CupertinoPageRoute(
                settings: const RouteSettings(name: 'provider-detail'),
                builder: (_) => LlmProviderDetailScreen(parentCrumbs: _crumbs),
              ),
            );
            if (result == true) {
              ref.invalidate(llmProvidersProvider);
            }
          },
          child: Icon(AppIcons.add),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            ThkBreadcrumbRow(crumbs: _crumbs),
            Expanded(
              child: providersAsync.when(
                data: (providers) {
            // 只显示 APP 支持的提供商
            final visible = providers
                .where((p) => visibleProviderTypes.contains(p.type))
                .toList();
            if (visible.isEmpty) {
              return ThkFillCardPageBody(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.cloud,
                        size: 40,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noModels,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ThkFillCardPageBody(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: visible.length,
                separatorBuilder: (context, index) => Container(
                  height: 0.5,
                  margin: const EdgeInsetsDirectional.only(start: 16),
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                itemBuilder: (context, index) {
                  final provider = visible[index];
                  return _ProviderTile(
                    provider: provider,
                    onTap: () async {
                      final result = await Navigator.of(context).push<bool>(
                        CupertinoPageRoute(
                          settings: const RouteSettings(name: 'provider-detail'),
                          builder: (_) =>
                              LlmProviderDetailScreen(provider: provider, parentCrumbs: _crumbs),
                        ),
                      );
                      if (result == true) {
                        ref.invalidate(llmProvidersProvider);
                      }
                    },
                    onClearModels: provider.models.isNotEmpty
                        ? () async {
                            final confirmed = await showCupertinoDialog<bool>(
                              context: context,
                              builder: (ctx) {
                                return CupertinoAlertDialog(
                                  title: Text(l10n.clearModels),
                                  content: Text(
                                    l10n.clearModelsConfirm(provider.name),
                                  ),
                                  actions: [
                                    CupertinoDialogAction(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: Text(l10n.cancel),
                                    ),
                                    CupertinoDialogAction(
                                      isDestructiveAction: true,
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: Text(l10n.clear),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (confirmed == true) {
                              final configStore =
                                  ref.read(llmConfigStoreProvider);
                              await configStore.updateModels(provider.id, []);
                              if (context.mounted) {
                                ref.invalidate(llmProvidersProvider);
                              }
                            }
                          }
                        : null,
                  );
                },
              ),
            );
          },
          loading: () => const ThkFillCardPageBody(
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (e, st) => ThkFillCardPageBody(
            child: Center(child: Text(e.toString())),
          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.provider,
    required this.onTap,
    this.onClearModels,
  });

  final LlmProviderConfig provider;
  final VoidCallback onTap;
  final VoidCallback? onClearModels;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modelCount = provider.models.length;
    final modelText =
        modelCount > 0 ? l10n.modelCount(modelCount) : l10n.noModels;

    return ThkListTile(
      title: provider.name,
      subtitle: modelText,
      leading: null,
      trailing: onClearModels != null
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onClearModels,
              child: Icon(
                AppIcons.delete,
                color: CupertinoColors.destructiveRed,
                size: 20,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
