import 'package:flutter/cupertino.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/ui/core/shared/link_launcher.dart';
import 'package:thk_tree/ui/core/shared/markdown_builders.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';

/// 分享卡片 Widget —— 用于截图生成图片
///
/// 用 [RepaintBoundary] 包裹后通过 `toImage()` 截图。
/// 仅用于渲染，不展示在页面上。
class ShareCardWidget extends StatelessWidget {
  const ShareCardWidget({super.key, required this.messages, this.cardWidth});

  /// 按时间顺序排列的待分享消息（每条可携带本地图片字节）
  final List<ShareMessage> messages;

  /// 卡片固定逻辑宽。由 [ShareService] 按屏宽传入，避免屏外布局宽度不稳裁掉右半。
  final double? cardWidth;

  static const double _fallbackWidth = 360;
  static const double _padding = 20;
  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final width =
        cardWidth ?? MediaQuery.sizeOf(context).width.clamp(320.0, 420.0);
    // 兜底：极端 MediaQuery 时仍有宽度
    final w = width.isFinite && width > 0 ? width : _fallbackWidth;

    final blocks = <Widget>[];
    for (var i = 0; i < messages.length; i++) {
      blocks.add(_buildMessageBlock(context, messages[i], w - _padding * 2));
      if (i < messages.length - 1) blocks.add(const SizedBox(height: 16));
    }

    return SizedBox(
      width: w,
      child: Container(
        width: w,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [
            BoxShadow(
              color: AppColors.elevationShadow,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 品牌标识 ──
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
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

              // ── 消息列表 ──
              const SizedBox(height: 16),
              ...blocks,

              // ── 底部分隔线 ──
              const SizedBox(height: 20),
              Container(
                height: AppSp.dividerThickness,
                color: AppColors.border,
              ),
              const SizedBox(height: 12),
              Text(
                'Shared from ThkTree',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBlock(
    BuildContext context,
    ShareMessage m,
    double contentWidth,
  ) {
    if (m.role == SessionRole.user) {
      final hasText = m.text.trim().isNotEmpty;
      return Container(
        width: contentWidth,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  m.image!,
                  width: contentWidth - 24,
                  fit: BoxFit.contain,
                ),
              ),
              if (hasText) const SizedBox(height: 8),
            ],
            if (hasText)
              Text(
                m.text,
                softWrap: true,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      );
    }

    // ── 助手消息 ──
    // 钉死宽度，避免 markdown 表格/代码块横向撑破卡片导致截图右半空白或被裁。
    return SizedBox(
      width: contentWidth,
      child: GptMarkdown(
        m.text,
        style: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: AppColors.textPrimary,
        ),
        codeBuilder: buildCodeBlock,
        tableBuilder: (ctx, rows, style, cfg) =>
            MarkdownTableView(tableRows: rows, textStyle: style),
        latexBuilder: buildLatex,
        useDollarSignsForLatex: true,
        onLinkTap: (url, _) => openMarkdownLink(context, url),
      ),
    );
  }
}
