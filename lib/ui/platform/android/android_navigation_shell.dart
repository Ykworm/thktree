// Android 平台壳（适配器）。
//
// 镜像 macOS 桌面壳 _DesktopShell 的模式：在 router 的 _MainShell.build 里按
// Platform.isAndroid 分发到这里。本壳只负责 Android 的导航范式与平台适配，
// 内部页面仍复用 ThkTree 既有的 Cupertino 业务页面（handoff §2.7）。
//
// 关键平台约定（handoff §2.7）：
// - 手机底部导航栏 / 平板导航栏（rail），选中态 = accent；
// - edge-to-edge：用 SafeArea 处理状态栏/手势条，避免内容被遮；
// - 系统深色模式：监听 PlatformDispatcher.platformBrightness，实时同步 AppColors
//   （handoff §1.3），保证 App 跟 Android 全局深色开关走。
// - 不开启 Monet dynamic color：ColorScheme 由 AppColors 真源构造，品牌一致。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/platform/android/android_brightness_controller.dart';
import 'package:thk_tree/ui/platform/android/android_color_scheme.dart';
import 'package:thk_tree/ui/platform/android/android_nav_bar.dart';

/// 响应式断点判定（导出便于单测）。宽度 ≥ [kAndroidTabletBreakpoint] 视为平板，
/// 走导航栏（rail）；否则手机，走底部导航栏。
bool isTabletWidth(double width) => width >= kAndroidTabletBreakpoint;

/// 手机/平板通用壳。包裹 [navigationShell]，按宽度切换导航形态。
class AndroidNavigationShell extends StatefulWidget {
  const AndroidNavigationShell({
    super.key,
    required this.navigationShell,
    this.brightnessController,
  });

  final StatefulNavigationShell navigationShell;

  /// 注入用于测试的亮度控制器；默认构造真实控制器（监听系统 dispatcher）。
  final AndroidBrightnessController? brightnessController;

  @override
  State<AndroidNavigationShell> createState() => _AndroidNavigationShellState();
}

class _AndroidNavigationShellState extends State<AndroidNavigationShell>
    with WidgetsBindingObserver {
  late final AndroidBrightnessController _brightness;

  @override
  void initState() {
    super.initState();
    _brightness =
        widget.brightnessController ?? AndroidBrightnessController();
    _brightness.attach();
    _brightness.syncNow();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _brightness.detach();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _brightness.syncNow();

  void _go(int index) => widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <AndroidNavItem>[
      AndroidNavItem(icon: Icons.search, label: l10n.searchTabLabel),
      AndroidNavItem(icon: Icons.folder, label: l10n.themesTabLabel),
      AndroidNavItem(icon: Icons.note, label: l10n.notes),
      AndroidNavItem(icon: Icons.science, label: l10n.labTabLabel),
    ];
    final selectedIndex = widget.navigationShell.currentIndex;
    final isTablet = isTabletWidth(MediaQuery.of(context).size.width);

    final navChrome = isTablet
        ? AndroidNavRail(
            items: items,
            selectedIndex: selectedIndex,
            onTap: _go,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'ThkTree',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          )
        : AndroidNavBar(
            items: items,
            selectedIndex: selectedIndex,
            onTap: _go,
          );

    final chrome = isTablet
        ? SafeArea(child: navChrome)
        : SafeArea(
            top: false,
            bottom: true,
            child: navChrome,
          );

    return Theme(
      data: androidTheme(),
      child: isTablet
          ? Row(
              children: [
                Material(
                  color: AppColors.surface,
                  child: chrome,
                ),
                Expanded(
                  child: ColoredBox(
                    color: AppColors.pageBg,
                    child: widget.navigationShell,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: ColoredBox(
                    color: AppColors.pageBg,
                    child: widget.navigationShell,
                  ),
                ),
                Material(
                  color: AppColors.surface,
                  child: chrome,
                ),
              ],
            ),
    );
  }
}
