import 'dart:developer' as dev;

import 'package:thk_tree/data/models/wiki_node.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/domain/node.dart';

/// 把 theme tree 转换为只读 wiki 文档。
class WikiService {
  const WikiService();

  /// 从 [nodes] 与 [readSession] 构建 [WikiDocument]（整个 theme 的全部 tree）。
  ///
  /// [themeId] 与 [themeTitle] 仅用于文档元数据。
  /// [readSession] 负责按 [nodeId] 读取并解析 session.md。
  Future<WikiDocument> buildWikiDocument({
    required String themeId,
    required String themeTitle,
    required List<NodeEntity> nodes,
    required Future<SessionDocument> Function(String nodeId) readSession,
  }) async {
    // 1. 按 parentId 建立索引。
    final byId = {for (final n in nodes) n.nodeId: n};
    final childrenByParent = <String?, List<NodeEntity>>{};
    for (final node in nodes) {
      childrenByParent
          .putIfAbsent(node.parentId, () => <NodeEntity>[])
          .add(node);
    }
    for (final list in childrenByParent.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // 2. 递归构建 wiki 树。
    final root = await _buildNode(
      nodeId: '',
      title: themeTitle,
      depth: 0,
      childrenByParent: childrenByParent,
      byId: byId,
      readSession: readSession,
      isVirtualRoot: true,
    );

    return WikiDocument(
      themeId: themeId,
      themeTitle: themeTitle,
      root: root,
    );
  }

  /// 从单个 tree（[rootNodeId] 及其子孙）构建 [WikiDocument]。
  ///
  /// [nodes] 应只包含该 tree 的节点（root node + descendants）。
  Future<WikiDocument> buildWikiDocumentForTree({
    required String rootNodeId,
    required String themeId,
    required String themeTitle,
    required List<NodeEntity> nodes,
    required Future<SessionDocument> Function(String nodeId) readSession,
  }) async {
    // 1. 按 parentId 建立索引。
    final byId = {for (final n in nodes) n.nodeId: n};
    final childrenByParent = <String?, List<NodeEntity>>{};
    for (final node in nodes) {
      childrenByParent
          .putIfAbsent(node.parentId, () => <NodeEntity>[])
          .add(node);
    }
    for (final list in childrenByParent.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // 2. 找到 root node，以其为起点构建。
    final rootEntity = byId[rootNodeId];
    if (rootEntity == null) {
      throw StateError('Root node not found: $rootNodeId');
    }

    final root = await _buildNode(
      nodeId: rootEntity.nodeId,
      title: rootEntity.title,
      depth: 1,
      childrenByParent: childrenByParent,
      byId: byId,
      readSession: readSession,
    );

    // 包装一层虚拟根，保持与 buildWikiDocument 一致的结构。
    final virtualRoot = WikiNode(
      nodeId: '',
      title: themeTitle,
      depth: 0,
      messages: const [],
      children: [root],
    );

    return WikiDocument(
      themeId: themeId,
      themeTitle: themeTitle,
      root: virtualRoot,
    );
  }

  Future<WikiNode> _buildNode({
    required String nodeId,
    required String title,
    required int depth,
    required Map<String?, List<NodeEntity>> childrenByParent,
    required Map<String, NodeEntity> byId,
    required Future<SessionDocument> Function(String nodeId) readSession,
    bool isVirtualRoot = false,
  }) async {
    List<WikiMessage> messages = const [];

    // 只有真实节点才读取 session；虚拟根节点 messages 为空。
    if (!isVirtualRoot && nodeId.isNotEmpty) {
      try {
        final doc = await readSession(nodeId);
        messages = _toWikiMessages(doc.messages);
      } catch (e, st) {
        dev.log('[WikiService] failed to read session for $nodeId: $e\n$st');
        messages = const [];
      }
    }

    final children = <WikiNode>[];
    final lookupKey = isVirtualRoot ? null : nodeId;
    final childEntities = childrenByParent[lookupKey] ?? const [];
    for (final child in childEntities) {
      children.add(await _buildNode(
        nodeId: child.nodeId,
        title: child.title,
        depth: depth + 1,
        childrenByParent: childrenByParent,
        byId: byId,
        readSession: readSession,
      ));
    }

    return WikiNode(
      nodeId: nodeId,
      title: title,
      depth: depth,
      messages: messages,
      children: children,
    );
  }

  /// 过滤并转换消息。
  ///
  /// - 过滤 system 消息（通常为隐藏 system prompt）。
  /// - 过滤未完成（streaming）或失败（error）的 assistant 消息。
  /// - 保留 user 与成功 assistant 消息。
  List<WikiMessage> _toWikiMessages(List<SessionMessage> messages) {
    return messages.where((m) {
      if (m.role == SessionRole.system) return false;
      if (m.role == SessionRole.assistant) {
        if (m.status == SessionMessageStatus.streaming) return false;
        if (m.status == SessionMessageStatus.error) return false;
        if (m.status == SessionMessageStatus.interrupted) return false;
      }
      return true;
    }).map((m) {
      return WikiMessage(
        role: m.role,
        timestampUtcIso8601: m.timestampUtcIso8601,
        body: m.body,
        reasoning: m.reasoning,
        imagePath: m.imagePath,
      );
    }).toList(growable: false);
  }
}
