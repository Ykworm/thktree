import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.hintText,
    required this.isStreaming,
    required this.onSend,
    required this.onStopStreaming,
    this.enabled = true,
    this.onModelSelectorTap,
  });

  final String hintText;
  final bool isStreaming;
  final bool enabled;
  final Future<void> Function(String text) onSend;
  final Future<void> Function() onStopStreaming;

  /// 点击模型选择按钮的回调（可选，向后兼容）
  final VoidCallback? onModelSelectorTap;

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
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
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
                child: TextField(
                  controller: _controller,
                  focusNode: _inputFocusNode,
                  enabled: widget.enabled,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    border: const OutlineInputBorder(),
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
            if (widget.onModelSelectorTap != null) ...[
              IconButton(
                onPressed: widget.isStreaming ? null : widget.onModelSelectorTap,
                icon: Icon(
                  Icons.auto_awesome,
                  color: widget.isStreaming
                      ? Theme.of(context).disabledColor
                      : null,
                ),
                tooltip: 'Model',
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
            ],
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.enabled
                  ? widget.isStreaming
                      ? _stopStreaming
                      : _send
                  : null,
              child: Text(widget.isStreaming ? l10n.stop : l10n.send),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    try {
      await widget.onSend(text);
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    } catch (e) {
      _controller.text = text;
      if (mounted) {
        _inputFocusNode.requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _stopStreaming() async {
    try {
      await widget.onStopStreaming();
    } catch (e) {
      // 用户主动取消是正常操作，不显示错误
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
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
