import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/ui/platform/android/android_color_scheme.dart';
import 'package:thk_tree/ui/platform/android/android_nav_bar.dart';

List<AndroidNavItem> get _items => const [
      AndroidNavItem(icon: Icons.search, label: 'Search'),
      AndroidNavItem(icon: Icons.folder, label: 'Themes'),
      AndroidNavItem(icon: Icons.note, label: 'Notes'),
      AndroidNavItem(icon: Icons.science, label: 'Lab'),
    ];

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.from(colorScheme: androidColorScheme()),
      home: child,
    );

void main() {
  testWidgets('底部导航渲染 4 个目标并上报点击索引', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      _wrap(AndroidNavBar(
        items: _items,
        selectedIndex: 0,
        onTap: (i) => tapped = i,
      )),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Themes'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Lab'), findsOneWidget);

    await tester.tap(find.byType(NavigationDestination).at(2));
    expect(tapped, 2);
  });

  testWidgets('平板宽度渲染 NavigationRail', (tester) async {
    await tester.pumpWidget(
      _wrap(SizedBox(
        height: 600,
        width: 220,
        child: AndroidNavRail(
          items: _items,
          selectedIndex: 1,
          onTap: _noop,
        ),
      )),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('NavigationRail 点击上报索引', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      _wrap(SizedBox(
        height: 600,
        width: 220,
        child: AndroidNavRail(
          items: _items,
          selectedIndex: 0,
          onTap: (i) => tapped = i,
        ),
      )),
    );

    await tester.tap(find.text('Lab'));
    expect(tapped, 3);
  });
}

void _noop(int _) {}
