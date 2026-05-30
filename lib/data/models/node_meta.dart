import 'dart:convert';

import 'package:thk_tree/domain/node.dart';

class NodeMetaV1 {
  NodeMetaV1({
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

  Map<String, Object?> toJson() {
    return {
      'schema': 'node_meta/v1',
      'themeId': themeId,
      'nodeId': nodeId,
      'parentId': parentId,
      'kind': kind.value,
      'title': title,
      'createdAt': createdAtUtcIso8601,
      'updatedAt': updatedAtUtcIso8601,
    };
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  static NodeMetaV1 fromJson(Map<String, Object?> json) {
    return switch (json) {
      {
        'schema': 'node_meta/v1',
        'themeId': String themeId,
        'nodeId': String nodeId,
        'parentId': String? parentId,
        'kind': String kind,
        'title': String title,
        'createdAt': String createdAt,
        'updatedAt': String updatedAt,
      } =>
        NodeMetaV1(
          themeId: themeId,
          nodeId: nodeId,
          parentId: parentId,
          kind: switch (kind) {
            'chat' => NodeKind.chat,
            'summary' => NodeKind.summary,
            _ => throw FormatException('Unknown node kind: $kind'),
          },
          title: title,
          createdAtUtcIso8601: createdAt,
          updatedAtUtcIso8601: updatedAt,
        ),
      {'schema': final schema} =>
        throw FormatException('Unexpected schema: $schema'),
      _ => throw const FormatException('Invalid node meta fields'),
    };
  }

  NodeEntity toEntity() {
    return NodeEntity(
      themeId: themeId,
      nodeId: nodeId,
      parentId: parentId,
      kind: kind,
      title: title,
      createdAtUtcIso8601: createdAtUtcIso8601,
      updatedAtUtcIso8601: updatedAtUtcIso8601,
    );
  }
}

