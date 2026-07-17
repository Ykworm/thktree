import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thk_tree/data/services/keyword_global_storage.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/lab/keyword_ranking/keyword_list_view.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// 加载 `keyword_global.json` 的 file-scoped FutureProvider。
///
/// 监听 [keywordGlobalStorageProvider]，在 storage 就绪后调用
/// [KeywordGlobalStorage.loadOrInit] 拿到当前 [KeywordGlobalFile]。
///
/// 单独的 provider 让调用方用标准的 `ref.watch(...).when(...)` 处理三态，
/// 也方便 analyze / cleanup 等操作完成后调用 `ref.invalidate` 触发刷新。
/// 全局关键词排行数据（分析完成后可 [Ref.invalidate] 刷新）。
final keywordRankingFileProvider = FutureProvider<KeywordGlobalFile>((ref) async {
  final storage = await ref.watch(keywordGlobalStorageProvider.future);
  return storage.loadOrInit();
});

/// 关键词排行榜主屏（Task 8b）。
///
/// Lab tab 子功能入口（P.9 候选），回顾用户最近的思考脉络：
///   - 顶部「分析」按钮 → 跳转 `/lab/keyword-ranking/select-leaves`
///   - 显示全局聚合的关键词排名（score 倒序）
///   - 显示「上次更新时间」
///   - 支持下拉刷新
///
/// 当前（Task 8b）仅渲染列表 + 分析按钮；Detail 视图、score 编辑、
/// theme 删除清理等在 Task 9 / 11 / 12 中实现。
class KeywordRankingScreen extends ConsumerWidget {
  const KeywordRankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 跟踪深色模式变化，触发 UI 重建。
    ref.watch(brightnessProvider);

    final l10n = AppLocalizations.of(context)!;
    final asyncFile = ref.watch(keywordRankingFileProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      child: CustomScrollView(
        slivers: [
          ThkNavBar.large(
            title: l10n.keywordRankingTitle,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () =>
                  context.push('/lab/keyword-ranking/select-theme'),
              child: Text(
                l10n.keywordRankingAnalyze,
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              ref.invalidate(keywordRankingFileProvider);
              // 等待新一轮刷新完成，避免下拉指示器立即消失。
              await ref.read(keywordRankingFileProvider.future);
            },
          ),
          asyncFile.when(
            data: (file) => KeywordListView(
              file: file,
              onKeywordTap: (entry) {
                context.push(
                  '/lab/keyword-ranking/detail/${Uri.encodeComponent(entry.keyword)}',
                );
              },
            ),
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.destructive,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
