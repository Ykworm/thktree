/// 启动 [ChatScreen] 时通过 GoRouter `extra` 传递的参数。
///
/// [autoTriggerReply] 为 true 时，chat 加载完且最后一条消息是 user 消息时
/// 会自动调一次 LLM（用于"笔记→对话自动续聊"和"summary 流程"）。
class ChatScreenLaunchParams {
  const ChatScreenLaunchParams({
    required this.title,
    this.autoTriggerReply = false,
    this.isDocSplit = false,
  });

  /// 显示在 nav bar 中的标题。
  final String title;

  /// 是否在初始化完成后自动调一次 LLM。
  final bool autoTriggerReply;

  final bool isDocSplit;
}
