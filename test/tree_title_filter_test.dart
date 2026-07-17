import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/ui/features/themes/tree_title_filter.dart';

NodeEntity _node(
  String id,
  String? parentId, {
  required String title,
  int sortOrder = 0,
}) =>
    NodeEntity(
      themeId: 't1',
      nodeId: id,
      parentId: parentId,
      kind: NodeKind.chat,
      title: title,
      createdAtUtcIso8601: '2026-01-01T00:00:00Z',
      updatedAtUtcIso8601: '2026-01-01T00:00:00Z',
      sortOrder: sortOrder,
    );

void main() {
  // rootA "规划"
  //   a1 "预算讨论"
  //     a2 "Q1 明细"
  // rootB "闲聊"
  //   b1 "周末计划"
  final all = [
    _node('rootA', null, title: '规划'),
    _node('a1', 'rootA', title: '预算讨论'),
    _node('a2', 'a1', title: 'Q1 明细'),
    _node('rootB', null, title: '闲聊'),
    _node('b1', 'rootB', title: '周末计划'),
  ];

  group('visibleNodeIdsForTitleQuery', () {
    test('empty / whitespace query returns null (no filter)', () {
      expect(visibleNodeIdsForTitleQuery(all, ''), isNull);
      expect(visibleNodeIdsForTitleQuery(all, '   '), isNull);
    });

    test('match leaf keeps ancestors', () {
      final ids = visibleNodeIdsForTitleQuery(all, 'Q1');
      expect(ids, {'a2', 'a1', 'rootA'});
      expect(ids!.contains('rootB'), isFalse);
      expect(ids.contains('b1'), isFalse);
    });

    test('case-insensitive English substring', () {
      final ids = visibleNodeIdsForTitleQuery(
        [
          _node('r', null, title: 'Budget Plan'),
          _node('c', 'r', title: 'Notes'),
        ],
        'budget',
      );
      expect(ids, {'r'});
    });

    test('Chinese substring on mid node keeps root, drops siblings', () {
      final ids = visibleNodeIdsForTitleQuery(all, '预算');
      expect(ids, {'a1', 'rootA'});
      expect(ids!.contains('a2'), isFalse);
    });

    test('no match returns empty set (not null)', () {
      final ids = visibleNodeIdsForTitleQuery(all, '不存在的标题xyz');
      expect(ids, isNotNull);
      expect(ids, isEmpty);
    });

    test('multiple roots can match independently', () {
      final ids = visibleNodeIdsForTitleQuery(all, '计划');
      // b1 "周末计划" → + rootB; no other "计划"
      expect(ids, {'b1', 'rootB'});
    });
  });
}
