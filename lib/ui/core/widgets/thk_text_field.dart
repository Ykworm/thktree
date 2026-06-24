import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// iOS 风格文本输入框，基于 [CupertinoTextField]。
class ThkTextField extends StatelessWidget {
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

  final String? placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefix;
  final Widget? suffix;
  final OverlayVisibilityMode clearButtonMode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextAlign textAlign;
  final TextStyle? style;
  final TextStyle? placeholderStyle;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveBackground = backgroundColor ?? AppColors.surfaceMuted;

    return CupertinoTextField(
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
          TextStyle(color: AppColors.textTertiary),
      padding: padding,
      enableInteractiveSelection: true,
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}
