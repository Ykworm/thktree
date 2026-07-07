import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/features/search/search_content.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.searchTabLabel),
        leading: CupertinoButton(
          key: const ValueKey('menu_button'),
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => _showMenuPanel(context, l10n),
          child: Icon(
            CupertinoIcons.line_horizontal_3,
            size: 22,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      child: SafeArea(child: SearchContent()),
    );
  }

  void _showMenuPanel(BuildContext context, AppLocalizations l10n) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      _SlideFromLeftRoute(
        builder: (_) => _MenuPanel(l10n: l10n),
      ),
    );
  }
}

/// 从左往右滑入的半屏路由。
class _SlideFromLeftRoute extends PageRouteBuilder<_MenuPanel> {
  _SlideFromLeftRoute({required this.builder})
      : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: const Color(0x61000000),
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
        );

  final WidgetBuilder builder;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic));
    return SlideTransition(
      position: animation.drive(slide),
      child: child,
    );
  }
}

/// 半屏面板内容：从左侧滑入，宽度约占屏幕 70%。
class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.translucent,
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {}, // 阻止点击面板区域关闭
          child: Container(
            color: AppColors.surface,
            child: SafeArea(
              child: SizedBox(
                width: screenWidth * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'ThkTree',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _MenuTile(
                      icon: CupertinoIcons.gear,
                      title: l10n.menuSettings,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/settings');
                      },
                    ),
                    _MenuTile(
                      icon: CupertinoIcons.info,
                      title: l10n.menuAbout,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/about');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}