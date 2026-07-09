import 'package:thk_tree/domain/node.dart';

/// Helpers that keep the chat-page "merge & create" entry inside the *current
/// tree* — the sub-tree rooted at the merged chats' common root.
///
/// A [ThemeEntity] may hold multiple root nodes (= multiple trees), so a naive
/// `themeId` filter leaks other trees. These pure functions compute the
/// current tree's root and its node set, and are extracted here so the
/// restriction can be unit-tested independently of the widget.
///
/// Used by [MergeChatConfirmScreen]: when entered from a chat page
/// (`crossTree == false`) the mount-location picker must only offer nodes from
/// this single tree.

/// Root node id of the tree containing the merged chats, walking up from the
/// first selected node. Returns `null` when no selection is available.
String? currentTreeRootIdOf(List<NodeEntity> nodes, List<NodeEntity> selected) {
  if (selected.isEmpty) return null;
  final byId = <String, NodeEntity>{for (final n in nodes) n.nodeId: n};
  NodeEntity? cur = byId[selected.first.nodeId];
  while (cur != null && cur.parentId != null) {
    cur = byId[cur.parentId];
  }
  return cur?.nodeId;
}

/// All nodes in the sub-tree rooted at [rootId] (including [rootId]).
List<NodeEntity> subTreeNodes(List<NodeEntity> nodes, String rootId) {
  final byId = <String, NodeEntity>{for (final n in nodes) n.nodeId: n};
  final result = <NodeEntity>[];
  final stack = [rootId];
  final seen = <String>{};
  while (stack.isNotEmpty) {
    final id = stack.removeLast();
    if (!seen.add(id)) continue;
    final node = byId[id];
    if (node != null) {
      result.add(node);
      for (final n in nodes) {
        if (n.parentId == id) stack.add(n.nodeId);
      }
    }
  }
  return result;
}

/// Direct children of [parentId] within [nodes].
List<NodeEntity> directChildren(List<NodeEntity> nodes, String parentId) {
  return nodes.where((n) => n.parentId == parentId).toList();
}
