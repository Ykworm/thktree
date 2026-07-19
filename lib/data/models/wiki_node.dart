import 'package:thk_tree/data/services/session_markdown.dart';

/// Wiki 消息条目。
///
/// 从 [SessionMessage] 派生，但去掉了 App 内部状态（streaming/error）与
/// 不适合阅读视图的元数据（msgId、modelId 等）。
class WikiMessage {
  const WikiMessage({
    required this.role,
    required this.timestampUtcIso8601,
    required this.body,
    this.reasoning,
    this.imagePath,
  });

  final SessionRole role;
  final String timestampUtcIso8601;
  final String body;
  final String? reasoning;
  final String? imagePath;
}

/// Wiki 节点。
///
/// 与 [NodeEntity] 一一对应，但按阅读场景重新组织：保留层级关系、
/// 节点标题、以及过滤后的消息列表。
class WikiNode {
  const WikiNode({
    required this.nodeId,
    required this.title,
    required this.depth,
    required this.messages,
    required this.children,
  });

  final String nodeId;
  final String title;

  /// 在 tree 中的深度（根节点 = 1）。
  final int depth;

  final List<WikiMessage> messages;
  final List<WikiNode> children;

  /// 按 Markdown heading 层级（H1~H6）返回节点标题对应的级别。
  int get headingLevel => depth.clamp(1, 6);
}

/// 单个 theme 的 wiki 产物。
class WikiDocument {
  const WikiDocument({
    required this.themeId,
    required this.themeTitle,
    required this.root,
  });

  final String themeId;
  final String themeTitle;

  /// 虚拟根节点，depth = 0，title = themeTitle，messages 为空。
  /// 实际章节内容在其 [WikiNode.children] 中。
  final WikiNode root;

  /// 按深度优先遍历所有节点（不含虚拟根）。
  List<WikiNode> flatten() {
    final result = <WikiNode>[];
    void walk(WikiNode node) {
      for (final child in node.children) {
        result.add(child);
        walk(child);
      }
    }
    walk(root);
    return result;
  }
}
