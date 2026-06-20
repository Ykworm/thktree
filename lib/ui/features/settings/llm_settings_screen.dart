import 'package:flutter/cupertino.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/features/llm/llm_providers_screen.dart';
import 'package:thk_tree/ui/features/settings/default_model_config_screen.dart';

/// 大模型设置页
///
/// 设置页 → 大模型入口的目标页。
/// 包含两个子项：
/// - 模型提供商：跳转到现有的 LlmProvidersScreen
/// - 默认模型配置：跳转到 DefaultModelConfigScreen
class LlmSettingsScreen extends StatelessWidget {
  const LlmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.llmSettings),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              children: [
                // 模型提供商
                CupertinoListTile(
                  title: Text(l10n.llmProvidersTitle),
                  trailing: const Icon(CupertinoIcons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => const LlmProvidersScreen(),
                      ),
                    );
                  },
                ),
                // 默认模型配置
                CupertinoListTile(
                  title: Text(l10n.defaultModelConfig),
                  trailing: const Icon(CupertinoIcons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => const DefaultModelConfigScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
