import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/features/settings/tts_tokens.dart';

/// 播放按钮外圈的扩散脉冲环。
///
/// - 2 圈同心 BoxShape.circle 边框
/// - 从按钮尺寸 1.0x → 1.8x 扩散，alpha 0.35 → 0
/// - 单环 duration = [TtsMotion.pulseRingDuration]，环 1 起步、环 2 错峰 [TtsMotion.pulseRingStagger]
/// - 仅 isActive=true 时启动；speaking 结束立即停
///
/// 子节点是中心的 widget（通常是播放按钮）。环用 Stack 叠在子节点周围。
class TtsPulseRings extends StatefulWidget {
  const TtsPulseRings({
    super.key,
    required this.isActive,
    required this.child,
    this.size = 56,
  });

  final bool isActive;
  final Widget child;

  /// 中心 child 的边长。环基于此尺寸计算扩散。
  final double size;

  @override
  State<TtsPulseRings> createState() => _TtsPulseRingsState();
}

class _TtsPulseRingsState extends State<TtsPulseRings>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      TtsMotion.pulseRingCount,
      (_) => AnimationController(
        vsync: this,
        duration: TtsMotion.pulseRingDuration,
      ),
    );
    if (widget.isActive) {
      _startAll();
    }
  }

  void _startAll() {
    for (var i = 0; i < _ctrls.length; i++) {
      final ctrl = _ctrls[i];
      if (!ctrl.isAnimating) {
        Future<void>.delayed(
          i == 0 ? Duration.zero : TtsMotion.pulseRingStagger,
          () {
            if (mounted) ctrl.repeat();
          },
        );
      }
    }
  }

  void _stopAll() {
    for (final c in _ctrls) {
      c.stop();
      c.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant TtsPulseRings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startAll();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopAll();
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final c in _ctrls) _Ring(controller: c, size: widget.size),
          widget.child,
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.controller, required this.size});

  final AnimationController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          final currentSize = size *
              (TtsMotion.pulseRingStartSize +
                  (TtsMotion.pulseRingEndSize - TtsMotion.pulseRingStartSize) * t);
          final alpha = TtsMotion.pulseRingAlphaFrom +
              (TtsMotion.pulseRingAlphaTo - TtsMotion.pulseRingAlphaFrom) * t;
          return SizedBox(
            width: currentSize,
            height: currentSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: TtsColors.actionActive.withValues(alpha: alpha),
                  width: TtsMotion.pulseRingStrokeWidth,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
