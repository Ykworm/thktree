import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/shared/link_launcher.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/core/widgets/thk_nav_bar.dart';
import 'package:thk_tree/ui/features/settings/tts_controller.dart';
import 'package:thk_tree/ui/features/settings/tts_settings_screen.dart';
import 'package:thk_tree/ui/features/settings/tts_tokens.dart';
import 'package:thk_tree/ui/features/settings/widgets/tts_player_background.dart';
import 'package:thk_tree/ui/features/settings/widgets/tts_pulse_rings.dart';

/// 速度档位预设。label 为显示文本，rate 为 AVSpeechUtterance.rate 值。
const _speedPresets = [
  (label: '0.75×', rate: 0.35), // 默认偏慢，更自然
  (label: '1×',   rate: 0.5),
  (label: '1.5×', rate: 0.75),
  (label: '2×',   rate: 1.0),
];

/// TTS 播放器全屏页。
///
/// 组合层：3 层背景 + 沉浸式文本（延伸到屏幕底部）+ 底部毛玻璃控制面板（mini bar 布局）+ 双击标题回到顶部。
/// 设置入口在导航栏 trailing。
class TtsPlayerScreen extends ConsumerStatefulWidget {
  const TtsPlayerScreen({
    super.key,
    required this.messageId,
    required this.text,
  });

  final String messageId;
  final String text;

  @override
  ConsumerState<TtsPlayerScreen> createState() => _TtsPlayerScreenState();
}

class _TtsPlayerScreenState extends ConsumerState<TtsPlayerScreen> {
  final _scrollController = ScrollController();
  int _speedIndex = 0; // 默认 0.75×（偏慢，更自然）

  double get _rate => _speedPresets[_speedIndex].rate;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final ctrl = ref.read(ttsControllerProvider.notifier);
    final state = ref.read(ttsControllerProvider);

    if (state.isSpeaking && state.playingMessageId == widget.messageId) {
      await ctrl.stop();
    } else {
      await ctrl.play(widget.messageId, widget.text, rate: _rate);
    }
  }

  void _cycleSpeed() {
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speedPresets.length;
    });
  }

  void _openSettings() {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const TtsSettingsScreen()),
    );
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: TtsMotion.scrollBackToTopDuration,
        curve: TtsMotion.scrollBackToTopCurve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ttsState = ref.watch(ttsControllerProvider);
    final isThisPlaying =
        ttsState.isSpeaking && ttsState.playingMessageId == widget.messageId;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.transparent, // 让背景透出
      navigationBar: ThkNavBar.inline(
        title: l10n.ttsPlay,
        onTitleDoubleTap: _scrollToTop,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(AppIcons.back),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: _openSettings,
          child: const Icon(AppIcons.settings, size: 22),
        ),
      ),
      child: Stack(
        children: [
          // Layer 1-3: 背景
          Positioned.fill(
            child: TtsPlayerBackground(messageId: widget.messageId),
          ),

          // 文本区 — 铺满全屏，内容延伸到控制面板下方
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TtsSpacing.playerPagePaddingX,
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 16, bottom: 120),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: TtsSpacing.playerTextMaxWidth,
                      ),
                      child: GptMarkdown(
                        widget.text,
                        style: AppTheme.body.copyWith(
                          height: TtsSpacing.playerTextLineHeight,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                        onLinkTap: (url, _) => openMarkdownLink(context, url),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 底部毛玻璃控制面板 — 叠在最上层
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ControlPanel(
              isPlaying: isThisPlaying,
              speedLabel: _speedPresets[_speedIndex].label,
              onTogglePlay: _togglePlay,
              onCycleSpeed: _cycleSpeed,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedLabel extends StatelessWidget {
  const _SpeedLabel({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.symmetric(
        horizontal: TtsSpacing.speedLabelHorizontalPadding,
        vertical: TtsSpacing.speedLabelVerticalPadding,
      ),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: TtsSpacing.speedLabelFontSize,
          fontWeight: FontWeight.w600,
          color: TtsColors.textSecondary,
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = isPlaying ? AppIcons.ttsPause : AppIcons.ttsPlay;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        width: TtsDimensions.playerButtonSize,
        height: TtsDimensions.playerButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPlaying ? AppColors.accent : AppColors.surface,
          border: Border.all(
            color: isPlaying ? AppColors.accent : AppColors.border,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isPlaying
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : AppColors.scrimSoft,
              blurRadius: isPlaying ? 16 : 12,
              offset: const Offset(0, 2),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: TtsDimensions.playerButtonIconSize,
          color: isPlaying ? AppColors.surface : TtsColors.textSecondary,
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.isPlaying,
    required this.speedLabel,
    required this.onTogglePlay,
    required this.onCycleSpeed,
  });

  final bool isPlaying;
  final String speedLabel;
  final VoidCallback onTogglePlay;
  final VoidCallback onCycleSpeed;

  @override
  Widget build(BuildContext context) {
    // SizedBox 锁死高度，让 BackdropFilter 的 saveLayer 范围 = mini bar 自身，
    // 避免 Positioned 半约束下 saveLayer 被扩到父 Stack 整高（导致内容区被糊）。
    return SizedBox(
      height: TtsDimensions.controlPanelHeight,
      child: Stack(
        children: [
          // 毛玻璃背景层（背）— Positioned.fill 严格落在 SizedBox 范围内
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(TtsSpacing.controlPanelRadius),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: TtsSpacing.controlPanelBlurSigma,
                  sigmaY: TtsSpacing.controlPanelBlurSigma,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(
                      alpha: TtsSpacing.controlPanelSurfaceAlpha,
                    ),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.35),
                      ),
                    ),
                    // 顶边向上投影：iOS bottom toolbar 惯例，让 mini bar
                    // 跟上方内容区视觉分离，看起来像"悬浮"面板
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.scrimSoft, // ~6% black
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 内容前景层 — 在毛玻璃之上，按钮 + 速度标签
          Padding(
            padding: EdgeInsets.fromLTRB(
              TtsSpacing.controlPanelPaddingH,
              TtsSpacing.controlPanelPaddingV,
              TtsSpacing.controlPanelPaddingH,
              TtsSpacing.controlPanelPaddingV, // 跟顶边对齐 = 14pt，按钮真正居中
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左侧：播放按钮 + 脉冲环
                TtsPulseRings(
                  isActive: isPlaying,
                  size: TtsDimensions.playerButtonSize,
                  child: _PlayButton(
                    isPlaying: isPlaying,
                    onTap: onTogglePlay,
                  ),
                ),
                // 右侧：速度标签
                _SpeedLabel(
                  label: speedLabel,
                  onTap: onCycleSpeed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
