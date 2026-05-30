import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';

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

    final color = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    final body = message.body.isEmpty ? ' ' : message.body;
    final hasTable = _hasMarkdownTable(message.body);
    final cs = Theme.of(context).colorScheme;
    final maxWidth = hasTable
        ? MediaQuery.of(context).size.width - 32
        : 520.0;

    final mdStyle = _buildStyle(context, cs);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Card(
          color: color,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectionArea(
              contextMenuBuilder: (ctx, state) {
                return AdaptiveTextSelectionToolbar.buttonItems(
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
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      if (hasTable)
                        InkWell(
                          onTap: () => _showExpanded(context, body),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(Icons.open_in_full, size: 15, color: cs.onSurfaceVariant),
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

  MarkdownStyleSheet _buildStyle(BuildContext context, ColorScheme cs) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: Theme.of(context).textTheme.bodyMedium,
      code: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: cs.surfaceContainerHighest,
      ),
      codeblockDecoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      tableBorder: TableBorder.all(color: cs.outlineVariant, width: 1),
      tableHead: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      tableBody: Theme.of(context).textTheme.bodyMedium,
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      tableColumnWidth: const MaxColumnWidth(FixedColumnWidth(180), FlexColumnWidth()),
    );
  }

  void _showExpanded(BuildContext context, String content) {
    Navigator.of(context).push(
      MaterialPageRoute(
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.expandTable)),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 3.0,
        boundaryMargin: const EdgeInsets.all(40),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.all(16),
          child: MarkdownBody(
            data: content,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: cs.surfaceContainerHighest,
              ),
              codeblockDecoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              tableBorder: TableBorder.all(
                color: cs.outlineVariant,
                width: 1,
              ),
              tableHead: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              tableBody: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tableColumnWidth: const MaxColumnWidth(FixedColumnWidth(180), FlexColumnWidth()),
            ),
          ),
        ),
      ),
    );
  }
}
