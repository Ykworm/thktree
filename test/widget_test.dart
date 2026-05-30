// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thk_tree/domain/theme.dart';
import 'package:thk_tree/ui/features/themes/theme_list_controller.dart';
import 'package:thk_tree/main.dart';

void main() {
  testWidgets('App boots to theme list screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeListControllerProvider.overrideWith(FakeThemeListController.new),
        ],
        child: const ThkTreeApp(),
      ),
    );
    await tester.pump();

    expect(find.text('ThkTree'), findsNWidgets(2));
    expect(find.text('No themes yet'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}

class FakeThemeListController extends ThemeListController {
  @override
  Future<List<ThemeEntity>> build() async => const [];

  @override
  Future<void> createTheme({required String title}) async {}

  @override
  Future<void> reindex() async {}
}
