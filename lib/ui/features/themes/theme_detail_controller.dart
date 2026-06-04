import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/app_services.dart';
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
    final themeStore = await ref.read(themeStoreProvider.future);
    final nodeStore = await ref.read(nodeStoreProvider.future);
    await themeStore.reindexThemesFromDisk();
    final themeRow = await nodeStore.getThemeRow(themeId: themeId);
    final themeTitle = themeRow['title']! as String;
    final themePath = themeRow['themePath']! as String;
    await nodeStore.reindexNodesFromDisk(themePath: themePath);
    final nodes = await nodeStore.listNodes(themeId: themeId);
    return ThemeDetailState(
      themeId: themeId,
      themeTitle: themeTitle,
      themePath: themePath,
      nodes: nodes,
    );
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
