import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/share_service.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';

final _tablePattern = RegExp(r'^\|.+\|', multiLine: true);
final _tableSepPattern = RegExp(r'^\|[\s\-:]+\|', multiLine: true);

bool _hasMarkdownTable(String text) {
  final lines = text.split('\n');
  for (var i = 0; i < lines.length - 1; i++) {
    if (_tablePattern.hasMatch(lines[i]) && _tableSepPattern.hasMatch(lines[i + 1])) {
      return true;
    }
  }
  return false;
}

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.userQuestion,
  });

  final SessionMessage message;
  final VoidCallback? onRetry;

  /// 配对的用户提问（可选，用于分享图片）
  final String? userQuestion;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _copied = false;
  bool _sharing = false;
  final _shareButtonKey = GlobalKey();

  Future<void> _copyToClipboard() async {
    if (widget.message.body.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: widget.message.body));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  Future<void> _shareAsImage() async {
    if (_sharing || widget.message.body.isEmpty) return;
    setState(() => _sharing = true);
    try {
      Rect? origin;
      final renderBox = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final offset = renderBox.localToGlobal(Offset.zero);
        origin = offset & renderBox.size;
      }

      await ShareService.shareAsImage(
        context: context,
        userQuestion: widget.userQuestion,
        assistantAnswer: widget.message.body,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(context: context, message: 'Share failed: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isUser = widget.message.role == SessionRole.user;

    final title = switch (widget.message.role) {
      SessionRole.user => l10n.userRole,
      SessionRole.assistant => l10n.assistantRole,
      SessionRole.system => l10n.systemRole,
    };

    final statusText = switch (widget.message.status) {
      SessionMessageStatus.done => null,
      SessionMessageStatus.streaming => l10n.streamingStatus,
      SessionMessageStatus.error =>
        l10n.errorStatus(widget.message.errorCode ?? l10n.errorUnknown),
    };

    final backgroundColor = isUser
        ? AppColors.accentLight
        : AppColors.surface;

    final body = widget.message.body.isEmpty ? ' ' : widget.message.body;
    final hasTable = _hasMarkdownTable(widget.message.body);
    final maxWidth = hasTable
        ? MediaQuery.of(context).size.width - 32
        : 520.0;

    final baseStyle = TextStyle(
      fontSize: 17,
      color: AppColors.textPrimary,
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        statusText == null ? title : '$title · $statusText',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (hasTable)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () => _showExpanded(context, body),
                        child: Icon(
                          CupertinoIcons.arrow_up_left_arrow_down_right,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                GptMarkdown(
                  body,
                  style: baseStyle,
                  tableBuilder: _buildTable,
                  codeBuilder: _buildCodeBlock,
                ),
                if (widget.message.role == SessionRole.assistant &&
                    widget.message.status != SessionMessageStatus.streaming) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: _copyToClipboard,
                        child: Icon(
                          _copied ? AppIcons.checkCircle : AppIcons.copy,
                          size: 18,
                          color: _copied
                              ? CupertinoColors.systemGreen
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      CupertinoButton(
                        key: _shareButtonKey,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: _sharing ? null : _shareAsImage,
                        child: _sharing
                            ? const CupertinoActivityIndicator(radius: 8)
                            : Icon(
                                AppIcons.share,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                      ),
                      if (widget.onRetry != null) ...[
                        const SizedBox(width: 12),
                        if (widget.message.status == SessionMessageStatus.error)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: CupertinoColors.systemRed,
                            onPressed: widget.onRetry,
                            child: Text(
                              l10n.retry,
                              style: const TextStyle(fontSize: 14, color: CupertinoColors.white),
                            ),
                          )
                        else
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: widget.onRetry,
                            child: Icon(
                              CupertinoIcons.arrow_counterclockwise,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExpanded(BuildContext context, String content) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => _TableExpandedView(content: content),
      ),
    );
  }
}

Widget _buildCodeBlock(
  BuildContext context,
  String name,
  String code,
  bool closed,
) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
    ),
    child: SelectableText(
      code,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
      ),
    ),
  );
}

Widget _buildTable(
  BuildContext context,
  List<CustomTableRow> tableRows,
  TextStyle textStyle,
  GptMarkdownConfig config,
) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Table(
      border: TableBorder.all(
        color: AppColors.border,
        width: 1,
      ),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: tableRows.map((row) {
        return TableRow(
          children: row.fields.map((cell) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                cell.data,
                style: textStyle,
                textAlign: cell.alignment,
              ),
            );
          }).toList(),
        );
      }).toList(),
    ),
  );
}

class _TableExpandedView extends StatelessWidget {
  const _TableExpandedView({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: ThkNavBar.inline(
        title: AppLocalizations.of(context)!.expandTable,
      ),
      child: SafeArea(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          boundaryMargin: const EdgeInsets.all(40),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.all(16),
            child: GptMarkdown(
              content,
              style: const TextStyle(fontSize: 17, height: 1.6),
              codeBuilder: _buildCodeBlock,
              tableBuilder: _buildTable,
            ),
          ),
        ),
      ),
    );
  }
}
