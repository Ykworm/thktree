import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/domain/theme.dart';

class ThemeListController extends AsyncNotifier<List<ThemeEntity>> {
  @override
  Future<List<ThemeEntity>> build() async {
    log('ThemeListController.build: starting');
    final store = await ref.watch(themeStoreProvider.future);
    final themes = await store.listThemes();
    log('ThemeListController.build: found ${themes.length} themes');
    return _loadPreviews(themes);
  }

  Future<List<ThemeEntity>> _loadPreviews(List<ThemeEntity> themes) async {
    final db = await ref.read(appDatabaseProvider.future);
    final result = <ThemeEntity>[];

    for (final theme in themes) {
      String? preview;
      try {
        final rows = await db.db.query(
          'search_index',
          columns: ['content'],
          where: 'themeId = ? AND entityType = ?',
          whereArgs: [theme.themeId, 'message'],
          orderBy: 'updatedAt DESC',
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final content = rows.first['content'] as String;
          preview = content.length <= 40 ? content : '${content.substring(0, 40)}\u2026';
        }
      } catch (_) {}

      result.add(ThemeEntity(
        themeId: theme.themeId,
        title: theme.title,
        createdAtUtcIso8601: theme.createdAtUtcIso8601,
        updatedAtUtcIso8601: theme.updatedAtUtcIso8601,
        pinned: theme.pinned,
        lastMessagePreview: preview,
      ));
    }
    return result;
  }

  Future<void> createTheme({required String title}) async {
    final store = await ref.read(themeStoreProvider.future);
    await store.createTheme(title: title);
    state = AsyncData(await _loadPreviews(await store.listThemes()));
  }

  Future<void> reindex() async {
    final store = await ref.read(themeStoreProvider.future);
    await store.syncFromDisk();
    state = AsyncData(await _loadPreviews(await store.listThemes()));
  }

  Future<void> togglePin({required String themeId, required bool pinned}) async {
    final store = await ref.read(themeStoreProvider.future);
    await store.togglePin(themeId: themeId, pinned: pinned);
    state = AsyncData(await _loadPreviews(await store.listThemes()));
  }

  Future<void> deleteTheme({required String themeId}) async {
    final store = await ref.read(themeStoreProvider.future);

    // 同步清理 keyword_global.json 中该 theme 的反向索引 + 孤立关键词。
    // 必须在 store.deleteTheme() 之前调用，因为 deleteTheme 会递归删除
    // 整个 theme 目录（含 keyword_analysis.json）。
    try {
      final globalStorage =
          await ref.read(keywordGlobalStorageProvider.future);
      await globalStorage.removeThemeRefs(themeId);
    } catch (_) {
      // 静默失败，不影响主流程。
    }

    await store.deleteTheme(themeId: themeId);
    state = AsyncData(await _loadPreviews(await store.listThemes()));
  }

  Future<void> renameTheme({required String themeId, required String title}) async {
    final store = await ref.read(themeStoreProvider.future);
    await store.renameTheme(themeId: themeId, title: title);
    state = AsyncData(await _loadPreviews(await store.listThemes()));
  }
}

final themeListControllerProvider =
    AsyncNotifierProvider<ThemeListController, List<ThemeEntity>>(ThemeListController.new);
