import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/tree_parser.dart';
import 'package:thk_tree/data/stores/node_store.dart';
import 'package:thk_tree/data/stores/session_store.dart';

class DocSplitService {
  DocSplitService({
    required this.nodeStore,
    required this.sessionStore,
  });

  final NodeStore nodeStore;
  final SessionStore sessionStore;

  Future<int> materializeTree({
    required String docSplitNodeId,
    required String themeId,
    required String themePath,
    required String sourceMdText,
  }) async {
    final doc = await sessionStore.readSession(docSplitNodeId);

    String? lastAssistantBody;
    for (final msg in doc.messages.reversed) {
      if (msg.role == SessionRole.assistant &&
          msg.status == SessionMessageStatus.done &&
          msg.body.trim().isNotEmpty) {
        lastAssistantBody = msg.body;
        break;
      }
    }
    if (lastAssistantBody == null) {
      return 0;
    }

    final flatNodes = parseMarkdownTree(lastAssistantBody);
    if (flatNodes.isEmpty) {
      return 0;
    }

    final stack = <(int depth, String nodeId)>[];
    var createdCount = 0;

    final trimmedSource = sourceMdText.trim();
    final sourceExcerpt = trimmedSource.length <= 80
        ? trimmedSource
        : '${trimmedSource.substring(0, 80)}...';

    for (final parsed in flatNodes) {
      while (stack.isNotEmpty && stack.last.$1 >= parsed.depth) {
        stack.removeLast();
      }

      final String? parentId =
          stack.isNotEmpty && stack.last.$1 < parsed.depth ? stack.last.$2 : null;

      final childNode = await nodeStore.createChatNode(
        themeId: themeId,
        themePath: themePath,
        parentId: parentId,
        title: parsed.title,
      );

      await sessionStore.appendUserMessage(
        nodeId: childNode.nodeId,
        content: parsed.content,
      );

      await nodeStore.updateNodeSourceInfo(
        nodeId: childNode.nodeId,
        sourceExcerpt: sourceExcerpt,
        sourceType: 'docSplit',
      );

      stack.add((parsed.depth, childNode.nodeId));
      createdCount++;
    }

    await nodeStore.deleteNodeSubtree(nodeId: docSplitNodeId);
    return createdCount;
  }
}
