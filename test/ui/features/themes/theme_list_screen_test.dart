import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/domain/theme.dart';
import 'package:thk_tree/ui/features/themes/theme_list_controller.dart';
import 'package:thk_tree/main.dart';

void main() {
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

      expect(find.text('No themes yet'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
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

      expect(find.text('My Theme'), findsOneWidget);
      expect(find.text('theme_1'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
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
