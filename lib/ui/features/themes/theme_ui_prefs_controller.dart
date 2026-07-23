import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/services/theme_ui_prefs_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';

/// 按 themeId 暴露树页 UI 偏好（折叠 + root 隐藏）。
class ThemeUiPrefsController extends AsyncNotifier<ThemeUiPrefs> {
  ThemeUiPrefsController(this.themeId);

  final String themeId;

  @override
  Future<ThemeUiPrefs> build() async {
    final store = await ref.watch(themeUiPrefsStoreProvider.future);
    return store.forTheme(themeId);
  }

  Future<void> setCollapsedIds(Set<String> collapsedIds) async {
    final store = await ref.read(themeUiPrefsStoreProvider.future);
    await store.setCollapsedIds(themeId, collapsedIds);
    final current = state.value ?? const ThemeUiPrefs();
    state = AsyncData(
      current.copyWith(collapsedIds: Set<String>.from(collapsedIds)),
    );
  }

  Future<void> toggleCollapsed(String nodeId) async {
    final current = state.value ?? const ThemeUiPrefs();
    final next = Set<String>.from(current.collapsedIds);
    if (!next.remove(nodeId)) {
      next.add(nodeId);
    }
    await setCollapsedIds(next);
  }

  Future<void> collapseAll(Iterable<String> parentIds) async {
    await setCollapsedIds(parentIds.toSet());
  }

  Future<void> expandAll() async {
    await setCollapsedIds(const <String>{});
  }

  Future<void> setRootHidden(String rootNodeId, {required bool hidden}) async {
    final store = await ref.read(themeUiPrefsStoreProvider.future);
    await store.setRootHidden(themeId, rootNodeId, hidden: hidden);
    final current = state.value ?? const ThemeUiPrefs();
    final next = Set<String>.from(current.hiddenRootIds);
    if (hidden) {
      next.add(rootNodeId);
    } else {
      next.remove(rootNodeId);
    }
    state = AsyncData(current.copyWith(hiddenRootIds: next));
  }

  Future<void> hideRoot(String rootNodeId) =>
      setRootHidden(rootNodeId, hidden: true);

  Future<void> showRoot(String rootNodeId) =>
      setRootHidden(rootNodeId, hidden: false);
}

final themeUiPrefsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ThemeUiPrefsController, ThemeUiPrefs, String>(
  ThemeUiPrefsController.new,
);
