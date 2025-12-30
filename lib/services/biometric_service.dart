import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  static const String _lockKey = 'biometric_lock_enabled';

  Future<bool> isBiometricAvailable() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  Future<bool> isLockEnabled() async {
    final String? value = await _storage.read(key: _lockKey);
    return value == 'true';
  }

  Future<void> setLockEnabled(bool enabled) async {
    await _storage.write(key: _lockKey, value: enabled.toString());
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access your secure chats',
      );
    } catch (e) {
      print('Biometric Error: $e');
      return false;
    }
  }
}
