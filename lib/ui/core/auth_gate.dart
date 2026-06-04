import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// Wraps the app and shows a lock screen when biometric auth is required.
/// Listens to app lifecycle to re-authenticate on foreground resume.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> with WidgetsBindingObserver {
  bool _authenticated = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticateIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Only lock if we are NOT in the middle of an auth dialog.
      if (!_authenticating && mounted) {
        setState(() => _authenticated = false);
      }
    } else if (state == AppLifecycleState.resumed) {
      // Only trigger auth if we are currently locked (not already authenticated).
      if (!_authenticated) {
        _authenticateIfNeeded();
      }
    }
  }

  Future<void> _authenticateIfNeeded() async {
    if (_authenticating) return;

    final settingsAsync = ref.read(settingsControllerProvider);
    final settings = settingsAsync.whenOrNull(data: (s) => s);
    if (settings == null || !settings.faceIdEnabled) {
      if (mounted) setState(() => _authenticated = true);
      return;
    }

    final biometric = ref.read(biometricServiceProvider);
    final canAuth = await biometric.canAuthenticate();
    if (!canAuth) {
      if (mounted) setState(() => _authenticated = true);
      return;
    }

    _authenticating = true;
    final ok = await biometric.authenticate();
    _authenticating = false;
    if (mounted && ok) setState(() => _authenticated = true);
    // If failed, stay on lock screen — user can tap to retry.
  }

  @override
  Widget build(BuildContext context) {
    if (_authenticated) return widget.child;

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        // Dimmed background (the actual app content, not interactive).
        IgnorePointer(child: Opacity(opacity: 0.05, child: widget.child)),
        // Lock overlay.
        GestureDetector(
          onTap: _authenticateIfNeeded,
          behavior: HitTestBehavior.opaque,
          child: const _LockScreen(),
        ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemBackground,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.lock_fill,
                size: 64,
                color: CupertinoColors.secondaryLabel,
              ),
              SizedBox(height: 16),
              Text(
                'ThkTree 已锁定',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '请使用 Face ID 解锁',
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              SizedBox(height: 24),
              Text(
                '点击屏幕重试',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.tertiaryLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
