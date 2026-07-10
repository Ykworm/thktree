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

/// 从「活跃选区」直接分支的回调持有者。
///
/// 由 chat_screen 在挂载时写入（指向其 `_branchFromSelection`），卸载时清空。
/// 选区工具栏的「分支」按钮读取它，从而能在选区仍活跃时即时分支，
/// 而不依赖 [currentSelectionProvider] 的残留值（那是为了支持"选中→分享为图片"
/// 等选区收起后仍要用的场景而故意保留的）。
///
/// 用 provider 而非 widget 回调透传，是为了避免向嵌套的 SelectionArea
/// （消息体 / 推理区 / 表格等）逐个透传函数字段——那些子 widget 多为
/// `const` 构造，持有函数字段会破坏 `const`。
final branchFromSelectionProvider =
    NotifierProvider<BranchFromSelectionNotifier, void Function(String)?>(
  BranchFromSelectionNotifier.new,
);

class BranchFromSelectionNotifier extends Notifier<void Function(String)?> {
  @override
  void Function(String)? build() => null;
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
