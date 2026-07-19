import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:thk_tree/data/models/wiki_node.dart';
import 'package:thk_tree/data/services/wiki_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';

class WikiReaderState {
  const WikiReaderState({
    required this.hasWiki,
    required this.document,
    required this.meta,
  });

  final bool hasWiki;
  final WikiDocument? document;
  final WikiMeta? meta;
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
    final themeDir = Directory(p.join(paths.themesDir.path, themeId));
    final store = WikiStore(themeDir: themeDir);

    final hasWiki = await store.hasWiki();
    if (!hasWiki) {
      return const WikiReaderState(
        hasWiki: false,
        document: null,
        meta: null,
      );
    }

    final meta = await store.readMeta();
    final document = await store.readWiki();
    return WikiReaderState(
      hasWiki: true,
      document: document,
      meta: meta,
    );
  }

  /// 从当前 tree 生成 / 重新生成 wiki 快照。
  Future<void> generateWiki() async {
    state = const AsyncLoading();
    try {
      final paths = await ref.read(appPathsProvider.future);
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final sessionStore = await ref.read(sessionStoreProvider.future);

      final themeRow = await nodeStore.getThemeRow(themeId: themeId);
      final themeTitle = themeRow['title']! as String;
      final nodes = await nodeStore.listNodes(themeId: themeId);

      final themeDir = Directory(p.join(paths.themesDir.path, themeId));
      final store = WikiStore(themeDir: themeDir);

      await store.generateWiki(
        themeId: themeId,
        themeTitle: themeTitle,
        nodes: nodes,
        readSession: sessionStore.readSession,
        resolveImagePath: (nodeId, imagePath) async {
          // session.md 中的 imagePath 是相对于 node 目录的。
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

  /// 删除 wiki 快照。
  Future<void> deleteWiki() async {
    state = const AsyncLoading();
    try {
      final paths = await ref.read(appPathsProvider.future);
      final themeDir = Directory(p.join(paths.themesDir.path, themeId));
      final store = WikiStore(themeDir: themeDir);
      await store.deleteWiki();
      state = AsyncData(await _load());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final wikiReaderControllerProvider =
    AsyncNotifierProvider.autoDispose.family<WikiReaderController, WikiReaderState, String>(
  WikiReaderController.new,
);
