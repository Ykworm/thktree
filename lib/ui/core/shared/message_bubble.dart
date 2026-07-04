import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText, SelectionArea;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:thk_tree/data/models/llm_error.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/ui/core/shared/markdown_builders.dart';
import 'package:thk_tree/data/services/share_service.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/settings/tts_controller.dart';
import 'package:thk_tree/ui/features/settings/tts_player_screen.dart';

final _tableRowPattern = RegExp(r'^\|.*\|$');
final _tableSepPattern = RegExp(r'^\|\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|$');
final _looseTableSepPattern = RegExp(
  r'^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$',
);
final _htmlBreakPattern = RegExp(r'<br\s*/?>', caseSensitive: false);

bool _hasMarkdownTable(String text) {
  final lines = text.split('\n');
  for (var i = 0; i < lines.length - 1; i++) {
    final header = lines[i].trim();
    final sep = lines[i + 1].trim();
    if (_tableRowPattern.hasMatch(header) && _tableSepPattern.hasMatch(sep)) {
      return true;
    }
  }
  return false;
}

String _sanitizeMarkdown(String text) {
  var result = text.replaceAll('\r\n', '\n');
  result = result.replaceAll(
    RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false),
    '',
  );
  result = result.replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '');
  result = result.replaceAll('\uff0a', '*').replaceAll('\uff03', '#');

  final lines = result.split('\n');
  final expandedLines = <String>[];
  var inCodeFence = false;
  for (final raw in lines) {
    final line = raw.trimRight();
    final leftTrimmed = line.trimLeft();
    if (leftTrimmed.startsWith('```')) {
      inCodeFence = !inCodeFence;
      expandedLines.add(line);
      continue;
    }
    if (!inCodeFence &&
        line.contains('||') &&
        line.contains('|') &&
        line.contains('-')) {
      expandedLines.addAll(line.replaceAll('||', '|\n|').split('\n'));
      continue;
    }
    expandedLines.add(line);
  }

  final normalizedLines = <String>[];
  inCodeFence = false;
  for (var i = 0; i < expandedLines.length; i++) {
    final line = expandedLines[i].trimRight();
    final leftTrimmed = line.trimLeft();
    if (leftTrimmed.startsWith('```')) {
      inCodeFence = !inCodeFence;
      normalizedLines.add(line);
      continue;
    }

    if (!inCodeFence && i < expandedLines.length - 1) {
      final sep = expandedLines[i + 1].trim();
      final hasSep = _looseTableSepPattern.hasMatch(sep);
      final pipeCount = line.split('|').length - 1;
      if (hasSep && pipeCount >= 2) {
        final (prefix, headerRow) = _splitLeadingTextAndRow(line);
        if (prefix.isNotEmpty) normalizedLines.add(prefix);
        final normalizedHeader = _ensureRowPipes(headerRow);
        final cols = _countColumns(normalizedHeader);
        if (cols >= 2) {
          normalizedLines.add(normalizedHeader);
          normalizedLines.add(_buildSeparatorRow(cols));
          i++;

          while (i + 1 < expandedLines.length) {
            final candidate = expandedLines[i + 1].trimRight();
            if (candidate.trim().isEmpty) break;
            final candidateLeft = candidate.trimLeft();
            if (candidateLeft.startsWith('```')) break;
            if (!candidate.contains('|')) break;

            final (rowPrefix, rowBody) = _splitLeadingTextAndRow(candidate);
            if (rowPrefix.isNotEmpty) normalizedLines.add(rowPrefix);
            normalizedLines.add(_ensureRowPipes(rowBody));
            i++;
          }
          continue;
        }
      }
    }

    normalizedLines.add(line);
  }

  final cleaned = <String>[];
  for (var i = 0; i < normalizedLines.length; i++) {
    final cur = normalizedLines[i].trimRight();
    if (cur.isEmpty && i > 0 && i < normalizedLines.length - 1) {
      final prev = normalizedLines[i - 1].trim();
      final next = normalizedLines[i + 1].trim();
      final prevIsTable = _tableRowPattern.hasMatch(prev) || _tableSepPattern.hasMatch(prev);
      final nextIsTable = _tableRowPattern.hasMatch(next) || _tableSepPattern.hasMatch(next);
      if (prevIsTable && nextIsTable) continue;
    }
    cleaned.add(cur);
  }

  return cleaned.join('\n');
}

