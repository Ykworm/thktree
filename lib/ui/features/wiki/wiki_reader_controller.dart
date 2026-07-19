import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:thk_tree/data/models/wiki_node.dart';
import 'package:thk_tree/data/services/wiki_store.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/ui/core/app_services.dart';

/// 单个 tree 的 wiki 信息。
class TreeWikiInfo {
  const TreeWikiInfo({
    required this.rootNode,
    required this.hasWiki,
    required this.meta,
    required this.document,
  });

  final NodeEntity rootNode;
  final bool hasWiki;
  final WikiMeta? meta;
  final WikiDocument? document;
}

class WikiReaderState {
  const WikiReaderState({
    required this.trees,
    required this.selectedRootNodeId,
  });

  /// 当前 theme 下所有 root node（tree）及其 wiki 信息。
  final List<TreeWikiInfo> trees;

  /// 当前选中的 tree rootNodeId；null 表示尚未选择。
  final String? selectedRootNodeId;

  TreeWikiInfo? get selectedTree {
    if (selectedRootNodeId == null) return null;
    for (final tree in trees) {
      if (tree.rootNode.nodeId == selectedRootNodeId) return tree;
    }
    return null;
  }
}

class WikiReaderController extends AsyncNotifier<WikiReaderState> {
  WikiReaderController(this.themeId);

  final String themeId;

  @override
  Future<WikiReaderState> build() async {
    return _load();
  }

  Future<WikiReaderState> _load() async {
    final paths = await ref.watch(appPathsProvider.future);
    final nodeStore = await ref.watch(nodeStoreProvider.future);
    final themeDir = Directory(p.join(paths.themesDir.path, themeId));
    final store = WikiStore(themeDir: themeDir);

    final allNodes = await nodeStore.listNodes(themeId: themeId);
    final rootNodes = allNodes
        .where((n) => n.parentId == null)
        .toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final wikiIds = await store.listWikiRootNodeIds();

    final trees = <TreeWikiInfo>[];
    for (final rootNode in rootNodes) {
      final hasWiki = wikiIds.contains(rootNode.nodeId);
      WikiMeta? meta;
      WikiDocument? doc;
      if (hasWiki) {
        meta = await store.readMeta(rootNode.nodeId);
        doc = await store.readWiki(rootNode.nodeId);
      }
      trees.add(TreeWikiInfo(
        rootNode: rootNode,
        hasWiki: hasWiki,
        meta: meta,
        document: doc,
      ));
    }

    // 保持已有选择；若之前选中的 tree 已不存在，回退到第一个 tree。
    final previous = state.value?.selectedRootNodeId;
    String? selected;
    if (previous != null && trees.any((t) => t.rootNode.nodeId == previous)) {
      selected = previous;
    } else if (trees.isNotEmpty) {
      selected = trees.first.rootNode.nodeId;
    }

    return WikiReaderState(
      trees: trees,
      selectedRootNodeId: selected,
    );
  }

  /// 选择要查看 / 生成 wiki 的 tree。
  void selectTree(String rootNodeId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(WikiReaderState(
      trees: current.trees,
      selectedRootNodeId: rootNodeId,
    ));
  }

  /// 从当前 tree 生成 / 重新生成 wiki 快照。
  Future<void> generateWiki(String rootNodeId) async {
    final current = state.value;
    if (current == null) return;

    state = const AsyncLoading();
    try {
      final paths = await ref.read(appPathsProvider.future);
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final sessionStore = await ref.read(sessionStoreProvider.future);

      final themeRow = await nodeStore.getThemeRow(themeId: themeId);
      final themeTitle = themeRow['title']! as String;
      final allNodes = await nodeStore.listNodes(themeId: themeId);

      // 只保留该 tree 的节点（root node + descendants）。
      final treeNodes = _collectSubtreeNodes(rootNodeId, allNodes);

      final themeDir = Directory(p.join(paths.themesDir.path, themeId));
      final store = WikiStore(themeDir: themeDir);

      await store.generateWiki(
        rootNodeId: rootNodeId,
        themeId: themeId,
        themeTitle: themeTitle,
        nodes: treeNodes,
        readSession: sessionStore.readSession,
        resolveImagePath: (nodeId, imagePath) async {
          final row = await nodeStore.getNodeRow(nodeId: nodeId);
          final nodePath = row['nodePath'] as String?;
          if (nodePath == null) return null;
          return p.join(paths.rootDir.path, nodePath, imagePath);
        },
      );

      state = AsyncData(await _load());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// 删除指定 tree 的 wiki 快照。
  Future<void> deleteWiki(String rootNodeId) async {
    state = const AsyncLoading();
    try {
      final paths = await ref.read(appPathsProvider.future);
      final themeDir = Directory(p.join(paths.themesDir.path, themeId));
      final store = WikiStore(themeDir: themeDir);
      await store.deleteWiki(rootNodeId);
      state = AsyncData(await _load());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  List<NodeEntity> _collectSubtreeNodes(
      String rootNodeId, List<NodeEntity> allNodes) {
    final childrenByParent = <String?, List<NodeEntity>>{};
    for (final node in allNodes) {
      childrenByParent.putIfAbsent(node.parentId, () => []).add(node);
    }

    final result = <NodeEntity>[];
    final queue = <String>[rootNodeId];
    final byId = {for (final n in allNodes) n.nodeId: n};
    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      final node = byId[currentId];
      if (node == null) continue;
      result.add(node);
      queue.addAll(childrenByParent[currentId]?.map((n) => n.nodeId) ?? const []);
    }
    return result;
  }
}

final wikiReaderControllerProvider =
    AsyncNotifierProvider.autoDispose.family<WikiReaderController, WikiReaderState, String>(
  WikiReaderController.new,
);
