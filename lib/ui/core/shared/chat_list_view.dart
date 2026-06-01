import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';

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
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  static const _bottomTolerance = 24.0;

  final _scrollController = ScrollController();
  bool _stickToBottom = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(child: Text(l10n.noMessagesYet));
    }

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
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: widget.messages.length,
        itemBuilder: (context, index) {
          final msg = widget.messages[index];
          return widget.messageBuilder(context, msg);
        },
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
