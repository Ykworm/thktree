import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:thk_tree/ui/features/chat/chat_screen.dart';
import 'package:thk_tree/ui/features/chat/chat_screen_launch_params.dart';
import 'package:thk_tree/ui/features/settings/settings_screen.dart';
import 'package:thk_tree/ui/features/llm/llm_providers_screen.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_screen.dart';
import 'package:thk_tree/ui/features/themes/theme_list_screen.dart';
import 'package:thk_tree/ui/features/search/search_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _themesNavigatorKey = GlobalKey<NavigatorState>();
final _notesNavigatorKey = GlobalKey<NavigatorState>();
final _searchNavigatorKey = GlobalKey<NavigatorState>();
final _settingsNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/search',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => _MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          navigatorKey: _searchNavigatorKey,
          routes: [
            GoRoute(
              path: '/search',
              pageBuilder: (context, state) => CupertinoPage(
                child: const SearchScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _themesNavigatorKey,
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => CupertinoPage(
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
                final extra = state.extra;
                final ChatScreenLaunchParams params =
                    extra is ChatScreenLaunchParams
                        ? extra
                        : ChatScreenLaunchParams(
                            title: extra is String
                                ? extra
                                : '$themeId/$nodeId',
                          );
                return CupertinoPage(
                  child: ChatScreen(
                    themeId: themeId,
                    nodeId: nodeId,
                    title: params.title,
                    autoTriggerReply: params.autoTriggerReply,
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
              pageBuilder: (context, state) => CupertinoPage(
                child: NoteBrowseScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _settingsNavigatorKey,
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => CupertinoPage(
                child: SettingsScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/llm-providers',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CupertinoPage(
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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      resizeToAvoidBottomInset: false,
      child: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                final mq = MediaQuery.of(context);
                const tabBarContentHeight = 6 + 49 + 2;
                final tabBarHeight = mq.padding.bottom + tabBarContentHeight;
                final adjustedBottom = max<double>(
                  0,
                  mq.viewInsets.bottom - tabBarHeight,
                );
                return MediaQuery(
                  data: mq.copyWith(
                    viewInsets: mq.viewInsets.copyWith(bottom: adjustedBottom),
                  ),
                  child: navigationShell,
                );
              },
            ),
          ),
          _buildTabBar(context, l10n),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, AppLocalizations l10n) {
    final items = <({IconData icon, String label})>[
      (icon: CupertinoIcons.search, label: l10n.searchTabLabel),
      (icon: AppIcons.accountTree, label: l10n.themesTabLabel),
      (icon: AppIcons.note, label: l10n.notes),
      (icon: AppIcons.settings, label: l10n.settingsTabLabel),
    ];
    final selectedIndex = navigationShell.currentIndex;
    const activeColor = AppColors.accent;
    final inactiveColor = AppColors.textTertiary;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: SizedBox(
            height: 49,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int i = 0; i < items.length; i++)
                  _TabItem(
                    icon: items[i].icon,
                    label: items[i].label,
                    selected: i == selectedIndex,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      navigationShell.goBranch(
                        i,
                        initialLocation: i == selectedIndex,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SFIcon(icon, fontSize: 25, color: color),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: color),
              overflow: TextOverflow.ellipsis,
            ),
            if (selected) ...[
              const SizedBox(height: 0),
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
