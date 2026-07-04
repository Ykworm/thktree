import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

typedef MessageBuilder = Widget Function(BuildContext context, SessionMessage message);

class ChatListView extends StatefulWidget {
  const ChatListView({
    super.key,
    required this.messages,
    required this.messageBuilder,
  });

  final List<SessionMessage> messages;
  final MessageBuilder messageBuilder;

  @override
  ChatListViewState createState() => ChatListViewState();
}

class ChatListViewState extends State<ChatListView> {
  static const _bottomTolerance = 24.0;

  final _scrollController = ScrollController();
  final _itemKeys = <String, GlobalKey>{};
  bool _stickToBottom = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动到指定消息（通过 msgId 定位）。
  ///
  /// 如果目标消息在屏幕外，先近似跳转使其被构建，再精确对齐。
  void scrollToMessage(String msgId) {
    final key = _itemKeys[msgId];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: 0.3, // 目标消息停在屏幕上方 30% 处
    );
    // 取消吸底，避免滚动后被自动拉回底部
    if (_stickToBottom) {
      setState(() => _stickToBottom = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(child: Text(l10n.noMessagesYet));
    }

    // 清理不再存在的 key
    final currentIds = <String>{for (final m in widget.messages) m.msgId};
    _itemKeys.keys.where((id) => !currentIds.contains(id)).toList().forEach(_itemKeys.remove);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_stickToBottom) _scrollToBottom();
    });

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        final isNearBottom = notification.metrics.extentAfter <= _bottomTolerance;

        if (notification is UserScrollNotification) {
          if (notification.direction == ScrollDirection.idle) return false;
          final shouldStick = isNearBottom && notification.direction == ScrollDirection.reverse;
          if (_stickToBottom != shouldStick) {
            setState(() => _stickToBottom = shouldStick);
          }
          return false;
        }

        if (notification is ScrollUpdateNotification) {
          final delta = notification.scrollDelta ?? 0;
          final isMovingTowardHistory = delta < 0;
          final shouldStick = !isMovingTowardHistory && isNearBottom;
          if (_stickToBottom == shouldStick) return false;
          setState(() => _stickToBottom = shouldStick);
          return false;
        }

        if (notification is ScrollEndNotification && !_stickToBottom && isNearBottom) {
          setState(() => _stickToBottom = true);
        }
        return false;
      },
      child: Container(
        color: AppColors.pageBg,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: widget.messages.length,
          itemBuilder: (context, index) {
            final msg = widget.messages[index];
            final key = _itemKeys.putIfAbsent(msg.msgId, () => GlobalKey());
            return KeyedSubtree(
              key: key,
              child: widget.messageBuilder(context, msg),
            );
          },
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    final distance = (max - position.pixels).abs();
    if (distance < 4) return;
    _scrollController.animateTo(
      max,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }
}
