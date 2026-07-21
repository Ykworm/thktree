import 'dart:ui' show ImageFilter;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/chat/widgets/clips_sheet.dart';

class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.hintText,
    required this.isStreaming,
    required this.onSend,
    required this.onStopStreaming,
    this.enabled = true,
    this.webSearchEnabled = false,
    this.webSearchSupported = false,
    this.onWebSearchToggle,
    this.deepThinkingEnabled = false,
    this.deepThinkingSupported = false,
    this.onDeepThinkingToggle,
    this.alwaysThinking = false,
    this.onImagePick,
    this.imageSupported = false,
    this.selectedImageData,
    this.selectedImageMimeType,
    this.onImageRemove,
  });

  final String hintText;
  final bool isStreaming;
  final bool enabled;
  final Future<void> Function(String text, {Uint8List? imageData, String? imageMimeType}) onSend;
  final Future<void> Function() onStopStreaming;

  /// 联网搜索是否开启
  final bool webSearchEnabled;

  /// 当前模型是否支持联网搜索
  final bool webSearchSupported;

  /// 联网搜索开关回调（null 表示不显示按钮）
  final VoidCallback? onWebSearchToggle;

  /// 深度思考是否开启（per-session in-memory 状态）
  final bool deepThinkingEnabled;

  /// 当前模型是否支持深度思考
  final bool deepThinkingSupported;

  /// 深度思考开关回调（null 表示不显示按钮）
  final VoidCallback? onDeepThinkingToggle;

  /// 当前模型默认开启深度思考且无法关闭（豆包 Seed 系列），显示只读 chip，
  /// 取代可点击的 toggle。true 时即便 [onDeepThinkingToggle] 也可能被忽略。
  final bool alwaysThinking;

  /// 图片选择回调（null 表示不显示按钮）
  final VoidCallback? onImagePick;

  /// 当前模型是否支持图片
  final bool imageSupported;

  /// 已选图片数据
  final Uint8List? selectedImageData;

  /// 已选图片 MIME 类型
  final String? selectedImageMimeType;

  /// 移除已选图片回调
  final VoidCallback? onImageRemove;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final _controller = TextEditingController();
  final _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTools = widget.onWebSearchToggle != null ||
        widget.onDeepThinkingToggle != null ||
        widget.alwaysThinking;

    final attachEnabled =
        widget.onImagePick != null && widget.imageSupported && !widget.isStreaming;

    final showThinkingTool =
        widget.alwaysThinking || widget.onDeepThinkingToggle != null;

    // 大胶囊毛玻璃
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: _ComposerGlassShell(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.selectedImageData != null) ...[
                _ImagePreview(
                  imageData: widget.selectedImageData!,
                  onRemove: widget.onImageRemove!,
                ),
                const SizedBox(height: 4),
              ],
              // 主行：输入框 + 右侧按钮
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (!widget.enabled) return KeyEventResult.ignored;
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        if (event.logicalKey != LogicalKeyboardKey.enter &&
                            event.logicalKey != LogicalKeyboardKey.numpadEnter) {
                          return KeyEventResult.ignored;
                        }
                        final composing = _controller.value.composing;
                        if (composing.isValid && !composing.isCollapsed) {
                          return KeyEventResult.ignored;
                        }
                        if (HardwareKeyboard.instance.isShiftPressed ||
                            HardwareKeyboard.instance.isControlPressed) {
                          _insertNewline();
                          return KeyEventResult.handled;
                        }
                        _send();
                        return KeyEventResult.handled;
                      },
                      child: CupertinoTextField(
                        key: const ValueKey('chat_input'),
                        controller: _controller,
                        focusNode: _inputFocusNode,
                        enabled: widget.enabled,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        autocorrect: false,
                        enableInteractiveSelection: true,
                        textCapitalization: TextCapitalization.none,
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        placeholder: widget.hintText,
                        placeholderStyle: TextStyle(
                          color: AppColors.textQuaternary,
                          fontSize: 16,
                        ),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                        prefix: widget.onImagePick != null
                            ? CupertinoButton(
                                key: const ValueKey('attach_image_button'),
                                padding: const EdgeInsets.only(
                                  left: 10,
                                  right: 8,
                                ),
                                minimumSize: const Size(36, 36),
                                onPressed:
                                    attachEnabled ? widget.onImagePick : null,
                                child: Icon(
                                  AppIcons.add,
                                  size: 22,
                                  color: attachEnabled
                                      ? AppColors.accent
                                      : AppColors.textQuaternary,
                                ),
                              )
                            : null,
                        decoration: const BoxDecoration(
                          color: AppColors.transparent,
                        ),
                        padding: EdgeInsets.fromLTRB(
                          widget.onImagePick != null ? 0 : 16,
                          12,
                          14,
                          12,
                        ),
                        onSubmitted: (_) {
                          final composing = _controller.value.composing;
                          if (composing.isValid && !composing.isCollapsed) {
                            return;
                          }
                          if (HardwareKeyboard.instance.isShiftPressed ||
                              HardwareKeyboard.instance.isControlPressed) {
                            return;
                          }
                          _send();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _CircleIconButton(
                    icon: AppIcons.clips,
                    onPressed: _openClipsSheet,
                  ),
                  const SizedBox(width: 4),
                  _CircleIconButton(
                    buttonKey: ValueKey(
                      widget.isStreaming ? 'stop_button' : 'send_button',
                    ),
                    icon: widget.isStreaming ? AppIcons.stop : AppIcons.send,
                    onPressed: widget.enabled
                        ? widget.isStreaming
                            ? _stopStreaming
                            : _send
                        : null,
                  ),
                  const SizedBox(width: 10), // 右侧边距
                ],
              ),
              // 工具行：无背景直接放入大胶囊
              if (showTools) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    children: [
                      if (widget.onWebSearchToggle != null) ...[
                        _WebSearchToggle(
                          enabled: widget.webSearchEnabled,
                          supported: widget.webSearchSupported,
                          isStreaming: widget.isStreaming,
                          onToggle: widget.onWebSearchToggle!,
                        ),
                        if (showThinkingTool) const _ToolDivider(),
                      ],
                      if (widget.alwaysThinking)
                        _AlwaysThinkingIndicator(
                          isStreaming: widget.isStreaming,
                        )
                      else if (widget.onDeepThinkingToggle != null)
                        _DeepThinkingToggle(
                          enabled: widget.deepThinkingEnabled,
                          supported: widget.deepThinkingSupported,
                          isStreaming: widget.isStreaming,
                          onToggle: widget.onDeepThinkingToggle!,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openClipsSheet() {
    showClipsSheet(context, _controller);
  }

  Future<void> _send() async {
    final text = _controller.text;
    // 允许只发图片不发文本
    if (text.trim().isEmpty && widget.selectedImageData == null) return;
    _controller.clear();
    try {
      await widget.onSend(
        text,
        imageData: widget.selectedImageData,
        imageMimeType: widget.selectedImageMimeType,
      );
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    } catch (e) {
      _controller.text = text;
      if (mounted) {
        _inputFocusNode.requestFocus();
        _showError(e.toString());
      }
    }
  }

  Future<void> _stopStreaming() async {
    try {
      await widget.onStopStreaming();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ThkAlert.show(
      context: context,
      message: message,
    );
  }

  void _insertNewline() {
    final value = _controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final updated = text.replaceRange(start, end, '\n');
    _controller.value = value.copyWith(
      text: updated,
      selection: TextSelection.collapsed(offset: start + 1),
      composing: TextRange.empty,
    );
  }
}

/// 工具 pill 内竖线分隔
class _ToolDivider extends StatelessWidget {
  const _ToolDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSp.dividerThickness,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: AppColors.border.withValues(alpha: 0.85),
    );
  }
}

