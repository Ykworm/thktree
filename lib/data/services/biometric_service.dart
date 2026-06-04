import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  /// Check if the device supports biometric authentication.
  Future<bool> canAuthenticate() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      debugPrint('[BiometricService] canAuthenticate error: $e');
      return false;
    }
  }

  /// Authenticate the user using Face ID / Touch ID.
  /// Falls back to device passcode if biometrics fail.
  /// Returns true if authentication succeeded.
  Future<bool> authenticate({String reason = '请验证身份以访问 ThkTree'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allow device PIN fallback
        ),
      );
    } catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return false;
    }
  }
}
