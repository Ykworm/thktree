class NodeKind {
  const NodeKind._(this.value);

  final String value;

  static const chat = NodeKind._('chat');
  static const summary = NodeKind._('summary');
}

/// 节点树最大嵌套深度（按节点层级计，根节点=第 1 层）。
///
/// 面包屑固定显示的两段（主题 Tab / 主题名）不计入此深度。
/// 所有新建节点都汇流到 [NodeStore.createChatNode]，深度校验在那里统一把关；
/// reparent / 移动到新父节点时也用同一套 helper 计算，确保一致。
const int kMaxNodeDepth = 4;

/// 沿 parentId 链回溯，计算 [nodeId] 在树中的深度（根=1）。
///
/// [byId] 应为 nodeId → [NodeEntity] 的全量映射。遇环或缺失父节点时，
/// 以当前可达链长作为深度（不抛异常，便于对脏数据兜底）。
int computeNodeDepth(Map<String, NodeEntity> byId, String nodeId) {
  var depth = 1;
  var cursor = byId[nodeId];
  final visited = <String>{};
  while (cursor?.parentId != null) {
    if (!visited.add(cursor!.nodeId)) break; // 防环
    final parent = byId[cursor.parentId];
    if (parent == null) break;
    cursor = parent;
    depth += 1;
  }
  return depth;
}

/// 创建 / 移动节点时，若会超过 [kMaxNodeDepth] 则抛出。
///
/// UI 捕获后展示友好文案（如「已达最大层级」），而非崩溃。
class MaxNodeDepthExceededException implements Exception {
  const MaxNodeDepthExceededException(this.depth);

  /// 尝试创建 / 移动后将会达到的层级（= parent 深度 + 1）。
  final int depth;

  @override
  String toString() =>
      'MaxNodeDepthExceededException: node depth would exceed $kMaxNodeDepth (got $depth)';
}

class NodeEntity {
  NodeEntity({
    required this.themeId,
    required this.nodeId,
    required this.parentId,
    required this.kind,
    required this.title,
    required this.createdAtUtcIso8601,
    required this.updatedAtUtcIso8601,
    required this.sortOrder,
    this.sourceExcerpt,
    this.sourceType,
    this.lastMessagePreview,
  });

  final String themeId;
  final String nodeId;
  final String? parentId;
  final NodeKind kind;
  final String title;
  final String createdAtUtcIso8601;
  final String updatedAtUtcIso8601;

  /// DB-only: branch source excerpt (first ~80 chars of the source content)
  final String? sourceExcerpt;

  /// DB-only: branch source type label key
  /// ("selectedText" | "conversation" | "summary" | "note")
  final String? sourceType;

  /// DB-only: manual sort order within same parent (lower = earlier)
  final int sortOrder;

  /// Populated by controller: last user message preview (first ~40 chars)
  final String? lastMessagePreview;
}

