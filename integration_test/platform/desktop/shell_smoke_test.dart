// macOS 桌面端启动冒烟测试
//
// 验证桌面壳（_DesktopShell）在 macOS 下启动无崩溃，且默认分支与切换正常：
// 1. 启动后侧栏 'ThkTree' 标题存在（说明走 _DesktopShell 而非移动端壳）
// 2. 默认落地 /search 分支 → SearchWorkspace 渲染
// 3. 点侧栏 '主题'(index=1) → ThemesWorkspace 渲染（分支切换生效）
// 4. 切回 '搜索'(index=0) → SearchWorkspace 仍在（indexedStack 不重置）
//
// 纯 UI 测试，不触发 LLM，无需 --dart-define-from-file。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/desktop/search_workspace.dart';
import 'package:thk_tree/ui/desktop/themes_workspace.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('桌面壳启动：侧栏存在 + 默认搜索分支 + 切换主题分支', (
    tester,
  ) async {
    final app = await createTestApp(locale: const Locale('zh'));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // 1. 侧栏标题存在 = 桌面壳已渲染
    expect(
      find.text('ThkTree'),
      findsOneWidget,
      reason: '桌面侧栏标题 "ThkTree" 应存在',
    );

    // 2. 默认落地 /search → SearchWorkspace
    expect(
      find.byType(SearchWorkspace),
      findsOneWidget,
      reason: '默认应渲染 SearchWorkspace',
    );

    // 3. 切到主题分支
    await tester.tap(find.byKey(const ValueKey('sidebar_item_1')));
    await tester.pumpAndSettle();
    expect(
      find.byType(ThemesWorkspace),
      findsOneWidget,
      reason: '切到主题分支应渲染 ThemesWorkspace',
    );

    // 4. 切回搜索分支，indexedStack 状态保留
    await tester.tap(find.byKey(const ValueKey('sidebar_item_0')));
    await tester.pumpAndSettle();
    expect(
      find.byType(SearchWorkspace),
      findsOneWidget,
      reason: '切回搜索分支 SearchWorkspace 应仍在',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
