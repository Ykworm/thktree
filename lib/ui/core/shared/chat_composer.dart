import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.hintText,
    required this.isStreaming,
    required this.onSend,
    required this.onStopStreaming,
    this.enabled = true,
    this.onModelSelectorTap,
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

  /// 点击模型选择按钮的回调（可选，向后兼容）
  final VoidCallback? onModelSelectorTap;

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
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
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
            const SizedBox(height: 4),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
                    enableSuggestions: false,
                    enableInteractiveSelection: true,
                    textCapitalization: TextCapitalization.none,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    placeholder: widget.hintText,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              const SizedBox(width: 4),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CupertinoButton(
                  key: ValueKey(widget.isStreaming ? 'stop_button' : 'send_button'),
                  padding: const EdgeInsets.all(8),
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
              ),
              if (widget.onModelSelectorTap != null) ...[
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed:
                        widget.isStreaming ? null : widget.onModelSelectorTap,
                    child: Icon(
                      AppIcons.sparkles,
                      size: 20,
                      color: widget.isStreaming
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // 联网搜索、深度思考和图片按钮（输入框下方）
          if (widget.onWebSearchToggle != null ||
              widget.onDeepThinkingToggle != null ||
              widget.alwaysThinking ||
              widget.onImagePick != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (widget.onWebSearchToggle != null) ...[
                  _WebSearchToggle(
                    enabled: widget.webSearchEnabled,
                    supported: widget.webSearchSupported,
                    isStreaming: widget.isStreaming,
                    onToggle: widget.onWebSearchToggle!,
                  ),
                ],
                if (widget.alwaysThinking) ...[
                  if (widget.onWebSearchToggle != null) const SizedBox(width: 8),
                  _AlwaysThinkingIndicator(isStreaming: widget.isStreaming),
                ] else if (widget.onDeepThinkingToggle != null) ...[
                  if (widget.onWebSearchToggle != null) const SizedBox(width: 8),
                  _DeepThinkingToggle(
                    enabled: widget.deepThinkingEnabled,
                    supported: widget.deepThinkingSupported,
                    isStreaming: widget.isStreaming,
                    onToggle: widget.onDeepThinkingToggle!,
                  ),
                ],
                if (widget.onImagePick != null) ...[
                  if (widget.onWebSearchToggle != null ||
                      widget.onDeepThinkingToggle != null ||
                      widget.alwaysThinking)
                    const SizedBox(width: 8),
                  _ImageButton(
                    supported: widget.imageSupported,
                    isStreaming: widget.isStreaming,
                    onPick: widget.onImagePick!,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
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

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minSize: 0,
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
        ),
      ),
    );
  }
}

/// 深度思考开关（联网搜索右边，UI 与 web search 镜像）
///
/// 与 `_WebSearchToggle` 的核心区别是文案/icon：
/// - enabled：紫色 + 灯泡 icon + "深度思考"
/// - disabled (但 supported)：灰色 + 灯泡 icon 暗淡 + "深度思考"
/// - 不支持当前模型：灰色 "不支持深度思考"，按下不响应
class _AlwaysThinkingIndicator extends StatelessWidget {
  const _AlwaysThinkingIndicator({required this.isStreaming});

  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    // 始终开启（不可点击），弱化色让用户知道这是只读状态而非可操作控件
    final color = AppColors.textTertiary.withValues(alpha: 0.5);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minSize: 0,
          onPressed: null, // 只读，永远 disabled
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.sparkles,
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
        ),
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

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minSize: 0,
          onPressed: supported && !isStreaming ? onToggle : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.sparkles, // 与"AI / 思考"相关的 icon（与模型选择入口共用语义）
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
        ),
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
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              imageData,
              width: 80,
              height: 80,
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

/// 图片按钮（联网搜索旁边）
class _ImageButton extends StatelessWidget {
  const _ImageButton({
    required this.supported,
    required this.isStreaming,
    required this.onPick,
  });

  final bool supported;
  final bool isStreaming;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final color = supported
        ? AppColors.accent
        : AppColors.textTertiary.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minSize: 0,
        onPressed: supported && !isStreaming ? onPick : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.image,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              supported ? '添加图片' : '不支持图片',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
