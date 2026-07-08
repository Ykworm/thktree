import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_durations.dart';

typedef MessageBuilder = Widget Function(BuildContext context, SessionMessage message);

class ChatListView extends StatefulWidget {
  const ChatListView({
    super.key,
    required this.messages,
    required this.messageBuilder,
    this.onScrollPositionChanged,
  });

  final List<SessionMessage> messages;
  final MessageBuilder messageBuilder;

  /// 当滚动位置变化时回调，参数 `isNearBottom` 表示是否接近底部。
  final ValueChanged<bool>? onScrollPositionChanged;

  @override
  ChatListViewState createState() => ChatListViewState();
}

class ChatListViewState extends State<ChatListView> {
  static const _bottomTolerance = 24.0;

  final _scrollController = ScrollController();
  final _itemKeys = <String, GlobalKey>{};
  bool _stickToBottom = true;
  bool _isNearBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final nearBottom = position.extentAfter <= _bottomTolerance;
    if (nearBottom != _isNearBottom) {
      _isNearBottom = nearBottom;
      widget.onScrollPositionChanged?.call(nearBottom);
    }
  }

  /// 滚动到指定消息（通过 msgId 定位）。
  ///
  /// 先测量所有消息的实际高度，再用精确偏移量跳转。
  /// 如果目标已在屏幕上，直接用 `Scrollable.ensureVisible`。
  void scrollToMessage(String msgId) {
    if (!_scrollController.hasClients) return;

    // 取消吸底，避免滚动后被自动拉回底部
    if (_stickToBottom) {
      setState(() => _stickToBottom = false);
    }

    // 目标已在屏幕上，直接精确滚动
    final key = _itemKeys[msgId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: AppDur.listScroll,
        curve: AppDur.listScrollCurve,
        alignment: 0.3,
      );
      return;
    }

    // 测量所有消息高度，计算精确偏移量
    final index = widget.messages.indexWhere((m) => m.msgId == msgId);
    if (index < 0) return;

    _measureAndScroll(index);
  }

  /// 测量所有消息的实际高度，然后精确跳转到目标索引。
  void _measureAndScroll(int targetIndex) async {
    final heights = await _measureAllItemHeights();
    if (!mounted || heights.isEmpty) return;

    // 累计偏移量（含 12px ListView padding）
    var offset = 12.0;
    for (var i = 0; i < targetIndex; i++) {
      offset += heights[i];
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(offset.clamp(0.0, maxScroll));

    // 等一帧渲染，再精确对齐
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _itemKeys[widget.messages[targetIndex].msgId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: AppDur.sheetScroll,
          curve: Curves.easeOut,
          alignment: 0.3,
        );
      }
    });
  }

  /// 逐条构建消息并测量实际渲染高度。
  ///
  /// 通过临时 overlay 附加 widget → 读取 RenderBox.size → 移除，
  /// 得到每条消息在当前宽度下的精确高度。
  Future<List<double>> _measureAllItemHeights() async {
    final heights = <double>[];
    final overlay = Overlay.of(context, debugRequiredFor: widget);

    for (final msg in widget.messages) {
      final key = GlobalKey();
      final entry = OverlayEntry(
        builder: (_) => Offstage(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: KeyedSubtree(
              key: key,
              child: widget.messageBuilder(context, msg),
            ),
          ),
        ),
      );

      overlay.insert(entry);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        entry.remove();
        return heights;
      }

      final box = key.currentContext?.findRenderObject() as RenderBox?;
      heights.add(box?.size.height ?? 80.0);
      entry.remove();
    }

    return heights;
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
      if (_stickToBottom) scrollToBottom();
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

  /// 滚动到列表底部（最新消息）。
  void scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    final distance = (max - position.pixels).abs();
    if (distance < 4) return;
    _scrollController.animateTo(
      max,
      duration: AppDur.scrimFade,
      curve: AppDur.scrimFadeCurve,
    );
  }

  /// 滚动到列表顶部（最早消息）。
  void scrollToTop() {
    if (!_scrollController.hasClients) return;
    final distance = _scrollController.position.pixels.abs();
    if (distance < 4) return;
    _scrollController.animateTo(
      0,
      duration: AppDur.listScroll,
      curve: AppDur.listScrollCurve,
    );
  }
}
