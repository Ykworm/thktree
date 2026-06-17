import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/features/settings/tts_tokens.dart';

/// Player 页右下角浮按钮："↑ 回到顶部"。
///
/// 行为：
/// - scrollY > [TtsMotion.scrollShowThreshold] 时淡入
/// - 停止滚动 [TtsMotion.scrollHideDelay] 后才更新可见性（debounce）
/// - 点击 → scrollController.animateTo(0)
/// - dispose 时清理 timer 和 listener
///
/// v1 行为：仅"回到顶部"模式。v2 跟随朗读 ON 时文案变"→ 继续跟随"（见 roadmap §11.1）。
class TtsBackToTopButton extends ConsumerStatefulWidget {
  const TtsBackToTopButton({
    super.key,
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  ConsumerState<TtsBackToTopButton> createState() => _TtsBackToTopButtonState();
}

class _TtsBackToTopButtonState extends ConsumerState<TtsBackToTopButton> {
  bool _visible = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final y = widget.scrollController.position.pixels;
    final shouldShow = y > TtsMotion.scrollShowThreshold;
    if (shouldShow == _visible) return; // 防抖
    _debounce?.cancel();
    _debounce = Timer(TtsMotion.scrollHideDelay, () {
      if (mounted) setState(() => _visible = shouldShow);
    });
  }

  void _onTap() {
    widget.scrollController.animateTo(
      0,
      duration: TtsMotion.scrollBackToTopDuration,
      curve: TtsMotion.scrollBackToTopCurve,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      right: TtsMotion.scrollBackToTopRight,
      bottom: TtsMotion.scrollBackToTopBottom,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: TtsMotion.scrollFadeDuration,
        child: IgnorePointer(
          ignoring: !_visible,
          child: Semantics(
            label: l10n.ttsBackToTop,
            button: true,
            child: GestureDetector(
              onTap: _onTap,
              child: Container(
                width: TtsDimensions.backToTopSize,
                height: TtsDimensions.backToTopSize,
                decoration: BoxDecoration(
                  color: TtsColors.backToTopBg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ui.Color.fromRGBO(0, 0, 0, TtsMotion.backToTopShadowAlpha),
                      blurRadius: TtsMotion.backToTopShadowBlur,
                      offset: Offset(0, TtsMotion.backToTopShadowOffsetY),
                    ),
                  ],
                ),
                child: Icon(
                  AppIcons.chevronUp,
                  size: TtsDimensions.backToTopIconSize,
                  color: TtsColors.backToTopFg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
