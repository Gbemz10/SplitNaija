import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

/// Handles phone+OTP auth (PRD §7.1) and persists the session token in
/// secure storage (Keychain on iOS, EncryptedSharedPreferences on Android).
class AuthService {
  AuthService(this._api);

  final ApiClient _api;
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'splitnaija_token';

  Future<void> requestOtp(String phoneNumber) async {
    await _api.post('/auth/otp/request', {'phoneNumber': phoneNumber});
  }

  Future<String> verifyOtp(String phoneNumber, String code, {String? displayName}) async {
    final data = await _api.post('/auth/otp/verify', {
      'phoneNumber': phoneNumber,
      'code': code,
      if (displayName != null) 'displayName': displayName,
    });
    final token = data['token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    _api.setAuthToken(token);
    return token;
  }

  Future<String?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null) _api.setAuthToken(token);
    return token;
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    _api.setAuthToken(null);
  }
}
