import 'package:flutter/cupertino.dart';

/// iOS 风格导航栏，支持 Large Title 和 Inline Title 双模式。
///
/// 使用 [ThkNavBar.large] 创建大标题模式（列表页），滚动时自动收为 inline。
/// 使用 [ThkNavBar.inline] 创建固定小标题模式（详情页）。
///
/// 示例：
/// ```dart
/// ThkNavBar.large(title: '设置', trailing: addButton)
/// ThkNavBar.inline(title: '详情', leading: backButton)
/// ```
class ThkNavBar {
  ThkNavBar._();

  /// Large Title 模式导航栏。
  ///
  /// 基于 [CupertinoSliverNavigationBar]，需要在 [CustomScrollView] 中使用。
  /// 滚动时标题会自动从 large 收缩为 inline。
  static CupertinoSliverNavigationBar large({
    required String title,
    Widget? leading,
    Widget? trailing,
    Widget? middle,
    String? previousPageTitle,
    bool alwaysShowMiddle = false,
    EdgeInsetsDirectional? padding,
    Border? border,
    Color? backgroundColor,
  }) {
    return CupertinoSliverNavigationBar(
      largeTitle: Text(title),
      leading: leading,
      trailing: trailing,
      middle: middle,
      previousPageTitle: previousPageTitle,
      alwaysShowMiddle: alwaysShowMiddle,
      padding: padding,
      border: border,
      backgroundColor: backgroundColor,
    );
  }

  /// Inline Title 模式导航栏。
  ///
  /// 基于 [CupertinoNavigationBar]，标题固定显示在导航栏中央。
  static CupertinoNavigationBar inline({
    required String title,
    Widget? leading,
    Widget? trailing,
    Widget? middle,
    String? previousPageTitle,
    bool automaticallyImplyLeading = true,
    bool automaticallyImplyMiddle = true,
    EdgeInsetsDirectional? padding,
    Border? border,
    Color? backgroundColor,
    VoidCallback? onTitleTap,
  }) {
    return CupertinoNavigationBar(
      middle: middle ?? GestureDetector(
        onTap: onTitleTap,
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
      leading: leading,
      trailing: trailing,
      previousPageTitle: previousPageTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      automaticallyImplyMiddle: automaticallyImplyMiddle,
      padding: padding,
      border: border,
      backgroundColor: backgroundColor,
    );
  }
}

/// 封装了 [CupertinoPageScaffold] + [CustomScrollView] + [ThkNavBar.large] 的便捷 Scaffold。
///
/// 用于需要 Large Title 效果的页面，自动处理 sliver 结构。
class ThkLargeTitlePage extends StatelessWidget {
  /// 创建一个大标题页面。
  const ThkLargeTitlePage({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.middle,
    this.previousPageTitle,
    this.children = const [],
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final Widget? middle;
  final String? previousPageTitle;
  final List<Widget> children;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      child: CustomScrollView(
        slivers: [
          ThkNavBar.large(
            title: title,
            leading: leading,
            trailing: trailing,
            middle: middle,
            previousPageTitle: previousPageTitle,
          ),
          SliverList(
            delegate: SliverChildListDelegate(children),
          ),
        ],
      ),
    );
  }
}
