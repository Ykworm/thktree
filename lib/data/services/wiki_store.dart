import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:thk_tree/data/models/wiki_node.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/wiki_service.dart';
import 'package:thk_tree/domain/node.dart';

/// Wiki 快照存储。
///
/// 负责把 theme 下的单个 tree（root node 及其子孙）生成到
/// `themes/{themeId}/wiki/{rootNodeId}/` 目录，以及从该目录读取快照
/// 供 App 内阅读器使用。
///
/// 真相源边界：tree/session.md 是真相源；wiki/ 是派生只读产物。
class WikiStore {
  WikiStore({required this.themeDir});

  final Directory themeDir;

  Directory get _wikiRootDir => Directory(p.join(themeDir.path, 'wiki'));

  Directory _wikiDirFor(String rootNodeId) =>
      Directory(p.join(_wikiRootDir.path, rootNodeId));

  File _metaFileFor(String rootNodeId) =>
      File(p.join(_wikiDirFor(rootNodeId).path, 'wiki.meta.json'));

  File _indexFileFor(String rootNodeId) =>
      File(p.join(_wikiDirFor(rootNodeId).path, 'index.md'));

  /// 列出当前 theme 下所有已生成 wiki 的 rootNodeId。
  Future<List<String>> listWikiRootNodeIds() async {
    if (!await _wikiRootDir.exists()) return const [];
    final entities = await _wikiRootDir.list(followLinks: false).toList();
    final result = <String>[];
    for (final entity in entities) {
      if (entity is! Directory) continue;
      final meta = File(p.join(entity.path, 'wiki.meta.json'));
      final index = File(p.join(entity.path, 'index.md'));
      if (await meta.exists() && await index.exists()) {
        result.add(p.basename(entity.path));
      }
    }
    return result;
  }

  /// 检查指定 tree 是否已生成 wiki 快照。
  Future<bool> hasWiki(String rootNodeId) async {
    return await _metaFileFor(rootNodeId).exists() &&
        await _indexFileFor(rootNodeId).exists();
  }

  /// 读取指定 tree 的 wiki 快照元数据。
  Future<WikiMeta?> readMeta(String rootNodeId) async {
    final metaFile = _metaFileFor(rootNodeId);
    if (!await metaFile.exists()) return null;
    try {
      final text = await metaFile.readAsString();
      final json = jsonDecode(text) as Map<String, Object?>;
      return WikiMeta.fromJson(json);
    } catch (e) {
      dev.log('[WikiStore] failed to read wiki meta: $e');
      return null;
    }
  }

