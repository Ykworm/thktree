import 'package:flutter/cupertino.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// iOS Mail 风格的滑动操作行：左滑/右滑露出按钮，点击按钮触发对应回调。
///
/// 用户左滑时**不会**直接触发 [onSwipeLeft] / [onSwipeRight]；必须松手后
/// 用户再**主动点击**露出的按钮才会触发回调。这是为了避免"滑动一点点就误删"。
///
/// 行为规范：
/// - 单侧单按钮固定宽度 80pt（参考 [修复左滑删除按钮宽度无限增加问题]）
/// - 左滑可配置第二按钮 [onSwipeLeftSecondary]（再 +80pt），顺序：次要 | 主（靠右）
/// - 按钮始终满宽满高；靠内容位移 + ClipRect 露出
/// - icon 用 [SFIcon] + 固定宽槽，与下方 label 共用同一水平中心
/// - 拖动超过 60pt 阈值后松手，自动展开；否则回弹
/// - 点击按钮后先回弹，再触发回调
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
  final VoidCallback? onSwipeLeft;

  /// 用户点击右滑露出的按钮时触发。
  final VoidCallback? onSwipeRight;

  final String? leftActionLabel;
  final IconData? leftActionIcon;
  final Color? leftActionColor;

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
  static const _kIconSlot = 28.0;
  static const _kIconSize = 20.0;

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

    return ClipRect(
      child: Stack(
        children: [
          if (absExtent > 0)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  if (isLeft && _canSwipeLeft) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hasSecondaryLeft)
                            _buildAction(
                              height: h,
                              icon: widget.leftSecondaryActionIcon!,
                              label: widget.leftSecondaryActionLabel!,
                              color: widget.leftSecondaryActionColor!,
                              onTap: widget.onSwipeLeftSecondary!,
                            ),
                          if (_hasPrimaryLeft)
                            _buildAction(
                              height: h,
                              icon: widget.leftActionIcon!,
                              label: widget.leftActionLabel!,
                              color: widget.leftActionColor!,
                              onTap: widget.onSwipeLeft!,
                            ),
                        ],
                      ),
                    );
                  }
                  if (!isLeft && _canSwipeRight) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: _buildAction(
                        height: h,
                        icon: widget.rightActionIcon!,
                        label: widget.rightActionLabel!,
                        color: widget.rightActionColor!,
                        onTap: widget.onSwipeRight!,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
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
    required double height,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    // icon 与 label 共用同一内容宽，水平中心一致。
    const contentWidth = _kButtonWidth;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _snapBack();
        onTap();
      },
      child: Container(
        width: _kButtonWidth,
        height: height,
        color: color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: contentWidth,
              height: _kIconSlot,
              child: Center(
                child: SFIcon(
                  icon,
                  fontSize: _kIconSize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.white,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: contentWidth,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
