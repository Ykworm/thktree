import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/platform/android/android_color_scheme.dart';
import 'package:thk_tree/ui/platform/android/android_theme_tile.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.from(colorScheme: androidColorScheme()),
      // ListTile 需要 Material 祖先（真实壳由 Material(color:) 提供）。
      home: Material(child: child),
    );

void main() {
  testWidgets('徽章颜色来自 themeTileColorFor，不写裸色', (tester) async {
    const themeId = 'alpha-theme';
    await tester.pumpWidget(
      _wrap(const AndroidThemeTile(
        themeId: themeId,
        title: 'Alpha',
        subtitle: 'sub',
      )),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.folder));
    expect(icon.color, AppColors.themeTileColorFor(themeId));

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('sub'), findsOneWidget);
  });

  testWidgets('触摸命中区高度 ≥ 48dp', (tester) async {
    await tester.pumpWidget(
      _wrap(const AndroidThemeTile(
        themeId: 't',
        title: 'T',
      )),
    );

    final box = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .firstWhere((s) => s.height != null);
    expect(box.height, greaterThanOrEqualTo(kAndroidMinTouchTarget));
  });
}
