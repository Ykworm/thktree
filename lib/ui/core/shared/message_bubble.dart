import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
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

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
  });

  final SessionMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isUser = message.role == SessionRole.user;

    final title = switch (message.role) {
      SessionRole.user => l10n.userRole,
      SessionRole.assistant => l10n.assistantRole,
      SessionRole.system => l10n.systemRole,
    };

    final statusText = switch (message.status) {
      SessionMessageStatus.done => null,
      SessionMessageStatus.streaming => l10n.streamingStatus,
      SessionMessageStatus.error =>
        l10n.errorStatus(message.errorCode ?? l10n.errorUnknown),
    };

    final backgroundColor = isUser
        ? CupertinoColors.systemGrey6.resolveFrom(context).withValues(alpha: 0.5)
        : CupertinoColors.white;

    final body = message.body.isEmpty ? ' ' : message.body;
    final hasTable = _hasMarkdownTable(message.body);
    final maxWidth = hasTable
        ? MediaQuery.of(context).size.width - 32
        : 520.0;

    final baseStyle = TextStyle(
      fontSize: 17,
      color: CupertinoColors.label.resolveFrom(context),
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
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
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
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
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

  static Widget _buildCodeBlock(
    BuildContext context,
    String name,
    String code,
    bool closed,
  ) {
    final codeBg = CupertinoColors.systemGrey5.resolveFrom(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: codeBg,
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

  static Widget _buildTable(
    BuildContext context,
    List<CustomTableRow> tableRows,
    TextStyle textStyle,
    GptMarkdownConfig config,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(
          color: CupertinoColors.separator.resolveFrom(context),
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
              codeBuilder: MessageBubble._buildCodeBlock,
              tableBuilder: MessageBubble._buildTable,
            ),
          ),
        ),
      ),
    );
  }
}