(String, String) _splitLeadingTextAndRow(String line) {
  final idx = line.indexOf('|');
  if (idx <= 0) return ('', line);
  final prefix = line.substring(0, idx).trimRight();
  final row = line.substring(idx).trim();
  return (prefix, row);
}

String _ensureRowPipes(String row) {
  var r = row.trim();
  if (!r.startsWith('|')) r = '|$r';
  if (!r.endsWith('|')) r = '$r|';
  return r;
}

int _countColumns(String row) {
  final parts = row.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  return parts.length;
}

String _buildSeparatorRow(int columnCount) {
  final cells = List.filled(columnCount, '---');
  return '|${cells.join('|')}|';
}

Future<void> _copyTextToClipboard(String content) async {
  if (content.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: content));
}

String _tableRowsToMarkdown(List<CustomTableRow> tableRows) {
  if (tableRows.isEmpty) return '';
  final header = tableRows.first.fields;
  final lines = <String>[
    _tableFieldsToMarkdownRow(header),
    _tableFieldsToSeparatorRow(header),
    ...tableRows.skip(1).map((row) => _tableFieldsToMarkdownRow(row.fields)),
  ];
  return lines.join('\n');
}

String _tableFieldsToMarkdownRow(List<CustomTableField> fields) {
  final cells = fields.map((field) {
    final normalized = _normalizeTableCellText(field.data).replaceAll('\n', '<br>');
    return _escapeMarkdownTableCell(normalized);
  }).toList();
  return '| ${cells.join(' | ')} |';
}

String _tableFieldsToSeparatorRow(List<CustomTableField> fields) {
  final cells = fields.map((field) {
    return switch (field.alignment) {
      TextAlign.right => '---:',
      TextAlign.center => ':---:',
      _ => ':---',
    };
  }).toList();
  return '| ${cells.join(' | ')} |';
}

String _escapeMarkdownTableCell(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('|', r'\|');
}

/// 将 ISO 8601 UTC 时间戳格式化为人类可读的本地时间。
///
/// - 今天：`14:32`
/// - 昨天：`昨天 14:32`
/// - 今年内：`6月28日 14:32`
/// - 跨年：`2025年6月28日 14:32`
String formatMessageTime(String timestampUtcIso8601) {
  final utc = DateTime.tryParse(timestampUtcIso8601);
  if (utc == null) return '';
  final local = utc.toLocal();
  final now = DateTime.now();
  final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

  final today = DateTime(now.year, now.month, now.day);
  final targetDay = DateTime(local.year, local.month, local.day);
  final diff = today.difference(targetDay).inDays;

  if (diff == 0) return time;
  if (diff == 1) return '昨天 $time';
  if (local.year == now.year) {
    return '${local.month}月${local.day}日 $time';
  }
  return '${local.year}年${local.month}月${local.day}日 $time';
}