  /// 从磁盘读取指定 tree 的 wiki 快照，重建 [WikiDocument]。
  Future<WikiDocument?> readWiki(String rootNodeId) async {
    if (!await hasWiki(rootNodeId)) return null;
    final meta = await readMeta(rootNodeId);
    if (meta == null) return null;

    final wikiDir = _wikiDirFor(rootNodeId);
    final entities = await wikiDir.list(followLinks: false).toList();
    final nodeFiles = entities
        .whereType<File>()
        .where((f) => f.path.endsWith('.md') && p.basename(f.path) != 'index.md')
        .toList();

    final nodes = <WikiNodeData>[];
    for (final file in nodeFiles) {
      try {
        final node = await _parseNodeFile(file);
        if (node != null) nodes.add(node);
      } catch (e) {
        dev.log('[WikiStore] failed to parse ${file.path}: $e');
      }
    }

    // 按 parentId 重组树
    final byId = {for (final n in nodes) n.nodeId: n};
    final childrenByParent = <String?, List<WikiNodeData>>{};
    for (final node in nodes) {
      childrenByParent
          .putIfAbsent(node.parentId, () => <WikiNodeData>[])
          .add(node);
    }
    for (final list in childrenByParent.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    WikiNode buildNode(String nodeId, String title, int depth) {
      final data = byId[nodeId];
      final children = <WikiNode>[];
      for (final child in childrenByParent[nodeId] ?? const <WikiNodeData>[]) {
        children.add(buildNode(child.nodeId, child.title, depth + 1));
      }
      return WikiNode(
        nodeId: nodeId,
        title: data?.title ?? title,
        depth: depth,
        messages: data?.messages ?? const [],
        children: children,
      );
    }

    final root = WikiNode(
      nodeId: '',
      title: meta.themeTitle,
      depth: 0,
      messages: const [],
      children: [
        for (final rootData in childrenByParent[null] ?? const <WikiNodeData>[])
          buildNode(rootData.nodeId, rootData.title, 1),
      ],
    );

    return WikiDocument(
      themeId: meta.themeId,
      themeTitle: meta.themeTitle,
      root: root,
    );
  }

  /// 从单个 tree 生成 wiki 快照。
  ///
  /// [rootNodeId] 指定要转换的 tree 的根节点。
  /// [themeId] / [themeTitle] 用于元数据。
  /// [nodes] 为该 root node 及其全部子孙节点。
  /// [readSession] 用于读取每个节点的 session.md。
  /// [resolveImagePath] 把 session 中的相对图片路径解析为绝对路径。
  Future<WikiDocument> generateWiki({
    required String rootNodeId,
    required String themeId,
    required String themeTitle,
    required List<NodeEntity> nodes,
    required Future<SessionDocument> Function(String nodeId) readSession,
    required Future<String?> Function(String nodeId, String imagePath)? resolveImagePath,
  }) async {
    final wikiService = const WikiService();
    final doc = await wikiService.buildWikiDocumentForTree(
      rootNodeId: rootNodeId,
      themeId: themeId,
      themeTitle: themeTitle,
      nodes: nodes,
      readSession: readSession,
    );

    final wikiDir = _wikiDirFor(rootNodeId);

    // 清空旧 wiki
    if (await wikiDir.exists()) {
      await wikiDir.delete(recursive: true);
    }
    await wikiDir.create(recursive: true);
    await Directory(p.join(wikiDir.path, 'assets')).create();

    final flatNodes = doc.flatten();
    final now = DateTime.now().toUtc().toIso8601String();

    // 1. 写每个节点文件
    for (final node in flatNodes) {
      final file = File(p.join(wikiDir.path, '${node.nodeId}.md'));
      final buffer = StringBuffer()
        ..writeln('---')
        ..writeln('schema: wiki_node/v1')
        ..writeln('nodeId: "${node.nodeId}"')
        ..writeln('title: "${_escapeYaml(node.title)}"')
        ..writeln('depth: ${node.depth}')
        ..writeln('parentId: ${node.depth == 1 ? 'null' : '"${_findParentId(flatNodes, node.nodeId)}"'}')
        ..writeln('sortOrder: ${_findSortOrder(nodes, node.nodeId)}')
        ..writeln('---')
        ..writeln();

      for (final message in node.messages) {
        final role = switch (message.role) {
          SessionRole.user => 'user',
          SessionRole.assistant => 'assistant',
          SessionRole.system => 'system',
        };
        buffer.writeln('## $role');
        buffer.writeln();
        buffer.writeln(message.body.trim());
        buffer.writeln();

        if (message.reasoning != null && message.reasoning!.isNotEmpty) {
          buffer.writeln('<!-- reasoning:start -->');
          buffer.writeln(message.reasoning!.trim());
          buffer.writeln('<!-- reasoning:end -->');
          buffer.writeln();
        }

        if (message.imagePath != null && resolveImagePath != null) {
          final srcPath = await resolveImagePath(node.nodeId, message.imagePath!);
          if (srcPath != null) {
            final srcFile = File(srcPath);
            if (await srcFile.exists()) {
              final ext = p.extension(srcPath);
              final assetName = '${node.nodeId}$ext';
              final destPath = p.join(wikiDir.path, 'assets', assetName);
              await srcFile.copy(destPath);
              buffer.writeln('![image](assets/$assetName)');
              buffer.writeln();
            }
          }
        }
      }

      await file.writeAsString(buffer.toString());
    }

    // 2. 写 index.md
    final indexBuffer = StringBuffer()
      ..writeln('---')
      ..writeln('schema: wiki_index/v1')
      ..writeln('themeId: "$themeId"')
      ..writeln('themeTitle: "${_escapeYaml(themeTitle)}"')
      ..writeln('rootNodeId: "$rootNodeId"')
      ..writeln('generatedAt: "$now"')
      ..writeln('---')
      ..writeln()
      ..writeln('# $themeTitle')
      ..writeln()
      ..writeln('## 目录')
      ..writeln();

    void writeToc(WikiNode node, int indent) {
      for (final child in node.children) {
        indexBuffer.writeln('${'  ' * indent}- [${child.title}](${child.nodeId}.md)');
        writeToc(child, indent + 1);
      }
    }
    writeToc(doc.root, 0);

    await _indexFileFor(rootNodeId).writeAsString(indexBuffer.toString());

    // 3. 写 meta
    final meta = WikiMeta(
      schema: 'wiki_meta/v1',
      themeId: themeId,
      themeTitle: themeTitle,
      rootNodeId: rootNodeId,
      generatedAt: now,
      sourceUpdatedAt: _latestNodeUpdatedAt(nodes),
      nodeCount: flatNodes.length,
    );
    await _metaFileFor(rootNodeId).writeAsString(jsonEncode(meta.toJson()));

    return doc;
  }

  /// 删除指定 tree 的 wiki 快照。
  Future<void> deleteWiki(String rootNodeId) async {
    final wikiDir = _wikiDirFor(rootNodeId);
    if (await wikiDir.exists()) {
      await wikiDir.delete(recursive: true);
    }
  }

  String? _findParentId(List<WikiNode> nodes, String nodeId) {
    for (final node in nodes) {
      for (final child in node.children) {
        if (child.nodeId == nodeId) return node.nodeId;
      }
    }
    return null;
  }

  int _findSortOrder(List<NodeEntity> nodes, String nodeId) {
    for (final node in nodes) {
      if (node.nodeId == nodeId) return node.sortOrder;
    }
    return 0;
  }

  String _latestNodeUpdatedAt(List<NodeEntity> nodes) {
    if (nodes.isEmpty) return DateTime.now().toUtc().toIso8601String();
    return nodes
        .map((n) => n.updatedAtUtcIso8601)
        .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
  }

  String _escapeYaml(String value) {
    return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }

  Future<WikiNodeData?> _parseNodeFile(File file) async {
    final text = await file.readAsString();
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // frontmatter
    if (!normalized.startsWith('---\n')) return null;
    final endIndex = normalized.indexOf('\n---\n', 4);
    if (endIndex < 0) return null;

    final yamlText = normalized.substring(4, endIndex + 1);
    final body = normalized.substring(endIndex + 5);

    final frontmatter = <String, Object?>{};
    for (final line in yamlText.split('\n')) {
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final key = line.substring(0, colon).trim();
      var value = line.substring(colon + 1).trim();
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      frontmatter[key] = value;
    }

    if (frontmatter['schema'] != 'wiki_node/v1') return null;

    final nodeId = frontmatter['nodeId'] as String?;
    final title = frontmatter['title'] as String?;
    final depthStr = frontmatter['depth'] as String?;
    final parentId = frontmatter['parentId'] as String?;
    final sortOrderStr = frontmatter['sortOrder'] as String?;

    if (nodeId == null || title == null) return null;

    final messages = <WikiMessage>[];
    final lines = body.split('\n');
    String? currentRole;
    final currentBody = <String>[];

    void flush() {
      if (currentRole == null || currentBody.isEmpty) return;
      final role = switch (currentRole) {
        'user' => SessionRole.user,
        'assistant' => SessionRole.assistant,
        _ => SessionRole.system,
      };
      messages.add(WikiMessage(
        role: role,
        timestampUtcIso8601: '',
        body: currentBody.join('\n').trim(),
      ));
      currentBody.clear();
    }

    for (final line in lines) {
      if (line.startsWith('## ')) {
        flush();
        currentRole = line.substring(3).trim();
      } else if (line.startsWith('<!-- reasoning:start -->')) {
        // skip reasoning markers for now
      } else if (line.startsWith('<!-- reasoning:end -->')) {
        // skip reasoning markers for now
      } else {
        currentBody.add(line);
      }
    }
    flush();

    return WikiNodeData(
      nodeId: nodeId,
      title: title,
      depth: int.tryParse(depthStr ?? '') ?? 1,
      parentId: parentId == 'null' ? null : parentId,
      sortOrder: int.tryParse(sortOrderStr ?? '') ?? 0,
      messages: messages,
    );
  }
}

/// Wiki 快照元数据。
class WikiMeta {
  const WikiMeta({
    required this.schema,
    required this.themeId,
    required this.themeTitle,
    required this.rootNodeId,
    required this.generatedAt,
    required this.sourceUpdatedAt,
    required this.nodeCount,
  });

