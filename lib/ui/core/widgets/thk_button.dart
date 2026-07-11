import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// iOS 风格按钮，支持三种样式：filled、tinted、plain。
class ThkButton extends StatelessWidget {
  const ThkButton._({
    required this.label,
    this.onPressed,
    this.icon,
    required this._style,
    this.disabled = false,
    this.padding,
    this.borderRadius,
  });

  factory ThkButton.filled({
    required String label,
    VoidCallback? onPressed,
    Widget? icon,
    bool disabled = false,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return ThkButton._(
      label: label,
      onPressed: onPressed,
      icon: icon,
      style: ThkButtonVariant.filled,
      disabled: disabled,
      padding: padding,
      borderRadius: borderRadius,
    );
  }

  factory ThkButton.tinted({
    required String label,
    VoidCallback? onPressed,
    Widget? icon,
    bool disabled = false,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return ThkButton._(
      label: label,
      onPressed: onPressed,
      icon: icon,
      style: ThkButtonVariant.tinted,
      disabled: disabled,
      padding: padding,
      borderRadius: borderRadius,
    );
  }

  factory ThkButton.plain({
    required String label,
    VoidCallback? onPressed,
    Widget? icon,
    bool disabled = false,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return ThkButton._(
      label: label,
      onPressed: onPressed,
      icon: icon,
      style: ThkButtonVariant.plain,
      disabled: disabled,
      padding: padding,
      borderRadius: borderRadius,
    );
  }

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final ThkButtonVariant _style;
  final bool disabled;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  VoidCallback? get _effectiveOnPressed => disabled ? null : onPressed;

  Widget get _content {
    final text = Text(
      label,
      style: TextStyle(fontWeight: FontWeight.w600),
    );
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          const SizedBox(width: 4),
          text,
        ],
      );
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    switch (_style) {
      case ThkButtonVariant.filled:
        return CupertinoButton(
          padding: effectivePadding,
          borderRadius: borderRadius ?? const BorderRadius.all(Radius.circular(8)),
          color: AppColors.accent,
          disabledColor: AppColors.accentDeep.withValues(alpha: 0.4),
          onPressed: _effectiveOnPressed,
          child: DefaultTextStyle(
            style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
            child: _content,
          ),
        );
      case ThkButtonVariant.tinted:
        return CupertinoButton(
          padding: effectivePadding,
          borderRadius: borderRadius ?? const BorderRadius.all(Radius.circular(8)),
          color: AppColors.accentLight,
          disabledColor: AppColors.accentLight.withValues(alpha: 0.5),
          onPressed: _effectiveOnPressed,
          child: DefaultTextStyle(
            style: TextStyle(
              color: disabled
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
            child: _content,
          ),
        );
      case ThkButtonVariant.plain:
        return CupertinoButton(
          padding: effectivePadding,
          borderRadius: borderRadius ?? const BorderRadius.all(Radius.circular(8)),
          onPressed: _effectiveOnPressed,
          child: _content,
        );
    }
  }
}

enum ThkButtonVariant { filled, tinted, plain }
