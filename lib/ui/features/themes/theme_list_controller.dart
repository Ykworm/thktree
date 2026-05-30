import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/domain/theme.dart';

class ThemeListController extends AsyncNotifier<List<ThemeEntity>> {
  @override
  Future<List<ThemeEntity>> build() async {
    final store = await ref.watch(themeStoreProvider.future);
    await store.reindexThemesFromDisk();
    return store.listThemes();
  }

  Future<void> createTheme({required String title}) async {
    final store = await ref.read(themeStoreProvider.future);
    await store.createTheme(title: title);
    state = AsyncData(await store.listThemes());
  }

  Future<void> reindex() async {
    final store = await ref.read(themeStoreProvider.future);
    await store.reindexThemesFromDisk();
    state = AsyncData(await store.listThemes());
  }
}

final themeListControllerProvider =
    AsyncNotifierProvider<ThemeListController, List<ThemeEntity>>(ThemeListController.new);
