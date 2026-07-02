import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// 关键词分析 — 主题选择屏。
///
/// 展示所有主题列表，用户选择一个主题后跳转到对话选择页。
class ThemeSelectionScreen extends ConsumerWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(brightnessProvider);
    final l10n = AppLocalizations.of(context)!;

    final themeStoreAsync = ref.watch(themeStoreProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: l10n.keywordRankingTitle,
        middle: Text(l10n.keywordRankingSelectThemes),
      ),
      child: themeStoreAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 48,
                  color: AppColors.destructive,
                ),
                const SizedBox(height: 16),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoButton.filled(
                  onPressed: () => ref.invalidate(themeStoreProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
        data: (themeStore) => FutureBuilder(
          future: themeStore.listThemes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final themes = snapshot.data ?? [];

            if (themes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.tray,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.keywordRankingNoThemes,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                // 使用说明
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
                    child: Text(
                      l10n.keywordRankingSelectThemesHint,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

                // 主题列表
                SliverList(
                  delegate: SliverChildListDelegate([
                    for (int i = 0; i < themes.length; i++) ...[
                      ThkListTile(
                        leading: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Icon(
                            CupertinoIcons.folder,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        title: themes[i].title,
                        trailing: ThkListTile.chevron,
                        onTap: () {
                          context.push(
                            '/lab/keyword-ranking/select-leaves?themeId=${themes[i].themeId}',
                          );
                        },
                      ),
                      if (i < themes.length - 1)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 56),
                          child: Container(height: 0.5, color: AppColors.border),
                        ),
                    ],
                  ]),
                ),

                // 底部留白
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