  final String schema;
  final String themeId;
  final String themeTitle;
  final String rootNodeId;
  final String generatedAt;
  final String sourceUpdatedAt;
  final int nodeCount;

  Map<String, Object?> toJson() => {
        'schema': schema,
        'themeId': themeId,
        'themeTitle': themeTitle,
        'rootNodeId': rootNodeId,
        'generatedAt': generatedAt,
        'sourceUpdatedAt': sourceUpdatedAt,
        'nodeCount': nodeCount,
      };

  factory WikiMeta.fromJson(Map<String, Object?> json) {
    return WikiMeta(
      schema: json['schema']! as String,
      themeId: json['themeId']! as String,
      themeTitle: json['themeTitle']! as String,
      rootNodeId: json['rootNodeId']! as String,
      generatedAt: json['generatedAt']! as String,
      sourceUpdatedAt: json['sourceUpdatedAt']! as String,
      nodeCount: (json['nodeCount'] as num).toInt(),
    );
  }
}

/// 解析单个 wiki 节点文件后的中间结构。
class WikiNodeData {
  const WikiNodeData({
    required this.nodeId,
    required this.title,
    required this.depth,
    required this.parentId,
    required this.sortOrder,
    required this.messages,
  });

  final String nodeId;
  final String title;
  final int depth;
  final String? parentId;
  final int sortOrder;
  final List<WikiMessage> messages;
}
