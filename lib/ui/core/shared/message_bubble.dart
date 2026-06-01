import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

String _getSelectedText(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid || selection.isCollapsed) return '';
  return selection.textInside(value.text);
}

Future<String> _copySelectedText(SelectableRegionState state) async {
  // ignore: deprecated_member_use
  final fallback = _getSelectedText(state.textEditingValue);
  if (fallback.isEmpty) return '';

  for (final item in state.contextMenuButtonItems) {
    if (item.type == ContextMenuButtonType.copy) {
      item.onPressed?.call();
      break;
    }
  }
  final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
  return clipboard?.text?.isNotEmpty == true ? clipboard!.text! : fallback;
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onAddToNote,
  });

  final SessionMessage message;
  final void Function(String selectedText)? onAddToNote;

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
      SessionMessageStatus.error => l10n.errorStatus(message.errorCode ?? l10n.errorUnknown),
    };

    final backgroundColor = isUser
        ? CupertinoColors.systemBlue.resolveFrom(context)
        : CupertinoColors.systemGrey6.resolveFrom(context);

    final body = message.body.isEmpty ? ' ' : message.body;
    final hasTable = _hasMarkdownTable(message.body);
    final maxWidth = hasTable
        ? MediaQuery.of(context).size.width - 32
        : 520.0;

    final mdStyle = _buildStyle(context);

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
            child: SelectableRegion(
              selectionControls: cupertinoTextSelectionControls,
              contextMenuBuilder: (ctx, state) {
                return CupertinoAdaptiveTextSelectionToolbar.buttonItems(
                  anchors: state.contextMenuAnchors,
                  buttonItems: _buildMenuItems(ctx, state, hasTable, body),
                );
              },
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
                            color: isUser
                                ? CupertinoColors.white.withValues(alpha: 0.8)
                                : CupertinoColors.secondaryLabel.resolveFrom(context),
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
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (hasTable)
                    SizedBox(
                      width: maxWidth - 24,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: MarkdownBody(
                          data: body,
                          styleSheet: mdStyle,
                        ),
                      ),
                    )
                  else
                    MarkdownBody(
                      data: body,
                      styleSheet: mdStyle,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<ContextMenuButtonItem> _buildMenuItems(
    BuildContext context,
    SelectableRegionState state,
    bool hasTable,
    String fullBody,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final items = <ContextMenuButtonItem>[
      ...state.contextMenuButtonItems,
    ];

    if (onAddToNote != null) {
      // ignore: deprecated_member_use
      final hasSelectedText = _getSelectedText(state.textEditingValue).isNotEmpty;
      if (hasSelectedText) {
        items.add(
          ContextMenuButtonItem(
            label: l10n.addToNote,
            onPressed: () async {
              final selectedText = await _copySelectedText(state);
              if (selectedText.trim().isEmpty) return;
              state.hideToolbar();
              onAddToNote!(selectedText);
            },
          ),
        );
      }
    }

    if (hasTable) {
      items.add(
        ContextMenuButtonItem(
          label: l10n.expandTable,
          onPressed: () {
            state.hideToolbar();
            _showExpanded(context, fullBody);
          },
        ),
      );
    }

    return items;
  }

  MarkdownStyleSheet _buildStyle(BuildContext context) {
    final isUser = message.role == SessionRole.user;
    final baseStyle = TextStyle(
      fontSize: 17,
      color: isUser
          ? CupertinoColors.white
          : CupertinoColors.label.resolveFrom(context),
    );
    final codeBg = isUser
        ? CupertinoColors.white.withValues(alpha: 0.15)
        : CupertinoColors.systemGrey5.resolveFrom(context);

    return MarkdownStyleSheet(
      p: baseStyle,
      code: baseStyle.copyWith(
        fontFamily: 'monospace',
        backgroundColor: codeBg,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(8),
      ),
      tableBorder: TableBorder.all(
        color: isUser
            ? CupertinoColors.white.withValues(alpha: 0.3)
            : CupertinoColors.separator.resolveFrom(context),
        width: 1,
      ),
      tableHead: baseStyle.copyWith(fontWeight: FontWeight.bold),
      tableBody: baseStyle,
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      tableColumnWidth: const MaxColumnWidth(FixedColumnWidth(180), FlexColumnWidth()),
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
            child: MarkdownBody(
              data: content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 17, height: 1.6),
                code: const TextStyle(
                  fontFamily: 'monospace',
                  backgroundColor: CupertinoColors.systemGrey5,
                ),
                codeblockDecoration: const BoxDecoration(
                  color: CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                tableBorder: TableBorder.all(
                  color: CupertinoColors.separator,
                  width: 1,
                ),
                tableHead: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                tableBody: const TextStyle(fontSize: 17, height: 1.5),
                tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                tableColumnWidth: const MaxColumnWidth(FixedColumnWidth(180), FlexColumnWidth()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
