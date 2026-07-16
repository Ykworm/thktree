import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
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
    // 底边留给 SafeArea/tab；此处只留输入区与 tab 玻璃之间的呼吸间距
    final showTools = widget.onWebSearchToggle != null ||
        widget.onDeepThinkingToggle != null ||
        widget.alwaysThinking;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 图片预览条（在输入框上方）
          if (widget.selectedImageData != null) ...[
            _ImagePreview(
              imageData: widget.selectedImageData!,
              onRemove: widget.onImageRemove!,
            ),
            const SizedBox(height: 6),
          ],
          // 主输入行：[+ 附图片] [输入框] [碎片] [发送]
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.onImagePick != null) ...[
                _AttachPlusButton(
                  supported: widget.imageSupported,
                  isStreaming: widget.isStreaming,
                  onPick: widget.onImagePick!,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (!widget.enabled) return KeyEventResult.ignored;
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
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
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.border,
                        width: AppSp.dividerThickness,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    onSubmitted: (_) {
                      final composing = _controller.value.composing;
                      if (composing.isValid && !composing.isCollapsed) return;
                      if (HardwareKeyboard.instance.isShiftPressed ||
                          HardwareKeyboard.instance.isControlPressed) {
                        return;
                      }
                      _send();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _RoundIconButton(
                onPressed: _openClipsSheet,
                child: Icon(
                  AppIcons.clips,
                  size: 20,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 6),
              _RoundIconButton(
                buttonKey: ValueKey(
                  widget.isStreaming ? 'stop_button' : 'send_button',
                ),
                onPressed: widget.enabled
                    ? widget.isStreaming
                        ? _stopStreaming
                        : _send
                    : null,
                child: Icon(
                  widget.isStreaming ? AppIcons.stop : AppIcons.send,
                  size: 20,
                  color: widget.enabled
                      ? AppColors.accent
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
          // 仅联网 / 深度思考（图片已迁到输入行 +）
          if (showTools) ...[
            const SizedBox(height: 6),
            // 半透明条：让底下 tab 玻璃透出来，避免实心白条压住磨砂
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.8),
                  width: AppSp.dividerThickness,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    if (widget.onWebSearchToggle != null) ...[
                      _WebSearchToggle(
                        enabled: widget.webSearchEnabled,
                        supported: widget.webSearchSupported,
                        isStreaming: widget.isStreaming,
                        onToggle: widget.onWebSearchToggle!,
                      ),
                      if (widget.alwaysThinking ||
                          widget.onDeepThinkingToggle != null)
                        _barDivider,
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
            ),
          ],
        ],
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

/// 统一底边栏内部的分隔线
final Widget _barDivider = SizedBox(
  width: 1,
  height: 20,
  child: DecoratedBox(
    decoration: BoxDecoration(color: AppColors.border),
  ),
);

/// 联网搜索开关（紧凑横条，放在输入框下方）
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
    final color = supported
        ? (enabled ? AppColors.accent : AppColors.textTertiary)
        : AppColors.textTertiary.withValues(alpha: 0.5);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onPressed: supported && !isStreaming ? onToggle : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? AppIcons.globe : AppIcons.globeSlash,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            supported
                ? (enabled ? '联网搜索' : '联网搜索')
                : '不支持联网',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

/// 深度思考开关（联网搜索右边，UI 与 web search 镜像）
///
/// 与 `_WebSearchToggle` 的核心区别是文案/icon：
/// - enabled：紫色 + 大脑 icon + "深度思考"
/// - disabled (但 supported)：灰色 + 大脑 icon 暗淡 + "深度思考"
/// - 不支持当前模型：灰色 "不支持深度思考"，按下不响应
class _AlwaysThinkingIndicator extends StatelessWidget {
  const _AlwaysThinkingIndicator({required this.isStreaming});

  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    // 始终开启（不可点击），弱化色让用户知道这是只读状态而非可操作控件
    final color = AppColors.textTertiary.withValues(alpha: 0.5);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onPressed: null, // 只读，永远 disabled
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.brain,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '深度思考（默认）',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

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
    final color = supported
        ? (enabled ? AppColors.accent : AppColors.textTertiary)
        : AppColors.textTertiary.withValues(alpha: 0.5);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onPressed: supported && !isStreaming ? onToggle : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.brain,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            supported
                ? (enabled ? '深度思考' : '深度思考')
                : '不支持深度思考',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

/// 图片预览条（输入框上方）
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.imageData,
    required this.onRemove,
  });

  final Uint8List imageData;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSp.imagePreviewHeight,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSp.cardRadius),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSp.cardRadius),
            child: Image.memory(
              imageData,
              width: AppSp.imagePreviewHeight,
              height: AppSp.imagePreviewHeight,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '图片已选择',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onRemove,
            child: Icon(
              AppIcons.close,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 输入行左侧「+」：打开图片选择（拍照/相册）。
class _AttachPlusButton extends StatelessWidget {
  const _AttachPlusButton({
    required this.supported,
    required this.isStreaming,
    required this.onPick,
  });

  final bool supported;
  final bool isStreaming;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final enabled = supported && !isStreaming;
    return _RoundIconButton(
      buttonKey: const ValueKey('attach_image_button'),
      onPressed: enabled ? onPick : null,
      child: Icon(
        AppIcons.add,
        size: 22,
        color: enabled ? AppColors.accent : AppColors.textTertiary,
      ),
    );
  }
}

/// 与输入框同高感的圆形/圆角图标钮（碎片、发送、+）。
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.child,
    this.onPressed,
    this.buttonKey,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border,
          width: AppSp.dividerThickness,
        ),
      ),
      child: CupertinoButton(
        key: buttonKey,
        padding: const EdgeInsets.all(10),
        minimumSize: const Size(40, 40),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