/// 输入行右侧圆钮（碎片 / 发送）：无毛玻璃底的图标按钮
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    this.onPressed,
    this.buttonKey,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      key: buttonKey,
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onPressed != null ? AppColors.accent.withValues(alpha: 0.1) : AppColors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: onPressed != null ? AppColors.accent : AppColors.textQuaternary,
        ),
      ),
    );
  }
}

/// 功能开关：落在工具玻璃 pill 上的扁平 chip（无重边框，靠玻璃与字色分层）
/// - active：淡 accent 底 + accent 字
/// - 关闭可点：accent 系字
/// - 不可点：弱化灰
class _ToolChip extends StatelessWidget {
  const _ToolChip({
    this.icon,
    required this.label,
    this.active = false,
    this.onPressed,
  });

  final IconData? icon;
  final String label;

  /// 视觉激活态（accent）。只读 indicator 也可为 true（onPressed 为 null）。
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color fg = active
        ? AppColors.accent
        : onPressed != null
            ? AppColors.textSecondary
            : AppColors.textTertiary.withValues(alpha: 0.55);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 36),
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 联网搜索开关 chip（输入壳内工具行）
class _WebSearchToggle extends StatelessWidget {
  const _WebSearchToggle({
    required this.enabled,
    required this.supported,
    required this.isStreaming,
    required this.onToggle,
  });

