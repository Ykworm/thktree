import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/domain/node.dart';

class ThemeDetailState {
  ThemeDetailState({
    required this.themeId,
    required this.themeTitle,
    required this.themePath,
    required this.nodes,
  });

  final String themeId;
  final String themeTitle;
  final String themePath;
  final List<NodeEntity> nodes;
}

class ThemeDetailController extends AsyncNotifier<ThemeDetailState> {
  ThemeDetailController(this.themeId);

  final String themeId;

  @override
  Future<ThemeDetailState> build() async {
    return _load();
  }

  Future<ThemeDetailState> _load() async {
    final nodeStore = await ref.read(nodeStoreProvider.future);
    final themeRow = await nodeStore.getThemeRow(themeId: themeId);
    final themeTitle = themeRow['title']! as String;
    final themePath = themeRow['themePath']! as String;
    final rawNodes = await nodeStore.listNodes(themeId: themeId);
    final nodes = await _withLastMessagePreviews(rawNodes);
    return ThemeDetailState(
      themeId: themeId,
      themeTitle: themeTitle,
      themePath: themePath,
      nodes: nodes,
    );
  }

  /// Load last user message preview for each node from session.md files.
  Future<List<NodeEntity>> _withLastMessagePreviews(List<NodeEntity> nodes) async {
    final paths = await ref.read(appPathsProvider.future);
    final result = <NodeEntity>[];
    for (final node in nodes) {
      String? preview;
      try {
        final row = await (await ref.read(nodeStoreProvider.future)).getNodeRow(nodeId: node.nodeId);
        final sessionPath = row['sessionPath'] as String;
        final absPath = paths.toAbsolutePath(sessionPath);
        final file = File(absPath);
        if (await file.exists()) {
          final raw = await file.readAsString();
          final doc = parseSessionMarkdown(raw);
          for (final msg in doc.messages.reversed) {
            if (msg.role == SessionRole.user && msg.body.trim().isNotEmpty) {
              final body = msg.body.trim();
              preview = body.length <= 40 ? body : '${body.substring(0, 40)}…';
              break;
            }
          }
        }
      } catch (_) {}
      result.add(NodeEntity(
        themeId: node.themeId,
        nodeId: node.nodeId,
        parentId: node.parentId,
        kind: node.kind,
        title: node.title,
        createdAtUtcIso8601: node.createdAtUtcIso8601,
        updatedAtUtcIso8601: node.updatedAtUtcIso8601,
        sortOrder: node.sortOrder,
        sourceExcerpt: node.sourceExcerpt,
        sourceType: node.sourceType,
        lastMessagePreview: preview,
      ));
    }
    return result;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _load());
  }

  /// Lightweight refresh that skips disk reindex.
  /// Use after in-memory-only changes like drag-to-reorder.
  Future<void> refreshNodesOnly() async {
    final nodeStore = await ref.read(nodeStoreProvider.future);
    final themeRow = await nodeStore.getThemeRow(themeId: themeId);
    final themeTitle = themeRow['title']! as String;
    final themePath = themeRow['themePath']! as String;
    final nodes = await nodeStore.listNodes(themeId: themeId);
    state = AsyncData(ThemeDetailState(
      themeId: themeId,
      themeTitle: themeTitle,
      themePath: themePath,
      nodes: nodes,
    ));
  }

  Future<void> createRootChatNode({required String title}) async {
    final nodeStore = await ref.read(nodeStoreProvider.future);
    final current = state.value ?? await _load();
    await nodeStore.createChatNode(
      themeId: themeId,
      themePath: current.themePath,
      parentId: null,
      title: title,
    );
    state = AsyncData(await _load());
  }

  Future<NodeEntity> createChildChatNode({required String parentId, required String title}) async {
    final nodeStore = await ref.read(nodeStoreProvider.future);
    final current = state.value ?? await _load();
    final child = await nodeStore.createChatNode(
      themeId: themeId,
      themePath: current.themePath,
      parentId: parentId,
      title: title,
    );
    state = AsyncData(await _load());
    return child;
  }

  Future<int> deleteNodeSubtree({required String nodeId}) async {
    final nodeStore = await ref.read(nodeStoreProvider.future);
    final deletedCount = await nodeStore.deleteNodeSubtree(nodeId: nodeId);
    state = AsyncData(await _load());
    return deletedCount;
  }
}

final themeDetailControllerProvider =
    AsyncNotifierProvider.autoDispose.family<ThemeDetailController, ThemeDetailState, String>(
  ThemeDetailController.new,
);
