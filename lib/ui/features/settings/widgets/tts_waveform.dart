import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:thk_tree/ui/features/settings/tts_tokens.dart';

/// 5-bar 波形均衡器。仅在 isActive=true 时通过 [Ticker] 采样驱动；
/// idle 时完全静态（节省电量）。
///
/// 高度公式：
///   h = lerp(min, max, 0.5 + sin(phase * 2π) * sinAmp + (random-0.5) * noise)
///   phase = t * speed + i * offset  (i = bar index)
///
/// TODO(roadmap-v3): 真实振幅替换随机 sin
///   spec: docs/modules/settings/specs/2026-06-05-语音播放功能-design.md#11-v3
///   hook: TtsService.amplitudeStream
class TtsWaveform extends StatefulWidget {
  const TtsWaveform({super.key, required this.isActive});

  final bool isActive;

  @override
  State<TtsWaveform> createState() => _TtsWaveformState();
}

class _TtsWaveformState extends State<TtsWaveform>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final math.Random _random;
  late List<double> _heights;

  static const double _speed = 1.7; // rad/s，节奏感
  static const double _barOffset = 0.4; // bar 之间相位差

  @override
  void initState() {
    super.initState();
    _random = math.Random();
    _heights = List.filled(TtsMotion.waveformBarCount, TtsMotion.waveformBarHeightMin);
    _ticker = createTicker(_onTick);
    if (widget.isActive) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant TtsWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_ticker.isActive) {
      _ticker.start();
    } else if (!widget.isActive && _ticker.isActive) {
      _ticker.stop();
      // 立即归零
      setState(() {
        for (var i = 0; i < _heights.length; i++) {
          _heights[i] = TtsMotion.waveformBarHeightMin;
        }
      });
    }
  }

  void _onTick(Duration elapsed) {
    final tSec = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    setState(() {
      for (var i = 0; i < TtsMotion.waveformBarCount; i++) {
        final phase = tSec * _speed + i * _barOffset;
        final sin = math.sin(phase * 2 * math.pi) * TtsMotion.waveformTickSinAmp;
        final noise = (_random.nextDouble() - 0.5) * TtsMotion.waveformTickNoise;
        final h = (0.5 + sin + noise).clamp(0.0, 1.0);
        _heights[i] = _lerp(
          TtsMotion.waveformBarHeightMin,
          TtsMotion.waveformBarHeightMax,
          h,
        );
      }
    });
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive ? TtsColors.waveformActive : TtsColors.waveformIdle;
    return RepaintBoundary(
      child: Semantics(
        label: '语音波形',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < TtsMotion.waveformBarCount; i++) ...[
              if (i > 0) SizedBox(width: TtsMotion.waveformBarGap),
              _Bar(
                height: _heights[i],
                color: color,
                width: TtsMotion.waveformBarWidth,
                radius: TtsMotion.waveformBarRadius,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.color,
    required this.width,
    required this.radius,
  });

  final double height;
  final Color color;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
