import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// 分享卡片 Widget —— 用于截图生成图片
///
/// 用 [RepaintBoundary] 包裹后通过 `toImage()` 截图。
/// 仅用于渲染，不展示在页面上。
class ShareCardWidget extends StatelessWidget {
  const ShareCardWidget({
    super.key,
    this.userQuestion,
    required this.assistantAnswer,
  });

  /// 用户提问（可选，可能为 null 或空）
  final String? userQuestion;

  /// AI 回答
  final String assistantAnswer;

  static const double _cardWidth = 400;
  static const double _padding = 20;
  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final hasQuestion =
        userQuestion != null && userQuestion!.trim().isNotEmpty;

    return Container(
      width: _cardWidth,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 品牌标识 ──
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ThkTree',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),

            // ── 用户问题 ──
            if (hasQuestion) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  userQuestion!,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // ── AI 回答 ──
            const SizedBox(height: 16),
            GptMarkdown(
              assistantAnswer,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppColors.textPrimary,
              ),
            ),

            // ── 底部分隔线 ──
            const SizedBox(height: 20),
            Container(
              height: 0.5,
              color: AppColors.border,
            ),
            const SizedBox(height: 12),
            const Text(
              'Shared from ThkTree',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
