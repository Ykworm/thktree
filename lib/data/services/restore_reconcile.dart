import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:thk_tree/data/services/import_service.dart';
import 'package:thk_tree/data/services/search_service.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';
import 'package:thk_tree/ui/features/themes/theme_list_controller.dart';

/// Rebuild the SQLite index from restored disk files, then invalidate
/// in-memory Riverpod caches so every screen picks up the new data.
Future<void> reconcileAndRefreshAfterRestore(
  WidgetRef ref, {
  required ImportMode mode,
}) async {
  final paths = await ref.read(appPathsProvider.future);
  final db = await ref.read(appDatabaseProvider.future);
  final themeStore = await ref.read(themeStoreProvider.future);
  final nodeStore = await ref.read(nodeStoreProvider.future);

  if (mode == ImportMode.overwrite) {
    await themeStore.reindexThemesFromDisk();
  } else {
    await themeStore.syncFromDisk();
  }

  final themes = await themeStore.listThemes();
  for (final theme in themes) {
    final themePath = p.join(paths.themesDir.path, theme.themeId);
    if (mode == ImportMode.overwrite) {
      await nodeStore.reindexNodesFromDisk(themePath: themePath);
    } else {
      await nodeStore.syncFromDisk(themePath: themePath);
    }
  }

  await db.db.delete('search_index');
  final searchService = await ref.read(searchServiceProvider.future);
  final scanItems = themes
      .map(
        (t) => ThemeScanItem(
          themeId: t.themeId,
          title: t.title,
          notesDir: Directory(p.join(paths.themesDir.path, t.themeId, 'notes')),
          nodesDir: Directory(p.join(paths.themesDir.path, t.themeId, 'nodes')),
        ),
      )
      .toList();
  await searchService.rebuildAll(scanItems);

  invalidateAppDataAfterRestore(ref);
}

/// Drop cached app data providers after a backup restore / import.
void invalidateAppDataAfterRestore(WidgetRef ref) {
  ref.invalidate(appDatabaseProvider);
  ref.invalidate(themeStoreProvider);
  ref.invalidate(nodeStoreProvider);
  ref.invalidate(sessionStoreProvider);
  ref.invalidate(searchServiceProvider);
  ref.invalidate(themeListControllerProvider);
  ref.invalidate(themeDetailControllerProvider);
  ref.read(noteListVersionProvider.notifier).bump();
  ref.read(pinListVersionProvider.notifier).bump();
  ref.invalidate(keywordGlobalStorageProvider);
  ref.invalidate(keywordCategoryStorageProvider);
  ref.invalidate(clipStorageProvider);
  ref.invalidate(pinStorageProvider);
  ref.invalidate(scrollAnchorStoreProvider);
  ref.invalidate(themeUiPrefsStoreProvider);
}
