import 'package:flutter/cupertino.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/shared/message_bubble.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';

/// 对话目录 — 列出所有 user message，点击跳转到对应位置。
///
/// 返回选中的 [SessionMessage]，由调用方 dismiss sheet 并 scrollToMessage。
Future<SessionMessage?> showChatOutlineSheet(
  BuildContext context,
  List<SessionMessage> messages,
) {
  return showCupertinoModalPopup<SessionMessage>(
    context: context,
    builder: (_) => _ChatOutlinePage(messages: messages),
  );
}

class _ChatOutlinePage extends StatefulWidget {
  const _ChatOutlinePage({required this.messages});

  final List<SessionMessage> messages;

  @override
  State<_ChatOutlinePage> createState() => _ChatOutlinePageState();
}

class _ChatOutlinePageState extends State<_ChatOutlinePage> {
  late final List<_OutlineItem> _items;

  @override
  void initState() {
    super.initState();
    _items = [];
    for (var i = 0; i < widget.messages.length; i++) {
      final msg = widget.messages[i];
      if (msg.role == SessionRole.user) {
        _items.add(_OutlineItem(
          message: msg,
          indexInAll: i,
          userIndex: _items.length + 1,
        ));
      }
    }
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
            middle: Text(l10n.chatOutline),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? Center(child: Text(l10n.noUserMessages))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final time = formatMessageTime(
                        item.message.timestampUtcIso8601,
                      );
                      final preview = _stripMarkdown(item.message.body);
                      return CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () =>
                            Navigator.of(context).pop(item.message),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.border
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${item.userIndex}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      preview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
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

/// 去除 Markdown 标记，取前 60 字作为预览。
String _stripMarkdown(String text) {
  return text
      .replaceAll(RegExp(r'[#*_`~\[\]()>|]'), '')
      .replaceAll(RegExp(r'\n+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

class _OutlineItem {
  const _OutlineItem({
    required this.message,
    required this.indexInAll,
    required this.userIndex,
  });

  final SessionMessage message;
  final int indexInAll;
  final int userIndex;
}
