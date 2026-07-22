// macOS 桌面端侧栏导航测试
//
// 验证点侧栏每一项都能切到对应工作区（选择驱动多栏）：
//   搜索(0) → SearchWorkspace
//   主题(1) → ThemesWorkspace
//   笔记(2) → NotesWorkspace
//   Lab(3)  → LabPlaceholderScreen
// 并验证来回切换后工作区仍正确渲染（indexedStack 保留各分支状态）。
//
// 纯 UI 测试，不触发 LLM，无需 --dart-define-from-file。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/desktop/search_workspace.dart';
import 'package:thk_tree/ui/desktop/themes_workspace.dart';
import 'package:thk_tree/ui/desktop/notes_workspace.dart';
import 'package:thk_tree/ui/features/lab/lab_placeholder_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('侧栏四分支切换渲染对应工作区', (tester) async {
    final app = await createTestApp(locale: const Locale('zh'));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // 搜索(0)
    await tester.tap(find.byKey(const ValueKey('sidebar_item_0')));
    await tester.pumpAndSettle();
    expect(
      find.byType(SearchWorkspace),
      findsOneWidget,
      reason: '搜索分支应渲染 SearchWorkspace',
    );

    // 主题(1)
    await tester.tap(find.byKey(const ValueKey('sidebar_item_1')));
    await tester.pumpAndSettle();
    expect(
      find.byType(ThemesWorkspace),
      findsOneWidget,
      reason: '主题分支应渲染 ThemesWorkspace',
    );

    // 笔记(2)
    await tester.tap(find.byKey(const ValueKey('sidebar_item_2')));
    await tester.pumpAndSettle();
    expect(
      find.byType(NotesWorkspace),
      findsOneWidget,
      reason: '笔记分支应渲染 NotesWorkspace',
    );

    // Lab(3)
    await tester.tap(find.byKey(const ValueKey('sidebar_item_3')));
    await tester.pumpAndSettle();
    expect(
      find.byType(LabPlaceholderScreen),
      findsOneWidget,
      reason: 'Lab 分支应渲染 LabPlaceholderScreen',
    );

    // 切回主题，验证 indexedStack 不重置
    await tester.tap(find.byKey(const ValueKey('sidebar_item_1')));
    await tester.pumpAndSettle();
    expect(
      find.byType(ThemesWorkspace),
      findsOneWidget,
      reason: '切回主题分支 ThemesWorkspace 应仍在',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
