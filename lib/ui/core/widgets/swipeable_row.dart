import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// iOS Mail 风格的滑动操作行：左滑/右滑露出按钮，点击按钮触发对应回调。
///
/// 用户左滑时**不会**直接触发 [onSwipeLeft] / [onSwipeRight]；必须松手后
/// 用户再**主动点击**露出的按钮才会触发回调。这是为了避免"滑动一点点就误删"。
///
/// 行为规范：
/// - 单侧单按钮固定宽度 80pt（参考 [修复左滑删除按钮宽度无限增加问题]）
/// - 左滑可配置第二按钮 [onSwipeLeftSecondary]（再 +80pt），顺序：次要 | 主（靠右）
/// - 拖动超过 60pt 阈值后松手，自动展开；否则回弹
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
    this.onSwipeLeftSecondary,
    this.leftSecondaryActionLabel,
    this.leftSecondaryActionIcon,
    this.leftSecondaryActionColor,
    this.rightActionLabel,
    this.rightActionIcon,
    this.rightActionColor,
  });

  final Widget child;

  /// 用户点击左滑露出的**主**按钮时触发（靠右，通常为删除）。
  /// `null` 表示禁用左滑（若 secondary 也 null）。
  final VoidCallback? onSwipeLeft;

  /// 用户点击右滑露出的按钮时触发。`null` 表示禁用右滑操作。
  final VoidCallback? onSwipeRight;

  final String? leftActionLabel;
  final IconData? leftActionIcon;
  final Color? leftActionColor;

  /// 左滑第二按钮（靠左，通常为隐藏等软操作）。需与主按钮配套。
  final VoidCallback? onSwipeLeftSecondary;
  final String? leftSecondaryActionLabel;
  final IconData? leftSecondaryActionIcon;
  final Color? leftSecondaryActionColor;

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
  static const _kButtonWidth = 80.0;

  bool get _hasPrimaryLeft => widget.onSwipeLeft != null;
  bool get _hasSecondaryLeft => widget.onSwipeLeftSecondary != null;
  bool get _canSwipeLeft => _hasPrimaryLeft || _hasSecondaryLeft;
  bool get _canSwipeRight => widget.onSwipeRight != null;

  int get _leftButtonCount {
    var n = 0;
    if (_hasPrimaryLeft) n++;
    if (_hasSecondaryLeft) n++;
    return n;
  }

  double get _maxLeftExtent => _kButtonWidth * _leftButtonCount;
  double get _maxRightExtent => _canSwipeRight ? _kButtonWidth : 0;

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
      if (!_canSwipeLeft && next < 0) next = 0;
      if (!_canSwipeRight && next > 0) next = 0;
      _dragExtent = next.clamp(-_maxLeftExtent, _maxRightExtent);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragExtent < -_kThreshold) {
      _animateTo(-_maxLeftExtent);
    } else if (_dragExtent > _kThreshold) {
      _animateTo(_maxRightExtent);
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
    final leftVisible = isLeft ? absExtent.clamp(0.0, _maxLeftExtent) : 0.0;
    final rightVisible = !isLeft ? absExtent.clamp(0.0, _maxRightExtent) : 0.0;

    return ClipRect(
      child: Stack(
        children: [
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
                      width: rightVisible,
                      onTap: widget.onSwipeRight!,
                    ),
                  const Spacer(),
                  if (isLeft && _canSwipeLeft) ...[
                    if (_hasSecondaryLeft)
                      _buildAction(
                        icon: widget.leftSecondaryActionIcon!,
                        label: widget.leftSecondaryActionLabel!,
                        color: widget.leftSecondaryActionColor!,
                        alignment: Alignment.center,
                        width: (leftVisible - _kButtonWidth)
                            .clamp(0.0, _kButtonWidth),
                        onTap: widget.onSwipeLeftSecondary!,
                      ),
                    if (_hasPrimaryLeft)
                      _buildAction(
                        icon: widget.leftActionIcon!,
                        label: widget.leftActionLabel!,
                        color: widget.leftActionColor!,
                        alignment: Alignment.center,
                        width: leftVisible.clamp(0.0, _kButtonWidth),
                        onTap: widget.onSwipeLeft!,
                      ),
                  ],
                ],
              ),
            ),
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _onPanUpdate,
              onHorizontalDragEnd: _onPanEnd,
              child: Container(
                color: AppColors.surface,
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: width < 24
            ? const SizedBox.shrink()
            : Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.white, size: 20),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      color: AppColors.white,
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
