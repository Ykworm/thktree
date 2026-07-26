import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/widgets/thk_alert.dart';
import 'package:thk_tree/ui/core/widgets/thk_breadcrumb_nav.dart';
import 'package:thk_tree/ui/features/settings/llm_settings_screen.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

class LlmSetupOnboardingRecheckNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Dev / 重置首次引导后，通知 [LlmSetupOnboardingHost] 重新检查是否弹窗。
final llmSetupOnboardingRecheckProvider =
    NotifierProvider<LlmSetupOnboardingRecheckNotifier, int>(
        LlmSetupOnboardingRecheckNotifier.new);

/// 首次启动时弹出 LLM 设置引导，只展示一次。
///
/// 仅在用户位于搜索 tab 且路由为 [/search] 时弹出（reset 后需切回搜索页）。
class LlmSetupOnboardingHost extends ConsumerStatefulWidget {
  const LlmSetupOnboardingHost({
    super.key,
    required this.child,
    required this.searchTabActive,
  });

  final Widget child;
  final bool searchTabActive;

  @override
  ConsumerState<LlmSetupOnboardingHost> createState() =>
      _LlmSetupOnboardingHostState();
}

class _LlmSetupOnboardingHostState extends ConsumerState<LlmSetupOnboardingHost> {
  bool _dialogInFlight = false;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryShowPrompt());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      router.routerDelegate.addListener(_onRouteChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryShowPrompt());
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryShowPrompt());
  }

  @override
  void didUpdateWidget(covariant LlmSetupOnboardingHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchTabActive != widget.searchTabActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryShowPrompt());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(llmSetupOnboardingRecheckProvider);
    ref.listen(settingsControllerProvider, (_, _) => _tryShowPrompt());
    ref.listen(llmSetupOnboardingRecheckProvider, (_, _) => _tryShowPrompt());
    return widget.child;
  }

  bool _isOnSearchPage(BuildContext context) {
    if (!widget.searchTabActive) return false;
    final location = GoRouter.of(context).state.matchedLocation;
    return location == '/search';
  }

  Future<void> _tryShowPrompt() async {
    if (_dialogInFlight || !mounted) return;
    if (!_isOnSearchPage(context)) return;

    final settings = ref.read(settingsControllerProvider).value;
    if (settings == null || settings.llmSetupOnboardingShown) return;

    _dialogInFlight = true;
    try {
      if (!mounted) return;

      final l10n = AppLocalizations.of(context)!;
      await ThkAlert.show(
        context: context,
        title: l10n.llmSetupOnboardingTitle,
        message: l10n.llmSetupOnboardingMessage,
        defaultAction: l10n.llmSetupOnboardingAction,
        onDefault: () {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(
              settings: const RouteSettings(name: 'llm-settings-onboarding'),
              builder: (_) => LlmSettingsScreen(
                parentCrumbs: [
                  BreadcrumbSegment(
                    label: l10n.settingsTabLabel,
                    routeName: 'settings',
                  ),
                ],
              ),
            ),
          );
        },
        cancelAction: l10n.llmSetupOnboardingLater,
      );

      if (!mounted) return;
      await ref
          .read(settingsControllerProvider.notifier)
          .markLlmSetupOnboardingShown();
    } finally {
      _dialogInFlight = false;
    }
  }
}
