import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';
import 'package:thk_tree/ui/core/widgets/thk_glass_bar.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:thk_tree/ui/platform/android/android_navigation_shell.dart';
import 'package:thk_tree/ui/features/chat/chat_screen.dart';
import 'package:thk_tree/ui/features/chat/chat_screen_launch_params.dart';
import 'package:thk_tree/ui/features/lab/lab_placeholder_screen.dart';
import 'package:thk_tree/ui/features/lab/keyword_ranking/keyword_ranking_screen.dart';
import 'package:thk_tree/ui/features/lab/keyword_ranking/theme_selection_screen.dart';
import 'package:thk_tree/ui/features/lab/keyword_ranking/leaf_selection_screen.dart';
import 'package:thk_tree/ui/features/lab/keyword_ranking/keyword_detail_screen.dart';
import 'package:thk_tree/ui/features/lab/thinking_collision/thinking_collision_screen.dart';
import 'package:thk_tree/ui/features/lab/user_input_summary/user_input_summary_screen.dart';
import 'package:thk_tree/ui/features/settings/settings_screen.dart';
import 'package:thk_tree/ui/features/settings/keyword_score_prompt_screen.dart';
import 'package:thk_tree/ui/features/llm/llm_providers_screen.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_screen.dart';
import 'package:thk_tree/ui/features/themes/theme_list_screen.dart';
import 'package:thk_tree/ui/features/themes/full_tree_screen.dart';
import 'package:thk_tree/ui/features/themes/merge_chat_confirm_screen.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/ui/features/about/about_screen.dart';
import 'package:thk_tree/ui/features/search/search_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _themesNavigatorKey = GlobalKey<NavigatorState>();
final _notesNavigatorKey = GlobalKey<NavigatorState>();
final _searchNavigatorKey = GlobalKey<NavigatorState>();
final _labNavigatorKey = GlobalKey<NavigatorState>();

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
                name: 'themes-list',
                child: ThemeListScreen(),
              ),
            ),
            GoRoute(
              path: '/themes/:themeId/tree',
              pageBuilder: (context, state) {
                final themeId = state.pathParameters['themeId']!;
                final scrollToNodeId = state.uri.queryParameters['scrollToNodeId'];
                final searchPrefill = state.uri.queryParameters['searchPrefill'];
                return CupertinoPage(
                  name: 'theme-tree-$themeId',
                  child: ThemeDetailScreen(
                    themeId: themeId,
                    scrollToNodeId: scrollToNodeId,
                    searchPrefill: searchPrefill,
                  ),
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
                  name: 'chat-$nodeId',
                  child: ChatScreen(
                    themeId: themeId,
                    nodeId: nodeId,
                    title: params.title,
                    autoTriggerReply: params.autoTriggerReply,
                    isDocSplit: params.isDocSplit,
                  ),
                );
              },
            ),
            GoRoute(
              path: '/themes/:themeId/full-tree',
              pageBuilder: (context, state) {
                final themeId = state.pathParameters['themeId']!;
                final currentNodeId =
                    state.uri.queryParameters['currentNodeId'];
                final multiSelect =
                    state.uri.queryParameters['multiSelect'] == 'true';
                return CupertinoPage(
                  child: FullTreeScreen(
                    themeId: themeId,
                    currentNodeId: currentNodeId,
                    initialMultiSelect: multiSelect,
                  ),
                );
              },
            ),
            GoRoute(
              path: '/themes/:themeId/merge-confirm',
              pageBuilder: (context, state) {
                final themeId = state.pathParameters['themeId']!;
                final extra = state.extra;
                final List<NodeEntity> selectedNodes =
                    extra is List<NodeEntity> ? extra : <NodeEntity>[];
                final crossTree =
                    state.uri.queryParameters['crossTree'] == 'true';
                return CupertinoPage(
                  child: MergeChatConfirmScreen(
                    themeId: themeId,
                    selectedNodes: selectedNodes,
                    crossTree: crossTree,
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
          navigatorKey: _labNavigatorKey,
          routes: [
            GoRoute(
              path: '/lab',
              pageBuilder: (context, state) => CupertinoPage(
                child: const LabPlaceholderScreen(),
              ),
            ),
            GoRoute(
              path: '/lab/keyword-ranking',
              pageBuilder: (context, state) => CupertinoPage(
                child: const KeywordRankingScreen(),
              ),
            ),
            GoRoute(
              path: '/lab/keyword-ranking/select-theme',
              pageBuilder: (context, state) => CupertinoPage(
                child: const ThemeSelectionScreen(),
              ),
            ),
            GoRoute(
              path: '/lab/keyword-ranking/select-leaves',
              pageBuilder: (context, state) => CupertinoPage(
                child: LeafSelectionScreen(
                  themeId: state.uri.queryParameters['themeId'],
                ),
              ),
            ),
            GoRoute(
              path: '/lab/keyword-ranking/detail/:keyword',
              pageBuilder: (context, state) {
                final keyword = state.pathParameters['keyword'] ?? '';
                return CupertinoPage(
                  child: KeywordDetailScreen(keyword: keyword),
                );
              },
            ),
            GoRoute(
              path: '/lab/user-input-summary',
              pageBuilder: (context, state) => CupertinoPage(
                child: const UserInputSummaryScreen(),
              ),
            ),
            GoRoute(
              path: '/lab/thinking-collision',
              pageBuilder: (context, state) => CupertinoPage(
                child: const ThinkingCollisionScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CupertinoPage(
        name: 'settings',
        child: const SettingsScreen(),
      ),
    ),
    GoRoute(
      path: '/settings/keyword-score-prompt',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CupertinoPage(
        child: const KeywordScorePromptScreen(),
      ),
    ),
    GoRoute(
      path: '/llm-providers',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CupertinoPage(
        child: LlmProvidersScreen(),
      ),
    ),
    GoRoute(
      path: '/about',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CupertinoPage(
        child: const AboutScreen(),
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
    // Android 底部导航/导航栏壳；其余平台沿用移动端 Cupertino tab bar 壳。
    if (Platform.isAndroid) {
      return AndroidNavigationShell(navigationShell: navigationShell);
    }
    final l10n = AppLocalizations.of(context)!;
    final mq = MediaQuery.of(context);
    // 键盘弹出时隐藏底部 tab（与 Android 壳一致）。
    final keyboardOpen = mq.viewInsets.bottom > 0;
    // Tab 必须叠在内容上方，BackdropFilter 才能磨到页面内容；
    // Column「内容 + tab」并排时 tab 背后只有 scaffold 实色，看起来像不透明圆角条。
    final tabOverlayHeight =
        AppGlass.tabBarContentHeight + mq.padding.bottom;
    final contentMq = keyboardOpen
        ? mq
        : mq.copyWith(
            padding: mq.padding.copyWith(
              bottom: mq.padding.bottom + AppGlass.tabBarContentHeight,
            ),
          );
    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      resizeToAvoidBottomInset: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaQuery(
            data: contentMq,
            child: navigationShell,
          ),
          if (!keyboardOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: tabOverlayHeight,
              child: _buildTabBar(context, l10n),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, AppLocalizations l10n) {
    final items = <({
      IconData icon,
      Widget? unselectedIcon,
      Widget? selectedIcon,
      String label,
    })>[
      (
        icon: CupertinoIcons.search,
        unselectedIcon: null,
        selectedIcon: null,
        label: l10n.searchTabLabel,
      ),
      (
        icon: AppIcons.accountTree,
        unselectedIcon: null,
        selectedIcon: null,
        label: l10n.themesTabLabel,
      ),
      (
        icon: AppIcons.note,
        unselectedIcon: null,
        selectedIcon: null,
        label: l10n.notes,
      ),
      (
        icon: AppIcons.lab,
        unselectedIcon: null,
        selectedIcon: null,
        label: l10n.labTabLabel,
      ),
    ];
    final selectedIndex = navigationShell.currentIndex;
    const activeColor = AppColors.accent;
    final inactiveColor = AppColors.textTertiary;

    // 壳层轻玻璃（iOS blur；Android 不透明 paper），锁在 tab 高度条带
    return ThkGlassBar(
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
                    unselectedIcon: items[i].unselectedIcon,
                    selectedIcon: items[i].selectedIcon,
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
    this.unselectedIcon,
    this.selectedIcon,
  });

  final IconData icon;
  final Widget? unselectedIcon;
  final Widget? selectedIcon;
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
            if (selected && selectedIcon != null)
              selectedIcon!
            else if (!selected && unselectedIcon != null)
              unselectedIcon!
            else
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