class MessageBubble extends ConsumerStatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.userQuestion,
    this.onSaveToNote,
    this.showTimestamp = false,
  });

  final SessionMessage message;
  final VoidCallback? onRetry;

  /// 配对的用户提问（可选，用于分享图片）
  final String? userQuestion;

  /// 点击"存为笔记"按钮时的回调
  final VoidCallback? onSaveToNote;

  /// 是否在气泡上方显示时间戳
  final bool showTimestamp;

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  bool _copied = false;
  bool _sharing = false;
  bool _showReasoning = false;
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
    final sanitizedBody = _sanitizeMarkdown(body);
    final reasoning = widget.message.reasoning?.trim();
    final shouldExpandReasoning =
        _showReasoning || (reasoning != null && reasoning.isNotEmpty && widget.message.body.trim().isEmpty);
    final hasTable = _hasMarkdownTable(sanitizedBody);
    final maxWidth = hasTable
        ? MediaQuery.of(context).size.width - 32
        : 520.0;

    final baseStyle = TextStyle(
      fontSize: 17,
      color: AppColors.textPrimary,
    );

    final timestampText = widget.showTimestamp
        ? formatMessageTime(widget.message.timestampUtcIso8601)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (timestampText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                timestampText,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          Align(
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
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (widget.message.status == SessionMessageStatus.error)
                        LlmErrorCard(
                          key: const ValueKey('llm_error_card_compact'),
                          compact: true,
                          error: LlmError(
                            kind: llmErrorKindFromCodeName(
                              widget.message.errorCode ?? '',
                            ),
                          ),
                          onRetry: widget.onRetry ?? () {},
                          onCancel: () {},
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (reasoning != null && reasoning.isNotEmpty)
                              _ReasoningSection(
                                reasoning: reasoning,
                                isExpanded: shouldExpandReasoning,
                                onToggle: () =>
                                    setState(() => _showReasoning = !_showReasoning),
                                onExpandTable: _showExpanded,
                              ),
                            if (reasoning != null &&
                                reasoning.isNotEmpty &&
                                widget.message.body.trim().isNotEmpty)
                              const SizedBox(height: 8),
                            if (widget.message.body.trim().isNotEmpty)
                              GptMarkdown(
                                sanitizedBody,
                                style: baseStyle,
                                tableBuilder: (ctx, rows, style, cfg) {
                                  final tableMarkdown = _tableRowsToMarkdown(rows);
                                  return _TableWithActions(
                                    tableRows: rows,
                                    textStyle: style,
                                    onCopy: () => _copyTextToClipboard(tableMarkdown),
                                    onExpand: () => _showExpanded(ctx, tableMarkdown),
                                  );
                                },
                                codeBuilder: _buildCodeBlock,
                                latexBuilder: buildLatex,
                                useDollarSignsForLatex: true,
                              ),
                          ],
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
                            _TtsPlayButton(
                              messageId: widget.message.msgId,
                              body: widget.message.body,
                              text: widget.message.body,
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
                            if (widget.onSaveToNote != null) ...[
                              const SizedBox(width: 12),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                onPressed: widget.onSaveToNote,
                                child: Icon(
                                  AppIcons.note,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (widget.onRetry != null) ...[
                              const SizedBox(width: 12),
                              if (widget.message.status == SessionMessageStatus.error)
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  color: CupertinoColors.systemRed,
                                  onPressed: widget.onRetry,
                                  child: Text(
                                    l10n.retry,
                                    style: TextStyle(fontSize: 14, color: CupertinoColors.white),
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
          ),
        ],
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

class _ReasoningSection extends StatelessWidget {
  const _ReasoningSection({
    required this.reasoning,
    required this.isExpanded,
    required this.onToggle,
    required this.onExpandTable,
  });

  final String reasoning;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(BuildContext, String) onExpandTable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sanitizedReasoning = _sanitizeMarkdown(reasoning);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.reasoningTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onToggle,
                child: Text(
                  isExpanded ? l10n.hideReasoning : l10n.showReasoning,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 8),
            GptMarkdown(
              sanitizedReasoning,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
              tableBuilder: (ctx, rows, style, cfg) {
                final tableMarkdown = _tableRowsToMarkdown(rows);
                return _TableWithActions(
                  tableRows: rows,
                  textStyle: style,
                  onCopy: () => _copyTextToClipboard(tableMarkdown),
                  onExpand: () => onExpandTable(ctx, tableMarkdown),
                );
              },
              codeBuilder: _buildCodeBlock,
              latexBuilder: buildLatex,
              useDollarSignsForLatex: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _TableWithActions extends StatelessWidget {
  const _TableWithActions({
    required this.tableRows,
    required this.textStyle,
    required this.onCopy,
    required this.onExpand,
  });

  final List<CustomTableRow> tableRows;
  final TextStyle textStyle;
  final VoidCallback onCopy;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 48;

        final columnCount = tableRows.fold<int>(
          0,
          (max, row) => math.max(max, row.fields.length),
        );
        final columnWidth = _resolveTableColumnWidth(
          availableWidth: availableWidth,
          columnCount: columnCount,
          expanded: false,
        );
        final tableWidth = columnWidth * columnCount;

        final barWidth = tableWidth + 10 < availableWidth
            ? tableWidth
            : availableWidth;

        return SizedBox(
          width: availableWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: barWidth,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      onPressed: onCopy,
                      child: Icon(
                        CupertinoIcons.doc_on_doc,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 4),
                    CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      onPressed: onExpand,
                      child: Icon(
                        CupertinoIcons.arrow_up_left_arrow_down_right,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              _MarkdownTableView(
                tableRows: tableRows,
                textStyle: textStyle,
              ),
            ],
          ),
        );
      },
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
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
      ),
    ),
  );
}

class _TableExpandedView extends StatelessWidget {
  const _TableExpandedView({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 17,
      color: AppColors.textPrimary,
    );

    return CupertinoPageScaffold(
      navigationBar: ThkNavBar.inline(
        title: AppLocalizations.of(context)!.expandTable,
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GptMarkdown(
            _sanitizeMarkdown(content),
            style: baseStyle,
            codeBuilder: _buildCodeBlock,
            tableBuilder: (
              context,
              tableRows,
              textStyle,
              config,
            ) {
              return _MarkdownTableView(
                tableRows: tableRows,
                textStyle: textStyle,
                expanded: true,
              );
            },
            latexBuilder: buildLatex,
            useDollarSignsForLatex: true,
          ),
        ),
      ),
    );
  }
}

class _MarkdownTableView extends StatelessWidget {
  const _MarkdownTableView({
    required this.tableRows,
    required this.textStyle,
    this.expanded = false,
  });

  final List<CustomTableRow> tableRows;
  final TextStyle textStyle;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final columnCount = tableRows.fold<int>(
      0,
      (maxColumns, row) => math.max(maxColumns, row.fields.length),
    );
    if (columnCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = MediaQuery.of(context).size.width - 48;
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : fallbackWidth;
        final columnWidth = _resolveTableColumnWidth(
          availableWidth: availableWidth,
          columnCount: columnCount,
          expanded: expanded,
        );

        return SelectionArea(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(
                color: AppColors.border,
                width: 1,
              ),
              defaultColumnWidth: FixedColumnWidth(columnWidth),
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              children: tableRows.map((row) {
                return TableRow(
                  decoration: row.isHeader
                      ? BoxDecoration(color: AppColors.surfaceMuted)
                      : null,
                  children: row.fields.map((cell) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: SelectableText(
                        _normalizeTableCellText(cell.data),
                        style: row.isHeader
                            ? textStyle.copyWith(fontWeight: FontWeight.w600)
                            : textStyle,
                        textAlign: cell.alignment,
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

double _resolveTableColumnWidth({
  required double availableWidth,
  required int columnCount,
  required bool expanded,
}) {
  const cellHorizontalPadding = 16.0;
  final minColumnWidth = expanded ? 180.0 : 120.0;
  final maxColumnWidth = expanded ? 420.0 : 280.0;
  final usableWidth = math.max(
    minColumnWidth,
    availableWidth - (columnCount * cellHorizontalPadding),
  );
  final targetWidth = usableWidth / columnCount;
  return targetWidth.clamp(minColumnWidth, maxColumnWidth).toDouble();
}

String _normalizeTableCellText(String value) {
  return value.replaceAll(_htmlBreakPattern, '\n').trim();
}


/// MessageBubble 上的"播放"按钮。assistant 消息可见，streaming 时隐藏。
/// 点击后 push [TtsPlayerScreen] 跳到全屏播放器。
class _TtsPlayButton extends ConsumerWidget {
  const _TtsPlayButton({
    required this.messageId,
    required this.body,
    required this.text,
  });

  final String messageId;
  final String body;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isThisPlaying = ref.watch(
      ttsControllerProvider.select((s) =>
          s.isSpeaking && s.playingMessageId == messageId),
    );

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: body.isEmpty
          ? null
          : () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => TtsPlayerScreen(
                    messageId: messageId,
                    text: text,
                  ),
                ),
              );
            },
      child: Icon(
        isThisPlaying ? AppIcons.ttsPause : AppIcons.ttsSpeak,
        size: 18,
        color: isThisPlaying
            ? CupertinoColors.systemBlue
            : AppColors.textSecondary,
      ),
    );
  }
}
