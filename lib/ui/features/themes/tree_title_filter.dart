import 'package:thk_tree/domain/node.dart';

/// 按节点 [NodeEntity.title] 做树内过滤。
///
/// - [query] 去空白后为空 → 返回 `null`（不过滤，展示整树）
/// - 否则返回「标题命中 ∪ 命中节点祖先」的 nodeId 集合
///
/// 匹配：不区分大小写的 substring（`contains`），不搜消息/副标题。
Set<String>? visibleNodeIdsForTitleQuery(
  List<NodeEntity> nodes,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return null;

  final byId = <String, NodeEntity>{
    for (final n in nodes) n.nodeId: n,
  };
  final visible = <String>{};

  for (final n in nodes) {
    if (!n.title.toLowerCase().contains(q)) continue;

    var cursor = n;
    while (true) {
      if (!visible.add(cursor.nodeId)) break;
      final parentId = cursor.parentId;
      if (parentId == null) break;
      final parent = byId[parentId];
      if (parent == null) break;
      cursor = parent;
    }
  }

  return visible;
}
