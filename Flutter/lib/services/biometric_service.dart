import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric login (fingerprint / Face ID / face unlock).
///
/// All calls are guarded — on unsupported devices or web this degrades to
/// "unavailable" instead of throwing.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> get isAvailable async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user; returns true only on successful authentication.
  Future<bool> authenticate({String reason = 'Sign in to Farvixo'}) async {
    if (!await isAvailable) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric auth failed: ${e.code}');
      return false;
    } catch (_) {
      return false;
    }
  }
}
