import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/shared/message_bubble.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';

/// 聊天内搜索 — 在当前对话的所有消息中搜索文本，点击结果跳转。
///
/// 返回选中的 [SessionMessage]，由调用方 dismiss sheet 并 scrollToMessage。
Future<SessionMessage?> showChatSearchSheet(
  BuildContext context,
  List<SessionMessage> messages,
) {
  return showCupertinoModalPopup<SessionMessage>(
    context: context,
    builder: (_) => _ChatSearchPage(messages: messages),
  );
}

class _ChatSearchPage extends StatefulWidget {
  const _ChatSearchPage({required this.messages});

  final List<SessionMessage> messages;

  @override
  State<_ChatSearchPage> createState() => _ChatSearchPageState();
}

class _ChatSearchPageState extends State<_ChatSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<_SearchResult> _results = [];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final lowerQuery = query.toLowerCase();
    final results = <_SearchResult>[];
    for (var i = 0; i < widget.messages.length; i++) {
      final msg = widget.messages[i];
      if (msg.body.toLowerCase().contains(lowerQuery)) {
        results.add(_SearchResult(
          message: msg,
          indexInAll: i,
          snippet: _extractSnippet(msg.body, lowerQuery),
        ));
      }
    }
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSp.sheetTopRadius)),
      ),
      child: Column(
        children: [
          // 拖拽指示条
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          CupertinoNavigationBar(
            middle: Text(l10n.chatSearch),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: CupertinoSearchTextField(
              controller: _controller,
              focusNode: _focusNode,
              placeholder: l10n.searchInChat,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          if (_controller.text.isNotEmpty && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                l10n.noSearchResults,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  final time = formatMessageTime(
                    result.message.timestampUtcIso8601,
                  );
                  final roleLabel = result.message.role == SessionRole.user
                      ? l10n.userRole
                      : l10n.assistantRole;
                  return CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        Navigator.of(context).pop(result.message),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                AppColors.border.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$roleLabel · $time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _HighlightText(
                            text: result.snippet,
                            query: _controller.text,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 从 body 中提取 query 前后各 40 字的片段。
String _extractSnippet(String body, String query) {
  final lowerBody = body.toLowerCase();
  final idx = lowerBody.indexOf(query);
  if (idx < 0) return body.substring(0, math.min(body.length, 80));

  final start = math.max(0, idx - 40);
  final end = math.min(body.length, idx + query.length + 40);
  var snippet = body.substring(start, end);
  if (start > 0) snippet = '…$snippet';
  if (end < body.length) snippet = '$snippet…';
  return snippet;
}

/// 高亮显示搜索关键词的文本组件。
class _HighlightText extends StatelessWidget {
  const _HighlightText({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx < 0) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
        ));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(
          text: text.substring(start, idx),
          style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          fontSize: 15,
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
      ));
      start = idx + query.length;
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }
}

class _SearchResult {
  const _SearchResult({
    required this.message,
    required this.indexInAll,
    required this.snippet,
  });

  final SessionMessage message;
  final int indexInAll;
  final String snippet;
}
