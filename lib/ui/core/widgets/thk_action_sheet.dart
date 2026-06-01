import 'package:flutter/cupertino.dart';

/// Action Sheet 中的单个操作项。
///
/// 用于 [ThkActionSheet.show] 的 [actions] 参数。
class ThkSheetAction {
  /// 创建一个 Action Sheet 操作项。
  const ThkSheetAction({
    required this.label,
    this.icon,
    this.isDestructive = false,
    this.isDefault = false,
    required this.onPressed,
  });

  /// 操作按钮文本。
  final String label;

  /// 操作按钮图标（显示在文本左侧）。
  final IconData? icon;

  /// 是否为破坏性操作（红色样式）。
  final bool isDestructive;

  /// 是否为默认操作（加粗样式）。
  final bool isDefault;

  /// 点击回调。
  final VoidCallback onPressed;
}

/// iOS 风格 Action Sheet 封装，简化 [CupertinoActionSheet] 的调用。
///
/// 自动添加"取消"按钮，使用 [showCupertinoModalPopup] 弹出。
///
/// 示例：
/// ```dart
/// ThkActionSheet.show(
///   context: context,
///   title: '选择操作',
///   actions: [
///     ThkSheetAction(label: '复制', icon: CupertinoIcons.doc_on_doc, onPressed: copy),
///     ThkSheetAction(label: '删除', icon: CupertinoIcons.delete, isDestructive: true, onPressed: del),
///   ],
/// );
/// ```
class ThkActionSheet {
  ThkActionSheet._();

  /// 显示 Action Sheet。
  ///
  /// [title] 和 [message] 为可选的标题和说明文本。
  /// [actions] 为操作列表，每个操作项包含文本、图标、样式和回调。
  /// 自动在底部添加"取消"按钮。
  static Future<void> show({
    required BuildContext context,
    String? title,
    String? message,
    required List<ThkSheetAction> actions,
    String cancelLabel = '取消',
  }) async {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        message: message != null ? Text(message) : null,
        actions: actions.map((action) {
          return CupertinoActionSheetAction(
            isDestructiveAction: action.isDestructive,
            isDefaultAction: action.isDefault,
            onPressed: () {
              Navigator.of(context).pop();
              action.onPressed();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (action.icon != null) ...[
                  Icon(action.icon, size: 18),
                  const SizedBox(width: 6),
                ],
                Text(action.label),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }
}
