class NodeKind {
  const NodeKind._(this.value);

  final String value;

  static const chat = NodeKind._('chat');
  static const summary = NodeKind._('summary');
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
  });

  final String themeId;
  final String nodeId;
  final String? parentId;
  final NodeKind kind;
  final String title;
  final String createdAtUtcIso8601;
  final String updatedAtUtcIso8601;
}

