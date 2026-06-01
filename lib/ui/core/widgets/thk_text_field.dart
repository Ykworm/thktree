import 'package:flutter/cupertino.dart';

/// iOS 风格文本输入框，基于 [CupertinoTextField]。
///
/// 支持点击外部自动隐藏键盘、圆角边框等 iOS 风格效果。
///
/// 示例：
/// ```dart
/// ThkTextField(
///   placeholder: '输入标题',
///   controller: _controller,
///   onSubmitted: (val) => save(val),
/// )
/// ```
class ThkTextField extends StatelessWidget {
  /// 创建 iOS 风格文本输入框。
  const ThkTextField({
    super.key,
    this.placeholder,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.suffix,
    this.clearButtonMode = OverlayVisibilityMode.editing,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.textAlign = TextAlign.start,
    this.style,
    this.placeholderStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.backgroundColor,
  });

  /// 占位提示文本。
  final String? placeholder;

  /// 文本控制器。
  final TextEditingController? controller;

  /// 文本变化回调。
  final ValueChanged<String>? onChanged;

  /// 提交回调（点击键盘完成/回车）。
  final ValueChanged<String>? onSubmitted;

  /// 前缀 Widget。
  final Widget? prefix;

  /// 后缀 Widget。
  final Widget? suffix;

  /// 清除按钮显示模式。
  final OverlayVisibilityMode clearButtonMode;

  /// 是否隐藏输入（密码模式）。
  final bool obscureText;

  /// 键盘类型。
  final TextInputType? keyboardType;

  /// 键盘操作按钮类型。
  final TextInputAction? textInputAction;

  /// 最大行数。
  final int? maxLines;

  /// 最小行数。
  final int? minLines;

  /// 最大字符数。
  final int? maxLength;

  /// 是否可用。
  final bool enabled;

  /// 是否自动聚焦。
  final bool autofocus;

  /// 焦点节点。
  final FocusNode? focusNode;

  /// 文本对齐方式。
  final TextAlign textAlign;

  /// 文本样式。
  final TextStyle? style;

  /// 占位文本样式。
  final TextStyle? placeholderStyle;

  /// 内边距。
  final EdgeInsetsGeometry padding;

  /// 边框圆角。
  final BorderRadius borderRadius;

  /// 背景色。
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveBackground = backgroundColor ??
        CupertinoColors.systemGroupedBackground.resolveFrom(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        prefix: prefix,
        suffix: suffix,
        clearButtonMode: clearButtonMode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        enabled: enabled,
        autofocus: autofocus,
        focusNode: focusNode,
        textAlign: textAlign,
        style: style,
        placeholderStyle: placeholderStyle ??
            TextStyle(
              color: CupertinoColors.placeholderText.resolveFrom(context),
            ),
        padding: padding,
        decoration: BoxDecoration(
          color: effectiveBackground,
          borderRadius: borderRadius,
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
