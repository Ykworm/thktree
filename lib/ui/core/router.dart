import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
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
              builder: (context, state) => const ThemeListScreen(),
            ),
            GoRoute(
              path: '/themes/:themeId/tree',
              builder: (context, state) {
                final themeId = state.pathParameters['themeId']!;
                return ThemeDetailScreen(themeId: themeId);
              },
            ),
            GoRoute(
              path: '/themes/:themeId/nodes/:nodeId',
              builder: (context, state) {
                final themeId = state.pathParameters['themeId']!;
                final nodeId = state.pathParameters['nodeId']!;
                final title = (state.extra is String) ? state.extra as String : '$themeId/$nodeId';
                return ChatScreen(themeId: themeId, nodeId: nodeId, title: title);
              },
            ),
            GoRoute(
              path: '/themes/:themeId/nodes/:parentNodeId/summary',
              builder: (context, state) {
                final themeId = state.pathParameters['themeId']!;
                final parentNodeId = state.pathParameters['parentNodeId']!;
                final params = state.extra as SummaryRouteParams;
                return SummaryChatScreen(
                  themeId: themeId,
                  parentNodeId: parentNodeId,
                  branchTitle: params.branchTitle,
                  parentSessionText: params.parentSessionText,
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
              builder: (context, state) => const NoteBrowseScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/llm-providers',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LlmProvidersScreen(),
    ),
  ],
  errorBuilder: (context, state) {
    return Directionality(
      textDirection: TextDirection.ltr,
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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          if (index == 1) {
            ref.read(noteListVersionProvider.notifier).bump();
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.account_tree_outlined),
            selectedIcon: const Icon(Icons.account_tree),
            label: l10n.appName,
          ),
          NavigationDestination(
            icon: const Icon(Icons.note_outlined),
            selectedIcon: const Icon(Icons.note),
            label: l10n.notes,
          ),
        ],
      ),
    );
  }
}
