import 'package:flutter/cupertino.dart';

/// 面包屑导航段。
///
/// [label] 是显示文本（如"设置"），[routeName] 是 CupertinoPageRoute 的 RouteSettings.name，
/// 用于 popUntil 定位目标页面。
class BreadcrumbSegment {
  const BreadcrumbSegment({required this.label, required this.routeName});

  final String label;
  final String routeName;
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
      onTap: isActive ? () => _popToRoute(context, segment.routeName) : null,
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

  void _popToRoute(BuildContext context, String routeName) {
    if (routeName.startsWith('/')) {
      // go_router 路由：pop 到栈底（第一个 Route），保留底层页面
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      // Navigator.push 的路由：用 popUntil 匹配 RouteSettings.name
      Navigator.of(context).popUntil((route) {
        final name = route.settings.name;
        return name == routeName;
      });
    }
  }
}
