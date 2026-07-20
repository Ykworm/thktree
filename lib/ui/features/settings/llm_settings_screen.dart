import 'package:flutter/cupertino.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/llm/llm_providers_screen.dart';
import 'package:thk_tree/ui/features/settings/default_model_config_screen.dart';

/// 大模型设置页
///
/// 设置页 → 大模型入口的目标页。
/// 包含两个子项：
/// - 模型提供商：跳转到现有的 LlmProvidersScreen
/// - 默认模型配置：跳转到 DefaultModelConfigScreen
class LlmSettingsScreen extends StatelessWidget {
  const LlmSettingsScreen({super.key, this.parentCrumbs = const []});

  final List<BreadcrumbSegment> parentCrumbs;

  BreadcrumbSegment _ownCrumb(AppLocalizations l10n) =>
      BreadcrumbSegment(label: l10n.breadcrumbLLM, routeName: 'llm-settings');

  List<BreadcrumbSegment> _crumbs(AppLocalizations l10n) => [...parentCrumbs, _ownCrumb(l10n)];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.llmSettings),
      ),
      child: SafeArea(
        child: Column(
          children: [
            ThkBreadcrumbRow(crumbs: _crumbs(l10n)),
            Expanded(
              child: ThkFillCardPageBody(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: 2,
                  separatorBuilder: (context, index) => Container(
                    height: 0.5,
                    margin: const EdgeInsetsDirectional.only(start: 16),
                    color: AppColors.border,
                  ),
                  itemBuilder: (context, index) {
                    switch (index) {
                      case 0:
                        return ThkListTile(
                          title: l10n.llmProvidersTitle,
                          backgroundColor: AppColors.surface,
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                settings: const RouteSettings(name: 'providers-list'),
                                builder: (context) => LlmProvidersScreen(
                                  parentCrumbs: _crumbs(l10n),
                                ),
                              ),
                            );
                          },
                        );
                      case 1:
                        return ThkListTile(
                          title: l10n.defaultModelConfig,
                          backgroundColor: AppColors.surface,
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                settings: const RouteSettings(name: 'default-model-config'),
                                builder: (context) => DefaultModelConfigScreen(
                                  parentCrumbs: _crumbs(l10n),
                                ),
                              ),
                            );
                          },
                        );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
