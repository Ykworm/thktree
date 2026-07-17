import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/chat/chat_screen_launch_params.dart';
import 'package:thk_tree/ui/features/lab/thinking_collision/thinking_collision_controller.dart';

/// 思维碰撞页面。
///
/// - 碰撞对列表（仅本地配对，不调 LLM）
/// - 点击碰撞对 → 创建 chat node → 跳转对话页（LLM 在对话页触发）
class ThinkingCollisionScreen extends ConsumerStatefulWidget {
  const ThinkingCollisionScreen({super.key});

  @override
  ConsumerState<ThinkingCollisionScreen> createState() =>
      _ThinkingCollisionScreenState();
}

class _ThinkingCollisionScreenState
    extends ConsumerState<ThinkingCollisionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(thinkingCollisionControllerProvider.notifier).loadPairs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(thinkingCollisionControllerProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      child: CustomScrollView(
        slivers: [
          ThkNavBar.large(title: l10n.thinkingCollisionTitle),
          // 操作栏
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Text(
                    l10n.thinkingCollisionHint,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: state.loading
                        ? null
                        : () {
                            ref
                                .read(
                                    thinkingCollisionControllerProvider.notifier)
                                .shuffle();
                          },
                    child: Icon(
                      CupertinoIcons.shuffle,
                      size: 20,
                      color: state.loading
                          ? AppColors.textTertiary
                          : AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 内容
          if (state.loading && state.pairs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      l10n.thinkingCollisionLoading,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (!state.loading && state.pairs.isEmpty && state.error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.lightbulb,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.error == 'no_keywords'
                            ? l10n.thinkingCollisionNoKeywords
                            : state.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.separated(
                itemCount: state.pairs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final pair = state.pairs[index];
                  return _CollisionCard(
                    pair: pair,
                    creating: state.creatingChat,
                    onTap: () => _onPairTap(pair),
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  Future<void> _onPairTap(CollisionPair pair) async {
    final result = await ref
        .read(thinkingCollisionControllerProvider.notifier)
        .createChatFromPair(pair);

    if (result != null && mounted) {
      context.push(
        '/themes/${result.themeId}/nodes/${result.nodeId}',
        extra: ChatScreenLaunchParams(
          title: result.title,
          autoTriggerReply: true,
        ),
      );
    }
  }
}

/// 碰撞对卡片。
class _CollisionCard extends StatelessWidget {
  const _CollisionCard({
    required this.pair,
    required this.creating,
    required this.onTap,
  });

  final CollisionPair pair;
  final bool creating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: creating ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 关键词配对
            Row(
              children: [
                Expanded(
                  child: Text(
                    pair.keywordA,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    CupertinoIcons.bolt_horizontal,
                    size: 16,
                    color: AppColors.labAccentPurple,
                  ),
                ),
                Expanded(
                  child: Text(
                    pair.keywordB,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 摘要（如有）
            if (pair.summary != null)
              Text(
                pair.summary!,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
