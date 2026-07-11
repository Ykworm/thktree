import 'package:flutter/cupertino.dart';
import 'package:thk_tree/data/models/llm_error.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart' show ThkButton;

/// 统一的 LLM 错误展示组件。
///
/// 两种形态：
/// - 默认（`compact: false`）：占位卡片，居中显示图标 + 文案 + `[重试] [取消]` 按钮。
/// - compact（`compact: true`）：inline 横条，左图标 + 错误文案 + `[重试] [取消]` 按钮。
///
/// `error.kind == LlmErrorKind.cancelled` 时调用方不应渲染此组件（见 [LlmError.isRetriable]）。
class LlmErrorCard extends StatelessWidget {
  const LlmErrorCard({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onCancel,
    this.title,
    this.compact = false,
  });

  /// 错误模型（必传）。
  final LlmError error;

  /// [重试] 回调（必传）。按钮文案始终为 `l10n.llmErrorRetry`。
  final VoidCallback onRetry;

  /// [取消] 回调（必传）。按钮文案始终为 `l10n.llmErrorCancel`。
  /// 取消语义由调用方决定：可为 `Navigator.pop()` / `setState` 清错误 / `cancelToken.cancel()` 等。
  final VoidCallback onCancel;

  /// 可选：覆盖标题（默认从 `l10n` 取对应 kind 的文案）。
  final String? title;

  /// true = inline 横条；false（默认）= 占位卡片。
  final bool compact;

  String _resolveMessage(AppLocalizations l10n) {
    return switch (error.kind) {
      LlmErrorKind.network => l10n.llmErrorNetwork,
      LlmErrorKind.timeout => l10n.llmErrorTimeout,
      LlmErrorKind.rateLimited => l10n.llmErrorRateLimited,
      LlmErrorKind.authFailed => l10n.llmErrorAuthFailed,
      LlmErrorKind.paymentRequired => l10n.llmErrorPaymentRequired,
      LlmErrorKind.serverError => l10n.llmErrorServerError,
      LlmErrorKind.cancelled => l10n.llmErrorCancel,
      LlmErrorKind.unknown => l10n.llmErrorUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = title ?? _resolveMessage(l10n);
    return compact ? _buildCompact(context, l10n, message) : _buildCard(context, l10n, message);
  }

  Widget _buildCard(BuildContext context, AppLocalizations l10n, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.destructive.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 32,
            color: AppColors.destructive,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ThkButton.plain(
                label: l10n.llmErrorCancel,
                onPressed: onCancel,
              ),
              const SizedBox(width: 12),
              ThkButton.filled(
                label: l10n.llmErrorRetry,
                onPressed: onRetry,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context, AppLocalizations l10n, String message) {
    return Container(
      width: double.infinity,
      color: AppColors.destructive.withValues(alpha: 0.1),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 14,
                color: AppColors.destructive,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: AppColors.destructive,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                onPressed: onCancel,
                child: Text(
                  l10n.llmErrorCancel,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: AppColors.destructive,
                minimumSize: Size.zero,
                onPressed: onRetry,
                child: Text(
                  l10n.llmErrorRetry,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
