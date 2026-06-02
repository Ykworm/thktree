// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

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

    // 'ThkTree' 现在只在 ThkLargeTitlePage 顶栏显示一次（原来 nav bar + 设置入口会显示 2 次）。
    expect(find.text('ThkTree'), findsOneWidget);
    expect(find.text('No themes yet'), findsOneWidget);
    // settings 按钮已从 theme list 顶栏移除，改用底部 tab bar 入口（见 router.dart）。
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
