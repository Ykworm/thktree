import 'package:flutter/cupertino.dart';

/// iOS 风格警告对话框封装，简化 [CupertinoAlertDialog] 的调用。
///
/// 提供 [ThkAlert.show] 和 [ThkAlert.confirm] 两种快捷方式。
///
/// 示例：
/// ```dart
/// ThkAlert.show(
///   context: context,
///   title: '删除确认',
///   message: '确定要删除这个对话吗？',
///   destructiveAction: '删除',
///   onDestructive: () => delete(),
/// );
///
/// ThkAlert.confirm(
///   context: context,
///   title: '保存更改？',
///   onConfirm: () => save(),
/// );
/// ```
class ThkAlert {
  ThkAlert._();

  /// 显示一个可自定义的警告对话框。
  ///
  /// [destructiveAction] 会显示为红色按钮（破坏性操作）。
  /// [defaultAction] 为蓝色默认按钮。
  /// [cancelAction] 为取消按钮。
  static Future<void> show({
    required BuildContext context,
    String? title,
    String? message,
    String? destructiveAction,
    VoidCallback? onDestructive,
    String? defaultAction,
    VoidCallback? onDefault,
    String cancelAction = '取消',
    VoidCallback? onCancel,
    bool barrierDismissible = true,
  }) async {
    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: title != null ? Text(title) : null,
        content: message != null ? Text(message) : null,
        actions: [
          if (destructiveAction != null)
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDestructive?.call();
              },
              child: Text(destructiveAction),
            ),
          if (defaultAction != null)
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDefault?.call();
              },
              child: Text(defaultAction),
            ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onCancel?.call();
            },
            child: Text(cancelAction),
          ),
        ],
      ),
    );
  }

  /// 显示一个确认/取消双按钮对话框。
  ///
  /// [confirmAction] 为确认按钮（蓝色），[cancelAction] 为取消按钮。
  static Future<void> confirm({
    required BuildContext context,
    String? title,
    String? message,
    String confirmAction = '确认',
    String cancelAction = '取消',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
  }) async {
    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: title != null ? Text(title) : null,
        content: message != null ? Text(message) : null,
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onCancel?.call();
            },
            child: Text(cancelAction),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onConfirm?.call();
            },
            child: Text(confirmAction),
          ),
        ],
      ),
    );
  }
}
