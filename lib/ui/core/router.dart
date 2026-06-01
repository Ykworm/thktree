import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/features/summary/summary_route_params.dart';
import 'package:thk_tree/ui/features/chat/chat_screen.dart';
import 'package:thk_tree/ui/features/settings/settings_screen.dart';
import 'package:thk_tree/ui/features/summary/summary_chat_screen.dart';
import 'package:thk_tree/ui/features/llm/llm_providers_screen.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_screen.dart';
import 'package:thk_tree/ui/features/themes/theme_list_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _themesNavigatorKey = GlobalKey<NavigatorState>();
final _notesNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => _MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          navigatorKey: _themesNavigatorKey,
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => const CupertinoPage(
                child: ThemeListScreen(),
              ),
            ),
            GoRoute(
              path: '/themes/:themeId/tree',
              pageBuilder: (context, state) {
                final themeId = state.pathParameters['themeId']!;
                return CupertinoPage(
                  child: ThemeDetailScreen(themeId: themeId),
                );
              },
            ),
            GoRoute(
              path: '/themes/:themeId/nodes/:nodeId',
              pageBuilder: (context, state) {
                final themeId = state.pathParameters['themeId']!;
                final nodeId = state.pathParameters['nodeId']!;
                final title = (state.extra is String) ? state.extra as String : '$themeId/$nodeId';
                return CupertinoPage(
                  child: ChatScreen(themeId: themeId, nodeId: nodeId, title: title),
                );
              },
            ),
            GoRoute(
              path: '/themes/:themeId/nodes/:parentNodeId/summary',
              pageBuilder: (context, state) {
                final themeId = state.pathParameters['themeId']!;
                final parentNodeId = state.pathParameters['parentNodeId']!;
                final params = state.extra as SummaryRouteParams;
                return CupertinoPage(
                  child: SummaryChatScreen(
                    themeId: themeId,
                    parentNodeId: parentNodeId,
                    branchTitle: params.branchTitle,
                    parentSessionText: params.parentSessionText,
                  ),
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _notesNavigatorKey,
          routes: [
            GoRoute(
              path: '/notes',
              pageBuilder: (context, state) => const CupertinoPage(
                child: NoteBrowseScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const CupertinoPage(
        child: SettingsScreen(),
      ),
    ),
    GoRoute(
      path: '/llm-providers',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const CupertinoPage(
        child: LlmProvidersScreen(),
      ),
    ),
  ],
  errorBuilder: (context, state) {
    return CupertinoPageScaffold(
      child: Center(child: Text(state.error.toString())),
    );
  },
);

class _MainShell extends ConsumerWidget {
  const _MainShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: [
          BottomNavigationBarItem(
            icon: const Icon(AppIcons.accountTree),
            label: l10n.appName,
          ),
          BottomNavigationBarItem(
            icon: const Icon(AppIcons.note),
            label: l10n.notes,
          ),
        ],
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          if (index == 1) {
            ref.read(noteListVersionProvider.notifier).bump();
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
      tabBuilder: (context, index) => navigationShell,
    );
  }
}
