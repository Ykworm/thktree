import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/llm/llm_provider_detail_screen.dart';

/// LLM 提供商列表页面
class LlmProvidersScreen extends ConsumerWidget {
  const LlmProvidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final providersAsync = ref.watch(llmProvidersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.llmProvidersTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: providersAsync.when(
            data: (providers) => _ProviderList(providers: providers),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text(e.toString())),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addCustomProvider,
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const LlmProviderDetailScreen(),
            ),
          );
          if (result == true) {
            ref.invalidate(llmProvidersProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
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
      return Center(child: Text(l10n.noModels));
    }

    return ListView.builder(
      itemCount: providers.length,
      itemBuilder: (context, index) {
        final provider = providers[index];
        final isCustom = provider.type == LlmProviderType.custom;

        return _ProviderTile(
          provider: provider,
          isCustom: isCustom,
          onTap: () async {
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => LlmProviderDetailScreen(provider: provider),
              ),
            );
            if (result == true) {
              ref.invalidate(llmProvidersProvider);
            }
          },
        );
      },
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
    final modelText = modelCount > 0
        ? l10n.modelCount(modelCount)
        : l10n.noModels;

    return ListTile(
      leading: Icon(isCustom ? Icons.extension : Icons.cloud),
      title: Text(provider.name),
      subtitle: FutureBuilder<String>(
        future: _buildSubtitle(l10n, modelText),
        initialData: modelText,
        builder: (context, snapshot) => Text(snapshot.data ?? modelText),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<String> _buildSubtitle(
    AppLocalizations l10n,
    String modelText,
  ) async {
    // We show model count, but apiKey status is async — skip for simplicity
    // The detail screen handles apiKey display
    return modelText;
  }
}
