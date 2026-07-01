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

  String _deriveRootTitle(String sourceMdText) {
    final lines = sourceMdText.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final normalized = line
          .replaceFirst(RegExp(r'^#+\s*'), '')
          .replaceAll(RegExp(r'^\*\*|\*\*$'), '')
          .replaceAll(RegExp(r'^[-*]\s+'), '')
          .trim();
      if (normalized.isEmpty) continue;
      return normalized.length <= 30
          ? normalized
          : '${normalized.substring(0, 30)}...';
    }
    return 'Imported Document';
  }

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

    final rootNode = await nodeStore.createChatNode(
      themeId: themeId,
      themePath: themePath,
      parentId: null,
      title: _deriveRootTitle(sourceMdText),
    );
    await sessionStore.appendUserMessage(
      nodeId: rootNode.nodeId,
      content: trimmedSource.isEmpty ? sourceExcerpt : sourceMdText,
    );
    await nodeStore.updateNodeSourceInfo(
      nodeId: rootNode.nodeId,
      sourceExcerpt: sourceExcerpt,
      sourceType: 'docSplit',
    );
    createdCount++;

    for (final parsed in flatNodes) {
      while (stack.isNotEmpty && stack.last.$1 >= parsed.depth) {
        stack.removeLast();
      }

      final String parentId =
          stack.isNotEmpty && stack.last.$1 < parsed.depth
          ? stack.last.$2
          : rootNode.nodeId;

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
