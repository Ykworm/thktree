import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' show SelectionArea;
import 'package:thk_tree/ui/core/shared/selection_state.dart';
import 'package:thk_tree/ui/core/shared/clips_context_menu.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:thk_tree/data/models/llm_error.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/ui/core/shared/link_launcher.dart';
import 'package:thk_tree/ui/core/shared/markdown_builders.dart';
import 'package:thk_tree/data/services/share_service.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/settings/tts_controller.dart';
import 'package:thk_tree/ui/features/settings/tts_player_screen.dart';

final _tableRowPattern = RegExp(r'^\|.*\|$');
final _tableSepPattern = RegExp(r'^\|\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|$');
final _looseTableSepPattern = RegExp(
  r'^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$',
);

/// 全角标点 → 半角映射（仅 markdown 语法相关字符）
const _fullWidthToHalf = <String, String>{
  '\uff0a': '*', // ＊
  '\uff03': '#', // ＃
  '\uff40': '`', // ｀
  '\uff1e': '>', // ＞
  '\uff0d': '-', // －
  '\uff5c': '|', // ｜
  '\uff3f': '_', // ＿
  '\uff5e': '~', // ～
  '\uff1d': '=', // ＝
};

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

String _sanitizeMarkdown(String text, {bool stripThinkTags = false}) {
  var result = text.replaceAll('\r\n', '\n');

  if (stripThinkTags) {
    result = result.replaceAll(
      RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false),
      '',
    );
    result = result.replaceAll(
      RegExp(r'<think>[\s\S]*$', caseSensitive: false),
      '',
    );
  }

  final lines = result.split('\n');
  final convertedLines = <String>[];
  var inCodeFence = false;
  for (final raw in lines) {
    final line = raw.trimRight();
    final leftTrimmed = line.trimLeft();
    if (leftTrimmed.startsWith('```')) {
      inCodeFence = !inCodeFence;
      convertedLines.add(line);
      continue;
    }
    convertedLines.add(
      inCodeFence ? line : _convertFullWidthOutsideInlineCode(line),
    );
  }

  final expandedLines = <String>[];
  inCodeFence = false;
  for (final line in convertedLines) {
    final leftTrimmed = line.trimLeft();
    if (leftTrimmed.startsWith('```')) {
      inCodeFence = !inCodeFence;
      expandedLines.add(line);
      continue;
    }
    if (!inCodeFence && _shouldSplitDoublePipe(line)) {
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
          final alignments = _parseColumnAlignments(sep, cols);
          normalizedLines.add(normalizedHeader);
          normalizedLines.add(_buildSeparatorRow(cols, alignments));
          i++;

          while (i + 1 < expandedLines.length) {
            final candidate = expandedLines[i + 1].trimRight();
            if (candidate.trim().isEmpty) break;
            final candidateLeft = candidate.trimLeft();
            if (candidateLeft.startsWith('```')) break;
            if (!candidate.contains('|')) break;
            // 跳过额外的 separator 行（LLM 可能在数据行之间或末尾重复输出）
            if (_looseTableSepPattern.hasMatch(candidate.trim())) {
              i++;
              continue;
            }

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

/// 在行内 code span（反引号对）外部执行全角→半角转换。
/// code span 内部的字符保持原样，避免误伤代码字面量。
String _convertFullWidthOutsideInlineCode(String line) {
  final buf = StringBuffer();
  var inInlineCode = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '`') {
      inInlineCode = !inInlineCode;
      buf.write(ch);
      continue;
    }
    if (inInlineCode) {
      buf.write(ch);
    } else {
      buf.write(_fullWidthToHalf[ch] ?? ch);
    }
  }
  return buf.toString();
}

/// 判断一行是否需要做 `||` → `|\\n|` 拆分。
/// 只有当 `||` 分割后的某个片段本身是合法的表格分隔行时才拆分，
/// 避免误伤普通文本中同时出现 `|`、`-`、`||` 的情况。
bool _shouldSplitDoublePipe(String line) {
  if (!line.contains('||')) return false;
  final segments = line.split('||');
  return segments.any((seg) => _looseTableSepPattern.hasMatch(seg.trim()));
}

/// 解析表格分隔行中每一列的对齐方式（`:` 位置）。
/// 返回长度为 [colCount] 的列表，每列为 'left' / 'center' / 'right'。
List<String> _parseColumnAlignments(String sepRow, int colCount) {
  final trimmed = sepRow.trim();
  var body = trimmed;
  if (body.startsWith('|')) body = body.substring(1);
  if (body.endsWith('|')) body = body.substring(0, body.length - 1);

  final cells = body.split('|').map((s) => s.trim()).toList();
  final alignments = List<String>.filled(colCount, 'left');
  for (var i = 0; i < colCount && i < cells.length; i++) {
    final cell = cells[i];
    final leftColon = cell.startsWith(':');
    final rightColon = cell.endsWith(':');
    if (leftColon && rightColon) {
      alignments[i] = 'center';
    } else if (rightColon) {
      alignments[i] = 'right';
    } else {
      alignments[i] = 'left';
    }
  }
  return alignments;
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

String _buildSeparatorRow(int columnCount, List<String> alignments) {
  final cells = List<String>.generate(columnCount, (i) {
    final align = i < alignments.length ? alignments[i] : 'left';
    return switch (align) {
      'center' => ':---:',
      'right' => '---:',
      _ => '---',
    };
  });
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
    final normalized = normalizeTableCellText(field.data).replaceAll('\n', '<br>');
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
/// 格式：`2025-06-28 14:32:05`
String formatMessageTime(String timestampUtcIso8601) {
  final utc = DateTime.tryParse(timestampUtcIso8601);
  if (utc == null) return '';
  final local = utc.toLocal();
  final y = local.year;
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  final s = local.second.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min:$s';
}

class MessageBubble extends ConsumerStatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.userQuestion,
    this.userQuestionImage,
    this.onSaveToNote,
    this.showTimestamp = false,
    this.onShareEntireChat,
  });

  final SessionMessage message;
  final VoidCallback? onRetry;

  /// 配对的用户提问（可选，用于分享图片）
  final String? userQuestion;

  /// 配对的用户提问中的图片数据（可选，用于分享图片）
  final Uint8List? userQuestionImage;

  /// 点击"存为笔记"按钮时的回调
  final VoidCallback? onSaveToNote;

  /// 是否在气泡上方显示时间戳
  final bool showTimestamp;

  /// 分享整个聊天的回调
  final VoidCallback? onShareEntireChat;

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

  void _showShareSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('分享'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _shareAsImage();
            },
            child: Text('分享当前对话'),
          ),
          if (widget.onShareEntireChat != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                widget.onShareEntireChat!();
              },
              child: Text('分享整个聊天'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('取消'),
        ),
      ),
    );
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

      // 如果用户选中了文本，只对选中文本生成图片
      final selected = ref.read(currentSelectionProvider);
      final answer = (selected != null && selected.trim().isNotEmpty)
          ? selected
          : widget.message.body;

      final shareMessages = <ShareMessage>[];
      final hasUser = (widget.userQuestion != null &&
              widget.userQuestion!.trim().isNotEmpty) ||
          widget.userQuestionImage != null;
      if (hasUser) {
        shareMessages.add(
          ShareMessage(
            role: SessionRole.user,
            text: widget.userQuestion ?? '',
            image: widget.userQuestionImage,
          ),
        );
      }
      shareMessages.add(
        ShareMessage(role: SessionRole.assistant, text: answer),
      );

      await ShareService.shareAsImage(
        context: context,
        messages: shareMessages,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(context: context, message: 'Share failed: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// 按平台决定是否包裹 SelectionArea。
  /// Android: 直接返回 child（SelectionArea 跟 Scrollable 冲突导致手势异常）。
  /// iOS/macOS: 包裹 SelectionArea 保留文本选择 + 上下文菜单。
  Widget _buildSelectionAware({required Widget child}) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return child;
    }
    return SelectionArea(
      onSelectionChanged: (v) => syncSelection(context, v),
      contextMenuBuilder: (context, editableTextState) =>
          buildClipsContextMenu(context, editableTextState),
      child: child,
    );
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

    // 解析模型显示名（仅 assistant 消息）
    String? modelDisplayName;
    final modelId = widget.message.modelId;
    if (modelId != null && !isUser) {
      final providers = ref.watch(llmProvidersProvider).value;
      if (providers != null) {
        for (final p in providers) {
          for (final m in p.models) {
            if (m.id == modelId) {
              modelDisplayName = m.name;
              break;
            }
          }
          if (modelDisplayName != null) break;
        }
        // 兜底：找不到时直接显示 modelId
        modelDisplayName ??= modelId;
      }
    }

    // 组装标题：助手 · gpt-4o · streaming
    final titleParts = <String>[title];
    if (modelDisplayName != null) titleParts.add(modelDisplayName);
    if (statusText != null) titleParts.add(statusText);
    final displayTitle = titleParts.join(' · ');

    final backgroundColor = isUser
        ? AppColors.accentLight
        : AppColors.surface;

    final body = widget.message.body.isEmpty ? ' ' : widget.message.body;
    final sanitizedBody = body;
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
                  borderRadius: BorderRadius.circular(AppSp.chatBubbleRadius),
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
                              displayTitle,
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
                            // 图片渲染（如果有）
                            if (widget.message.imageData != null) ...[
                              _MessageImage(
                                imageData: widget.message.imageData!,
                                onTap: () => _showFullImage(context),
                              ),
                              if (widget.message.body.trim().isNotEmpty ||
                                  (reasoning != null && reasoning.isNotEmpty))
                                const SizedBox(height: 8),
                            ],
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
                              _buildSelectionAware(
                                child: GptMarkdown(
                                  sanitizedBody,
                                  style: baseStyle,
                                  onLinkTap: (url, _) =>
                                      openMarkdownLink(context, url),
                                  tableBuilder: (ctx, rows, style, cfg) {
                                    final tableMarkdown = _tableRowsToMarkdown(rows);
                                    return _TableWithActions(
                                      tableRows: rows,
                                      textStyle: style,
                                      onCopy: () => _copyTextToClipboard(tableMarkdown),
                                      onExpand: () => _showExpanded(ctx, tableMarkdown),
                                    );
                                  },
                                  codeBuilder: buildCodeBlock,
                                  latexBuilder: buildLatex,
                                  useDollarSignsForLatex: true,
                                ),
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
                                    ? AppColors.success
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
                              onPressed: _sharing ? null : _showShareSheet,
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
                                  color: AppColors.destructive,
                                  onPressed: widget.onRetry,
                                  child: Text(
                                    l10n.retry,
                                    style: TextStyle(fontSize: 14, color: AppColors.white),
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

  void _showFullImage(BuildContext context) {
    if (widget.message.imageData == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => _ImageFullScreen(imageData: widget.message.imageData!),
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
    final sanitizedReasoning = _sanitizeMarkdown(reasoning, stripThinkTags: true);
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
            defaultTargetPlatform == TargetPlatform.android
                ? GptMarkdown(
                    sanitizedReasoning,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                    onLinkTap: (url, _) => openMarkdownLink(context, url),
                    tableBuilder: (ctx, rows, style, cfg) {
                      final tableMarkdown = _tableRowsToMarkdown(rows);
                      return _TableWithActions(
                        tableRows: rows,
                        textStyle: style,
                        onCopy: () => _copyTextToClipboard(tableMarkdown),
                        onExpand: () => onExpandTable(ctx, tableMarkdown),
                      );
                    },
                    codeBuilder: buildCodeBlock,
                    latexBuilder: buildLatex,
                    useDollarSignsForLatex: true,
                  )
                : SelectionArea(
                    onSelectionChanged: (v) => syncSelection(context, v),
                    contextMenuBuilder: (context, editableTextState) =>
                        buildClipsContextMenu(context, editableTextState),
                    child: GptMarkdown(
                      sanitizedReasoning,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                      onLinkTap: (url, _) => openMarkdownLink(context, url),
                      tableBuilder: (ctx, rows, style, cfg) {
                        final tableMarkdown = _tableRowsToMarkdown(rows);
                        return _TableWithActions(
                          tableRows: rows,
                          textStyle: style,
                          onCopy: () => _copyTextToClipboard(tableMarkdown),
                          onExpand: () => onExpandTable(ctx, tableMarkdown),
                        );
                      },
                      codeBuilder: buildCodeBlock,
                      latexBuilder: buildLatex,
                      useDollarSignsForLatex: true,
                    ),
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
        final columnWidth = resolveTableColumnWidth(
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
              MarkdownTableView(
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
            _sanitizeMarkdown(content, stripThinkTags: true),
            style: baseStyle,
            onLinkTap: (url, _) => openMarkdownLink(context, url),
            codeBuilder: buildCodeBlock,
            tableBuilder: (
              context,
              tableRows,
              textStyle,
              config,
            ) {
              return MarkdownTableView(
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
            ? AppColors.accent
            : AppColors.textSecondary,
      ),
    );
  }
}

/// 消息中的图片缩略图
class _MessageImage extends StatelessWidget {
  const _MessageImage({
    required this.imageData,
    required this.onTap,
  });

  final Uint8List imageData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          imageData,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// 全屏图片查看器
class _ImageFullScreen extends StatelessWidget {
  const _ImageFullScreen({required this.imageData});

  final Uint8List imageData;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.black,
        middle: Text(
          '图片预览',
          style: TextStyle(color: AppColors.white),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Icon(
            CupertinoIcons.back,
            color: AppColors.white,
          ),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: InteractiveViewer(
            child: Image.memory(imageData),
          ),
        ),
      ),
    );
  }
}

