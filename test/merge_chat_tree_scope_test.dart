import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/ui/features/themes/merge_chat_tree_scope.dart';

NodeEntity _node(String id, String? parentId, [int sortOrder = 0]) => NodeEntity(
      themeId: 't1',
      nodeId: id,
      parentId: parentId,
      kind: NodeKind.chat,
      title: id,
      createdAtUtcIso8601: '2026-01-01T00:00:00Z',
      updatedAtUtcIso8601: '2026-01-01T00:00:00Z',
      sortOrder: sortOrder,
    );

void main() {
  // A theme with TWO trees:
  //   Tree A: rootA -> a1 -> a2
  //   Tree B: rootB -> b1 -> b2
  final all = [
    _node('rootA', null),
    _node('a1', 'rootA'),
    _node('a2', 'a1'),
    _node('rootB', null),
    _node('b1', 'rootB'),
    _node('b2', 'b1'),
  ];

  group('chat-page merge entry stays inside the current tree', () {
    test('currentTreeRootIdOf walks up from a descendant to rootA', () {
      final selected = [_node('a2', 'a1')];
      expect(currentTreeRootIdOf(all, selected), 'rootA');
    });

    test('currentTreeRootIdOf returns null when nothing is selected', () {
      expect(currentTreeRootIdOf(all, []), isNull);
    });

    test('subTreeNodes(rootA) contains only Tree A nodes', () {
      final ids = {for (final n in subTreeNodes(all, 'rootA')) n.nodeId};
      expect(ids, {'rootA', 'a1', 'a2'});
      // Tree B must never leak in.
      expect(ids.contains('rootB'), isFalse);
      expect(ids.contains('b1'), isFalse);
      expect(ids.contains('b2'), isFalse);
    });

    test('subTreeNodes(rootB) contains only Tree B nodes', () {
      final ids = {for (final n in subTreeNodes(all, 'rootB')) n.nodeId};
      expect(ids, {'rootB', 'b1', 'b2'});
      expect(ids.contains('rootA'), isFalse);
      expect(ids.contains('a1'), isFalse);
    });

    test('directChildren(rootA) excludes Tree B entirely', () {
      final roots = directChildren(all, 'rootA').map((n) => n.nodeId).toList();
      expect(roots, ['a1']);
      expect(roots.contains('b1'), isFalse);
    });

    test('a cross-tree node (b1) is never selectable within Tree A', () {
      final subIds = {for (final n in subTreeNodes(all, 'rootA')) n.nodeId};
      // Simulates the _submit guard: b1 is not in the current tree -> rejected.
      expect(subIds.contains('b1'), isFalse);
    });
  });
}