  final bool enabled;
  final bool supported;
  final bool isStreaming;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _ToolChip(
      icon: enabled ? AppIcons.globe : AppIcons.globeSlash,
      label: supported ? '联网搜索' : '不支持联网',
      active: enabled && supported,
      onPressed: supported && !isStreaming ? onToggle : null,
    );
  }
}

/// 深度思考常开只读 chip（豆包 Seed 类模型）
class _AlwaysThinkingIndicator extends StatelessWidget {
  const _AlwaysThinkingIndicator({required this.isStreaming});

  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    // 始终开启（不可点击）：active 视觉但无交互，表明这是状态而非开关
    return const _ToolChip(
      icon: null,
      label: '深度思考（默认）',
      active: true,
      onPressed: null,
    );
  }
}

/// 深度思考开关 chip，与 `_WebSearchToggle` 镜像
class _DeepThinkingToggle extends StatelessWidget {
  const _DeepThinkingToggle({
    required this.enabled,
    required this.supported,
    required this.isStreaming,
    required this.onToggle,
  });

  final bool enabled;
  final bool supported;
  final bool isStreaming;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _ToolChip(
      icon: null,
      label: supported ? l10n.deepThinking : l10n.deepThinkingNotSupported,
      active: enabled && supported,
      onPressed: supported && !isStreaming ? onToggle : null,
    );
  }
}

/// 图片预览条（玻璃壳内顶部，透明底 + hair 分隔）
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.imageData,
    required this.onRemove,
  });

  final Uint8List imageData;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              imageData,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '图片已选择',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            minimumSize: const Size(32, 32),
            onPressed: onRemove,
            child: Icon(
              AppIcons.close,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 输入 / 工具 / 圆钮共用毛玻璃壳：比 Kimi 更透（强 blur + 低 alpha）。
///
/// 背后必须是消息列表像素（chat_screen Stack 叠层）；
/// 工具文字必须包在此壳内，禁止裸字叠气泡。
class _ComposerGlassShell extends StatelessWidget {
  const _ComposerGlassShell({
    required this.child,
    required this.borderRadius,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// ~22% 暖白；靠 blur 保可读，避免「实心白块」（token 见 AppGlass）
  static const _fill = AppGlass.composerFill;
  static const _blur = AppGlass.composerBlurSigma;
  static const _stroke = AppGlass.composerStroke;

  @override
  Widget build(BuildContext context) {
    if (!AppGlass.useBlur) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppGlass.fillOpaque.withValues(alpha: 0.96),
          borderRadius: borderRadius,
          border: Border.all(color: AppColors.border),
          boxShadow: AppSurfaces.cardShadowSm,
        ),
        child: ClipRRect(borderRadius: borderRadius, child: child),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: AppSurfaces.cardShadowSm,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _fill,
              borderRadius: borderRadius,
              border: Border.all(
                color: _stroke,
                width: AppSp.dividerThickness,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
