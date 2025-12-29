import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

enum AuthResult { success, failed, canceled, lockedOut, error }

class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isDeviceSupported() => _auth.isDeviceSupported();

  Future<bool> canCheckBiometrics() => _auth.canCheckBiometrics;

  Future<List<BiometricType>> getAvailableBiometrics() =>
      _auth.getAvailableBiometrics();

  Future<AuthResult> authenticate({bool biometricsOnly = false}) async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to continue',
        // Removed 'options' parameter for compatibility with current local_auth version
      );
      return didAuthenticate ? AuthResult.success : AuthResult.failed;
    } on PlatformException catch (e) {
      debugPrint('Auth error: \\${e.code} - \\${e.message}');
      if (e.code == 'LockedOut' || e.code == 'permanentlyLockedOut') {
        return AuthResult.lockedOut;
      }
      return AuthResult.error;
    } on LocalAuthException catch (e) {
      debugPrint('LocalAuthException: \\${e.code}');
      if (e.code == LocalAuthExceptionCode.userCanceled ||
          e.code == LocalAuthExceptionCode.systemCanceled) {
        return AuthResult.canceled;
      }
      return AuthResult.error;
    }
  }

  Future<void> cancelAuthentication() => _auth.stopAuthentication();
}
