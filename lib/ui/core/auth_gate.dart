import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/services/auto_backup_service.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
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
      if (mounted) {
        setState(() => _authenticated = true);
        _triggerAutoBackup();
      }
      return;
    }

    final biometric = ref.read(biometricServiceProvider);
    final canAuth = await biometric.canAuthenticate();
    if (!canAuth) {
      if (mounted) {
        setState(() => _authenticated = true);
        _triggerAutoBackup();
      }
      return;
    }

    _authenticating = true;
    final ok = await biometric.authenticate();
    _authenticating = false;
    if (mounted && ok) {
      setState(() => _authenticated = true);
      _triggerAutoBackup();
    }
    // If failed, stay on lock screen — user can tap to retry.
  }

  /// 认证成功后触发自动备份（前台补偿：超 24h 备份一次到本地）
  void _triggerAutoBackup() {
    final paths = ref.read(appPathsProvider).value;
    if (paths == null) return;
    final settings =
        ref.read(settingsControllerProvider).whenOrNull(data: (s) => s);
    if (settings == null) return;
    unawaited(_doAutoBackup(paths, settings));
  }

  Future<void> _doAutoBackup(AppPaths paths, AppSettings settings) async {
    if (!settings.autoBackupEnabled) return;
    final service = AutoBackupService(paths: paths);
    final didBackup = await service.maybeBackup(
      settings: settings,
      appVersion: '1.0.0', // TODO: package_info
    );
    if (didBackup) {
      await ref
          .read(settingsControllerProvider.notifier)
          .saveLastAutoBackupAt(DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always keep widget.child in a stable position in the tree to avoid
    // tearing down the entire InheritedWidget subtree (MediaQuery,
    // Localizations, etc.) when toggling the lock screen.
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (!_authenticated) ...[
          // Dim the app content and absorb all touches.
          const Positioned.fill(
            child: ColoredBox(color: Color(0xF0000000)),
          ),
          // Lock overlay.
          GestureDetector(
            onTap: _authenticateIfNeeded,
            behavior: HitTestBehavior.opaque,
            child: const _LockScreen(),
          ),
        ],
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
        backgroundColor: const Color(0x00000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.lock_fill,
                size: 64,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 16),
              Text(
                'ThkTree 已锁定',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '请使用 Face ID 解锁',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 24),
              Text(
                '点击屏幕重试',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
