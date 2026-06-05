import 'package:flutter/cupertino.dart';

/// iOS Mail 风格的滑动操作行：左滑/右滑露出按钮，点击按钮触发对应回调。
///
/// 用户左滑时**不会**直接触发 [onSwipeLeft] / [onSwipeRight]；必须松手后
/// 用户再**主动点击**露出的按钮才会触发回调。这是为了避免"滑动一点点就误删"。
///
/// 行为规范：
/// - 按钮固定宽度 80pt（参考 [修复左滑删除按钮宽度无限增加问题]）
/// - 拖动超过 60pt 阈值后松手，自动展开到 80pt；否则回弹
/// - 点击按钮后先回弹，再触发回调，确保后续弹窗干净显示
class SwipeableRow extends StatefulWidget {
  const SwipeableRow({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.leftActionLabel,
    this.leftActionIcon,
    this.leftActionColor,
    this.rightActionLabel,
    this.rightActionIcon,
    this.rightActionColor,
  });

  final Widget child;

  /// 用户点击左滑露出的按钮时触发。`null` 表示禁用左滑操作。
  final VoidCallback? onSwipeLeft;

  /// 用户点击右滑露出的按钮时触发。`null` 表示禁用右滑操作。
  final VoidCallback? onSwipeRight;

  final String? leftActionLabel;
  final IconData? leftActionIcon;
  final Color? leftActionColor;

  final String? rightActionLabel;
  final IconData? rightActionIcon;
  final Color? rightActionColor;

  @override
  State<SwipeableRow> createState() => _SwipeableRowState();
}

class _SwipeableRowState extends State<SwipeableRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragExtent = 0;
  static const _kThreshold = 60.0;
  static const _kMaxExtent = 80.0;
  static const _kButtonWidth = 80.0;

  bool get _canSwipeLeft => widget.onSwipeLeft != null;
  bool get _canSwipeRight => widget.onSwipeRight != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snapBack() {
    final start = _dragExtent;
    final anim = Tween<double>(begin: start, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.reset();
    anim.addListener(() {
      if (mounted) setState(() => _dragExtent = anim.value);
    });
    _controller.forward();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_canSwipeLeft && !_canSwipeRight) return;
    setState(() {
      var next = _dragExtent + details.delta.dx;
      // 禁用一侧的滑动时，禁止向那一侧拖动
      if (!_canSwipeLeft && next < 0) next = 0;
      if (!_canSwipeRight && next > 0) next = 0;
      _dragExtent = next.clamp(-_kMaxExtent, _kMaxExtent);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragExtent < -_kThreshold) {
      _animateTo(-_kMaxExtent);
    } else if (_dragExtent > _kThreshold) {
      _animateTo(_kMaxExtent);
    } else {
      _snapBack();
    }
  }

  void _animateTo(double target) {
    final start = _dragExtent;
    final anim = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.reset();
    anim.addListener(() {
      if (mounted) setState(() => _dragExtent = anim.value);
    });
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final absExtent = _dragExtent.abs();
    final isLeft = _dragExtent < 0;
    final visibleWidth = absExtent.clamp(0.0, _kButtonWidth);

    return ClipRect(
      child: Stack(
        children: [
          // Action buttons behind content
          if (absExtent > 0)
            Positioned.fill(
              child: Row(
                children: [
                  if (!isLeft && _canSwipeRight)
                    _buildAction(
                      icon: widget.rightActionIcon!,
                      label: widget.rightActionLabel!,
                      color: widget.rightActionColor!,
                      alignment: Alignment.center,
                      width: visibleWidth,
                      onTap: widget.onSwipeRight!,
                    ),
                  const Spacer(),
                  if (isLeft && _canSwipeLeft)
                    _buildAction(
                      icon: widget.leftActionIcon!,
                      label: widget.leftActionLabel!,
                      color: widget.leftActionColor!,
                      alignment: Alignment.center,
                      width: visibleWidth,
                      onTap: widget.onSwipeLeft!,
                    ),
                ],
              ),
            ),
          // Sliding content
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _onPanUpdate,
              onHorizontalDragEnd: _onPanEnd,
              child: Container(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required Color color,
    required Alignment alignment,
    required double width,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        _snapBack();
        onTap();
      },
      child: Container(
        width: width,
        color: color,
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: CupertinoColors.white, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
