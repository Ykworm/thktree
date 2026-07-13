// Android 生物识别 + AuthGate 测试
//
// - BiometricService 通过 provider override 注入 FakeBiometricService，验证
//   canAuthenticate / authenticate 的返回分支。
// - AuthGate 在 faceIdEnabled=false 时不应锁屏；faceIdEnabled=true 且
//   认证成功时应解锁（锁屏消失）。

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/biometric_service.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/auth_gate.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// 可注入结果的假 BiometricService（覆盖 public 方法即可）。
class FakeBiometricService extends BiometricService {
  bool canAuthResult = true;
  bool authResult = true;

  @override
  Future<bool> canAuthenticate() async => canAuthResult;

  @override
  Future<bool> authenticate({String reason = ''}) async => authResult;
}

/// 假 SettingsController：build() 直接返回注入的 AppSettings，
/// 避免真实的 settingsStore 磁盘/平台读取。
class _FakeSettingsController extends SettingsController {
  final AppSettings _settings;
  _FakeSettingsController(this._settings);

  @override
  Future<AppSettings> build() async => _settings;
}

AppPaths _fakePaths() => AppPaths(
      rootDir: Directory.systemTemp,
      themesDir: Directory.systemTemp,
      logsDir: Directory.systemTemp,
      tempDir: Directory.systemTemp,
      backupsDir: Directory.systemTemp,
      indexDbPath: '${Directory.systemTemp.path}/index.sqlite',
      appLogPath: '${Directory.systemTemp.path}/app.log',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricService（provider override）', () {
    test('canAuthenticate / authenticate 返回注入值', () async {
      final fake = FakeBiometricService()
        ..canAuthResult = true
        ..authResult = true;
      final container = ProviderContainer(
        overrides: [biometricServiceProvider.overrideWithValue(fake)],
      );
      final svc = container.read(biometricServiceProvider);
      expect(await svc.canAuthenticate(), isTrue);
      expect(await svc.authenticate(), isTrue);
      container.dispose();
    });

    test('canAuthenticate=false / authenticate=false 时返回 false', () async {
      final fake = FakeBiometricService()
        ..canAuthResult = false
        ..authResult = false;
      final container = ProviderContainer(
        overrides: [biometricServiceProvider.overrideWithValue(fake)],
      );
      final svc = container.read(biometricServiceProvider);
      expect(await svc.canAuthenticate(), isFalse);
      expect(await svc.authenticate(), isFalse);
      container.dispose();
    });
  });

  group('AuthGate 锁屏/解锁', () {
    testWidgets('faceIdEnabled=false → 直接进入，不锁屏', (tester) async {
      final container = ProviderContainer(overrides: [
        settingsControllerProvider.overrideWith(
          () => _FakeSettingsController(AppSettings(
            localeLanguageCode: 'zh',
            faceIdEnabled: false,
            darkMode: false,
            autoBackupEnabled: false,
          )),
        ),
        appPathsProvider.overrideWithValue(AsyncData(_fakePaths())),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
      ]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: AuthGate(
            child: Container(key: const ValueKey('child')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('child')), findsOneWidget);
      expect(find.text('ThkTree 已锁定'), findsNothing);
      container.dispose();
    });

    testWidgets('faceIdEnabled=true + 认证成功 → 锁屏后解锁', (tester) async {
      final fake = FakeBiometricService()
        ..canAuthResult = true
        ..authResult = true;
      final container = ProviderContainer(overrides: [
        settingsControllerProvider.overrideWith(
          () => _FakeSettingsController(AppSettings(
            localeLanguageCode: 'zh',
            faceIdEnabled: true,
            darkMode: false,
            autoBackupEnabled: false,
          )),
        ),
        appPathsProvider.overrideWithValue(AsyncData(_fakePaths())),
        biometricServiceProvider.overrideWithValue(fake),
      ]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: AuthGate(
            child: Container(key: const ValueKey('child')),
          ),
        ),
      );
      // 认证是异步的（postFrameCallback 触发），等其完成
      await tester.pumpAndSettle();
      // 认证成功后不应再显示锁屏
      expect(find.text('ThkTree 已锁定'), findsNothing,
          reason: '认证成功后锁屏应消失');
      expect(find.byKey(const ValueKey('child')), findsOneWidget);
      container.dispose();
    });
  });
}
