import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/domain/theme.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/features/themes/theme_list_controller.dart';
import 'package:thk_tree/main.dart';

void main() {
  /// Navigate to the Themes tab (index 1) from the default Search tab.
  Future<void> goToThemesTab(WidgetTester tester) async {
    // StatefulShellRoute.indexedStack builds all branches, so the large title
    // "Themes" also exists in the widget tree. The tab-bar label is rendered
    // last (after the navigation shell), so .last targets it.
    await tester.tap(find.text('Themes').last);
    await tester.pumpAndSettle();
  }

  group('ThemeListScreen', () {
    testWidgets('shows empty state when no themes', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeListControllerProvider.overrideWith(FakeThemeListController.new),
          ],
          child: const ThkTreeApp(),
        ),
      );
      await tester.pumpAndSettle();
      await goToThemesTab(tester);

      expect(find.text('Start your first knowledge theme'), findsOneWidget);
      // 注意：settings 按钮已从 theme list 顶栏移除，改用底部 tab bar 入口（见 router.dart）。
      expect(find.byIcon(AppIcons.refresh), findsOneWidget);
      expect(find.byIcon(AppIcons.add), findsOneWidget);
    });

    testWidgets('shows theme list when themes exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeListControllerProvider
                .overrideWith(() => FakeThemeListController.withThemes([
                      ThemeEntity(
                        themeId: 'theme_1',
                        title: 'My Theme',
                        createdAtUtcIso8601: '2026-01-01T00:00:00.000Z',
                        updatedAtUtcIso8601: '2026-01-01T00:00:00.000Z',
                      ),
                    ])),
          ],
          child: const ThkTreeApp(),
        ),
      );
      await tester.pumpAndSettle();
      await goToThemesTab(tester);

      expect(find.text('My Theme'), findsOneWidget);
      expect(find.text('theme_1'), findsOneWidget);
      // ThkListTile.chevron 内部用 CupertinoListTileChevron 渲染（不用 AppIcons.chevronRight）。
      expect(find.byType(CupertinoListTileChevron), findsOneWidget);
      // 每个主题 tile 带 folder 图标作为 leading。
      expect(find.byIcon(AppIcons.folder), findsOneWidget);
    });

    testWidgets('shows multiple themes in list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeListControllerProvider
                .overrideWith(() => FakeThemeListController.withThemes([
                      ThemeEntity(
                        themeId: 'theme_1',
                        title: 'Theme A',
                        createdAtUtcIso8601: '2026-01-01T00:00:00.000Z',
                        updatedAtUtcIso8601: '2026-01-01T00:00:00.000Z',
                      ),
                      ThemeEntity(
                        themeId: 'theme_2',
                        title: 'Theme B',
                        createdAtUtcIso8601: '2026-01-02T00:00:00.000Z',
                        updatedAtUtcIso8601: '2026-01-02T00:00:00.000Z',
                      ),
                    ])),
          ],
          child: const ThkTreeApp(),
        ),
      );
      await tester.pumpAndSettle();
      await goToThemesTab(tester);

      expect(find.text('Theme A'), findsOneWidget);
      expect(find.text('Theme B'), findsOneWidget);
    });
  });
}

class FakeThemeListController extends ThemeListController {
  final List<ThemeEntity> _themes;

  FakeThemeListController() : _themes = const [];
  FakeThemeListController.withThemes(this._themes);

  @override
  Future<List<ThemeEntity>> build() async => _themes;

  @override
  Future<void> createTheme({required String title}) async {}

  @override
  Future<void> reindex() async {}
}
