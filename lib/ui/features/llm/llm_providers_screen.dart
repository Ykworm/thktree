import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/llm/llm_provider_detail_screen.dart';

/// LLM 提供商列表页面
class LlmProvidersScreen extends ConsumerWidget {
  const LlmProvidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final providersAsync = ref.watch(llmProvidersProvider);

    return ThkLargeTitlePage(
      title: l10n.llmProvidersTitle,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            CupertinoPageRoute(
              builder: (_) => const LlmProviderDetailScreen(),
            ),
          );
          if (result == true) {
            ref.invalidate(llmProvidersProvider);
          }
        },
        child: Icon(AppIcons.add),
      ),
      children: [
        providersAsync.when(
          data: (providers) => _ProviderList(providers: providers),
          loading: () => const SliverToBoxAdapter(
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (e, st) => SliverToBoxAdapter(
            child: Center(child: Text(e.toString())),
          ),
        ),
      ],
    );
  }
}

class _ProviderList extends ConsumerWidget {
  const _ProviderList({required this.providers});

  final List<LlmProviderConfig> providers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    if (providers.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(child: Text(l10n.noModels)),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final provider = providers[index];
          final isCustom = provider.type == LlmProviderType.custom;

          return ThkListSection(
            children: [
              _ProviderTile(
                provider: provider,
                isCustom: isCustom,
                onTap: () async {
                  final result = await Navigator.of(context).push<bool>(
                    CupertinoPageRoute(
                      builder: (_) =>
                          LlmProviderDetailScreen(provider: provider),
                    ),
                  );
                  if (result == true) {
                    ref.invalidate(llmProvidersProvider);
                  }
                },
              ),
            ],
          );
        },
        childCount: providers.length,
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.provider,
    required this.isCustom,
    required this.onTap,
  });

  final LlmProviderConfig provider;
  final bool isCustom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modelCount = provider.models.length;
    final modelText =
        modelCount > 0 ? l10n.modelCount(modelCount) : l10n.noModels;

    return ThkListTile(
      title: provider.name,
      subtitle: modelText,
      leading: Icon(isCustom ? AppIcons.extensionIcon : AppIcons.cloud),
      onTap: onTap,
    );
  }
}
