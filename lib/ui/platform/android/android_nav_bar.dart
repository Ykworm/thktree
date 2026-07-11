// Android 导航表现层（与平台无关的纯展示组件，便于单测）。
//
// - 手机：底部 NavigationBar（Material 3）。
// - 平板 large-screen：左侧 NavigationRail。
// 选中态用 accent（来自 ColorScheme.primary），未选中用 textTertiary 一族，
// 与 iOS/macOS 壳的语义一致（handoff §2.7 导航范式）。
//
// 图标用 Material Icons（SF Symbols 在 Android 不可用）。选中的强调色完全由
// androidColorScheme() 的 primary 决定，不在此处写任何裸色。

import 'package:flutter/material.dart';

/// 单个导航项。icon 同时用于选中/未选中（NavigationBar 会按 selection 自动着色），
/// 避免依赖 Android 缺失的 SF Symbols 变体。
class AndroidNavItem {
  const AndroidNavItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

/// 手机底部导航栏。
class AndroidNavBar extends StatelessWidget {
  const AndroidNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<AndroidNavItem> items;
  final int selectedIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onTap,
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.icon),
            label: item.label,
          ),
      ],
    );
  }
}

/// 平板 large-screen 左侧导航栏。
class AndroidNavRail extends StatelessWidget {
  const AndroidNavRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.leading,
  });

  final List<AndroidNavItem> items;
  final int selectedIndex;
  final void Function(int) onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onTap,
      useIndicator: true,
      leading: leading,
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: Icon(item.icon),
            label: Text(item.label),
          ),
      ],
    );
  }
}
