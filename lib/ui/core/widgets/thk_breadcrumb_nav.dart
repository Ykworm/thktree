import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

/// 面包屑导航段。
///
/// [label] 是显示文本（如"设置"）。回跳目标用二者之一：
/// - [goPath]：go_router 路由路径（如 `/themes/:id/tree`）。非空时优先用
///   `GoRouter.of(context).go(goPath)` 声明式回跳，让 go_router 自己重建分支栈。
///   **禁止**对 go_router 管理的路由用 `Navigator.popUntil`，否则会把 go_router
///   的 route match list 摘空，崩溃 "You have popped the last page off of the stack"。
/// - [routeName]：普通 Navigator 路由的 `RouteSettings.name`，用 `popUntil` 精确匹配。
///   go_router 路由需在 pageBuilder 的 Page 上显式设 name，Navigator.push 路由用
///   `RouteSettings(name:)`。
class BreadcrumbSegment {
  const BreadcrumbSegment({
    required this.label,
    this.routeName = '',
    this.goPath,
  });

  final String label;
  final String routeName;
  final String? goPath;
}

/// 面包屑导航行。
///
/// 显示为水平排列的灰色小字，用 `/` 分隔。
/// 最后一个段（当前页）不可点击，其余段可点击并跳回对应页面。
///
/// 放在 CupertinoPageScaffold 的 SafeArea 内部、导航栏下方。
class ThkBreadcrumbRow extends StatelessWidget {
  const ThkBreadcrumbRow({super.key, required this.crumbs});

  final List<BreadcrumbSegment> crumbs;

  @override
  Widget build(BuildContext context) {
    if (crumbs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: _buildSegments(context),
      ),
    );
  }

  List<Widget> _buildSegments(BuildContext context) {
    final widgets = <Widget>[];
    for (int i = 0; i < crumbs.length; i++) {
      if (i > 0) {
        widgets.add(_separator(context));
      }
      final isLast = i == crumbs.length - 1;
      widgets.add(_segment(context, crumbs[i], isLast: isLast));
    }
    return widgets;
  }

  Widget _separator(BuildContext context) {
    return Text(
      '/',
      style: TextStyle(
        fontSize: 12,
        color: CupertinoColors.separator.resolveFrom(context),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _segment(BuildContext context, BreadcrumbSegment segment, {required bool isLast}) {
    final isActive = !isLast;
    return GestureDetector(
      onTap: isActive ? () => _popToRoute(context, segment) : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          segment.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w400 : FontWeight.w500,
            color: isActive
                ? CupertinoColors.secondaryLabel.resolveFrom(context)
                : CupertinoColors.label.resolveFrom(context),
          ),
        ),
      ),
    );
  }

  void _popToRoute(BuildContext context, BreadcrumbSegment segment) {
    final goPath = segment.goPath;
    if (goPath != null) {
      // go_router 管理的路由：用声明式导航重建该分支栈。
      // 不能用 Navigator.popUntil —— 会把 go_router 的 route match list 摘空，
      // 触发 "You have popped the last page off of the stack" 断言。
      GoRouter.of(context).go(goPath);
      return;
    }

    final routeName = segment.routeName;
    if (routeName.startsWith('/')) {
      // 仅适用于"真正位于 navigator 栈底"的路由（如 tab 根）。
      // 注意：parentNavigatorKey=root 的全屏覆盖路由（如 /settings）不是栈底，
      // 不能用 isFirst —— 需给目标 Page 设 name 并走下面的 name 匹配分支。
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      // 用 RouteSettings.name 精确匹配，停在目标页。
      // go_router 路由需在 pageBuilder 的 Page 上显式设 name（不是 GoRoute.name，
      // 后者不会传到 navigator Page 的 RouteSettings.name）；
      // Navigator.push 路由用 RouteSettings(name:)。
      Navigator.of(context).popUntil((route) {
        final name = route.settings.name;
        return name == routeName;
      });
    }
  }
}
