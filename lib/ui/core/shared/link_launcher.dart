import 'package:flutter/cupertino.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';

/// 处理 markdown 里链接点击：仅放行 http/https，用应用内浏览器浮层
/// （iOS = SFSafariViewController / Android = Chrome Custom Tabs）打开。
///
/// 走浏览器进程，不受 App 的 ATS / cleartext 约束，http 链接也能直接加载；
/// 同时共享系统浏览器的登录态、地址栏可见，安全性等同于跳外部浏览器。
///
/// 非 http/https（javascript: / data: / file: / tel: 等）静默忽略，避免不可信
/// 内容（LLM 输出的链接可能被幻觉/投毒）触发意外行为。
///
/// 作为 `GptMarkdown.onLinkTap` 的统一回调。
Future<void> openMarkdownLink(
  BuildContext context,
  String url, [
  String? title,
]) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (uri.scheme != 'http' && uri.scheme != 'https') return;

  try {
    await launchUrl(
      uri,
      // Android Custom Tabs
      customTabsOptions: CustomTabsOptions(
        colorSchemes: CustomTabsColorSchemes.defaults(
          toolbarColor: AppColors.surface,
        ),
        urlBarHidingEnabled: true,
        showTitle: true,
        closeButton: CustomTabsCloseButton(
          icon: CustomTabsCloseButtonIcons.back,
        ),
      ),
      // iOS SFSafariViewController
      safariVCOptions: SafariViewControllerOptions(
        preferredBarTintColor: AppColors.surface,
        preferredControlTintColor: AppColors.accent,
        barCollapsingEnabled: true,
        dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ThkAlert.show(context: context, message: '无法打开链接');
  }
}
