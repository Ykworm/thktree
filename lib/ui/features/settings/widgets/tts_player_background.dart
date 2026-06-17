import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/features/settings/tts_controller.dart';
import 'package:thk_tree/ui/features/settings/tts_tokens.dart';

/// Player 页背景，三层组合：
///
/// Layer 1（base）：纯色 `AppColors.pageBg`
/// Layer 2（ambient radial）：champagne gold 顶部扩散，alpha 随 speaking 起伏（GlowShift）
/// Layer 3（per-message tint）：node palette × 0.03 alpha，soft light 混合
///
/// idle 时完全静态；speaking 时 Layer 2 alpha 在
/// [TtsMotion.glowShiftAlphaIdle] ↔ [TtsMotion.glowShiftAlphaSpeaking] 之间循环。
class TtsPlayerBackground extends ConsumerStatefulWidget {
  const TtsPlayerBackground({super.key, this.messageId});

  final String? messageId;

  @override
  ConsumerState<TtsPlayerBackground> createState() => _TtsPlayerBackgroundState();
}

class _TtsPlayerBackgroundState extends ConsumerState<TtsPlayerBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: TtsMotion.glowShiftDuration ~/ 2,
    );
    _syncGlow();
  }

  void _syncGlow() {
    final isSpeaking = ref.read(ttsControllerProvider.select((s) => s.isSpeaking));
    if (isSpeaking) {
      _glowCtrl.repeat(reverse: true);
    } else {
      _glowCtrl.stop();
      _glowCtrl.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 状态变化时同步动画（speaking 开始 → 启动 glow；结束 → 停止）
    ref.listen(ttsControllerProvider.select((s) => s.isSpeaking), (_, __) {
      _syncGlow();
    });

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: base color
          ColoredBox(color: TtsColors.playerBg),

          // Layer 2: ambient radial gradient
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (context, _) {
              final t = _glowCtrl.value;
              final alpha = TtsMotion.glowShiftAlphaIdle +
                  (TtsMotion.glowShiftAlphaSpeaking -
                          TtsMotion.glowShiftAlphaIdle) *
                      t;
              return _AmbientRadial(alpha: alpha);
            },
          ),

          // Layer 3: per-message tint
          if (widget.messageId != null) _PerMessageTint(messageId: widget.messageId!),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }
}

/// Layer 2：从屏幕顶部中点向下的 champagne gold 径向渐变。
class _AmbientRadial extends StatelessWidget {
  const _AmbientRadial({required this.alpha});

  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: TtsMotion.glowShiftCenter,
            radius: TtsMotion.glowShiftRadius,
            colors: [
              AppColors.champagneGold.withValues(alpha: alpha),
              AppColors.champagneGold.withValues(alpha: 0),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Layer 3：per-message 节点配色 × 0.03 alpha，soft light 混合。
class _PerMessageTint extends StatelessWidget {
  const _PerMessageTint({required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.paletteForNode(messageId);
    return IgnorePointer(
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          palette.title.withValues(alpha: TtsMotion.perMessageTintAlpha),
          BlendMode.softLight,
        ),
        child: const ColoredBox(color: Color(0x00000000)),
      ),
    );
  }
}
