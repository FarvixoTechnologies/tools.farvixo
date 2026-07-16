import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for tokens and session data (Android Keystore / iOS
/// Keychain-backed). Never store sensitive values in plain SharedPreferences.
class SecureStorageService {
  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kUserId = 'user_id';
  static const _kLoginProvider = 'login_provider';
  static const _kSessionExpiry = 'session_expiry';
  static const _kBiometricEnabled = 'biometric_enabled';

  Future<String?> get accessToken => _storage.read(key: _kAccessToken);
  Future<void> setAccessToken(String token) =>
      _storage.write(key: _kAccessToken, value: token);

  Future<String?> get refreshToken => _storage.read(key: _kRefreshToken);
  Future<void> setRefreshToken(String token) =>
      _storage.write(key: _kRefreshToken, value: token);

  Future<String?> get userId => _storage.read(key: _kUserId);
  Future<void> setUserId(String id) => _storage.write(key: _kUserId, value: id);

  /// 'email' | 'phone' | 'google' | 'apple' | 'github' | 'guest'
  Future<String?> get loginProvider => _storage.read(key: _kLoginProvider);
  Future<void> setLoginProvider(String provider) =>
      _storage.write(key: _kLoginProvider, value: provider);

  Future<DateTime?> get sessionExpiry async {
    final raw = await _storage.read(key: _kSessionExpiry);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setSessionExpiry(DateTime expiry) =>
      _storage.write(key: _kSessionExpiry, value: expiry.toIso8601String());

  /// Last successful account (kept after logout for biometric quick sign-in).
  static const _kLastUserJson = 'last_user_json';
  Future<String?> get lastUserJson => _storage.read(key: _kLastUserJson);
  Future<void> setLastUserJson(String json) =>
      _storage.write(key: _kLastUserJson, value: json);

  Future<bool> get biometricEnabled async =>
      (await _storage.read(key: _kBiometricEnabled)) == 'true';
  Future<void> setBiometricEnabled(bool enabled) =>
      _storage.write(key: _kBiometricEnabled, value: '$enabled');

  Future<void> clearAll() => _storage.deleteAll();
}
