import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 跨组件共享的当前选区文本。
///
/// 由于 chat 消息列表存在「嵌套 SelectionArea」：chat_screen 外层包了一个
/// SelectionArea，每条 MessageBubble 内部又各包了一个（GptMarkdown 自身不可选，
/// 必须靠内层 SelectionArea 才能选中）。嵌套下外层 SelectionArea 的
/// onSelectionChanged 收不到子选区，因此选区只能由内层 SelectionArea 捕获。
///
/// 这里用共享 provider 把内层捕获到的选区文本暴露给 chat_screen 的分支流程
/// 和气泡的「分享为图片」功能，避免重复捕获与状态不一致。
///
/// 约定：只在有真实选区时更新；收到空选区不要清空（保留上次有效选区），
/// 否则等真正点 branch / 分享时字段可能已被收起动作清空。
final currentSelectionProvider =
    NotifierProvider<CurrentSelectionNotifier, String?>(
  CurrentSelectionNotifier.new,
);

class CurrentSelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;
}

/// 把 SelectionArea 捕获到的选区同步进 [currentSelectionProvider]。
///
/// 写成顶层函数，避免依赖某个 State 的 `ref`，这样无论调用方是
/// _MessageBubbleState 还是内部表格组件都能直接用 `context` 写入。
void syncSelection(BuildContext context, dynamic value) {
  final text = value?.plainText as String?;
  if (text != null && text.trim().isNotEmpty) {
    ProviderScope.containerOf(context)
        .read(currentSelectionProvider.notifier)
        .state = text;
  }
}
