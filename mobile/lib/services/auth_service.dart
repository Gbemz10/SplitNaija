import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Sentinel for [AuthService.updateProfile]'s optional `photoUrl` param —
/// lets `null` mean "clear the photo" while omitting the argument entirely
/// means "leave it alone". Declared locally: privacy (`_`-prefixed) is
/// per-file in Dart, so this doesn't reuse models.dart's own `_unset`.
const _unset = Object();

/// Handles phone+OTP auth and persists the session token + current user in
/// secure storage (Keychain on iOS, EncryptedSharedPreferences on Android).
class AuthService extends ChangeNotifier {
  AuthService(this._api);

  final ApiClient _api;
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'splitnaija_token';
  static const _userKey = 'splitnaija_user';

  User? _currentUser;
  User? get currentUser => _currentUser;

  /// Set once via [attachPushService] from main.dart after both services
  /// exist — a pair of callbacks rather than a constructor param, since
  /// PushService itself needs a reference back to this AuthService (to know
  /// who's signed in) and Dart doesn't love two classes constructor-
  /// depending on each other. Left null if push was never wired up (e.g. no
  /// Firebase project configured yet), in which case every call site below
  /// is just a no-op.
  Future<void> Function()? _registerDeviceForPush;
  Future<void> Function()? _unregisterDeviceFromPush;

  void attachPushService({
    required Future<void> Function() onSignedIn,
    required Future<void> Function() onSignedOut,
  }) {
    _registerDeviceForPush = onSignedIn;
    _unregisterDeviceFromPush = onSignedOut;
  }

  /// Sends a 6-digit SMS code to [phoneNumber]. Used both to kick off
  /// signup (verify the number is real) and forgot-password (prove the
  /// caller owns the number before letting them set a new password).
  Future<void> requestOtp(String phoneNumber) async {
    await _api.post('/auth/otp/request', {'phoneNumber': phoneNumber});
  }

  /// Checks a code without consuming it, for immediate "wrong code"
  /// feedback right on the OTP-entry screen. The real, consuming check
  /// still happens in [signup]/[resetPassword] — this is just a peek so a
  /// random 6 digits doesn't silently sail through the rest of the wizard.
  Future<bool> checkOtp({required String phoneNumber, required String code}) async {
    final data = await _api.post('/auth/otp/check', {
      'phoneNumber': phoneNumber,
      'code': code,
    });
    return data['valid'] as bool;
  }

  /// Creates a new account. The OTP [code] is also (re-)checked here,
  /// consuming it this time — [checkOtp] earlier only peeked.
  Future<void> signup({
    required String phoneNumber,
    required String code,
    required String password,
    required String displayName,
  }) async {
    final data = await _api.post('/auth/signup', {
      'phoneNumber': phoneNumber,
      'code': code,
      'password': password,
      'displayName': displayName,
    });
    await _persistSession(data);
  }

  Future<void> login({required String phoneNumber, required String password}) async {
    final data = await _api.post('/auth/login', {
      'phoneNumber': phoneNumber,
      'password': password,
    });
    await _persistSession(data);
  }

  /// Kicks off the forgot-password flow — sends an OTP, but only if an
  /// account actually exists for this number (the backend 404s otherwise).
  Future<void> forgotPassword(String phoneNumber) async {
    await _api.post('/auth/password/forgot', {'phoneNumber': phoneNumber});
  }

  /// Completes forgot-password. Doesn't sign the user in — they land back
  /// on the login screen and sign in with the new password, same as most
  /// apps do after a reset.
  Future<void> resetPassword({
    required String phoneNumber,
    required String code,
    required String newPassword,
  }) async {
    await _api.post('/auth/password/reset', {
      'phoneNumber': phoneNumber,
      'code': code,
      'newPassword': newPassword,
    });
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    _api.setAuthToken(token);
    _currentUser = user;
    notifyListeners();
    unawaited(_registerDeviceForPush?.call());
  }

  /// Restores a saved session. Shows the cached user immediately (so the
  /// app doesn't sit on a spinner waiting on the network for something
  /// already known), then kicks off a background refresh from `GET /auth/me`
  /// so any drift between what's cached and what's actually saved
  /// server-side (e.g. fields added to the client after this user's data
  /// was last cached — bankCode/accountNumber/accountName were a real
  /// instance of this) self-heals on the next launch instead of staying
  /// stuck. The refresh is fire-and-forget: offline or a slow network just
  /// means the cached copy keeps being used, same as before this existed.
  Future<bool> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return false;
    _api.setAuthToken(token);

    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      _currentUser = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    }
    notifyListeners();
    unawaited(refreshCurrentUser());
    unawaited(_registerDeviceForPush?.call());
    return true;
  }

  /// Re-fetches the signed-in user from the server and updates the cache —
  /// see the note on [restoreSession] for why this exists. Silently does
  /// nothing on failure (no network, expired token, etc.) rather than
  /// throwing, since callers use this to opportunistically freshen already-
  /// displayed data, not as a load-bearing fetch.
  Future<void> refreshCurrentUser() async {
    try {
      final data = await _api.get('/auth/me');
      updateCurrentUser(User.fromJson(data));
    } catch (_) {
      // Best-effort — the cached user (if any) stays as-is.
    }
  }

  /// Call after successfully setting up a payout account so `currentUser`
  /// reflects it without needing a full re-login.
  void updateCurrentUser(User user) {
    _currentUser = user;
    _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    notifyListeners();
  }

  /// Edits the signed-in user's own display name and/or photo. Pass
  /// [photoUrl] as `null` explicitly to remove an existing photo — omit it
  /// entirely to leave it untouched.
  Future<void> updateProfile({String? displayName, Object? photoUrl = _unset}) async {
    final body = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (!identical(photoUrl, _unset)) 'photoUrl': photoUrl,
    };
    final data = await _api.patch('/auth/me', body);
    updateCurrentUser(User.fromJson(data));
  }

  /// Changes the signed-in user's password. Requires [currentPassword] —
  /// there's no OTP step here (unlike [resetPassword]) because the person
  /// already has a valid session and knows their current password; that's
  /// the confirmation. Throws [ApiException] with a 401 if it's wrong.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _api.patch('/auth/me/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  /// Permanently ends this account. The backend doesn't hard-delete the
  /// row (shared group/expense history stays intact for other members) but
  /// scrubs every personal identifier and blocks future login — from here
  /// it's gone. Requires the current password as a last confirmation since
  /// this can't be undone. Caller is responsible for navigating to Login
  /// afterward; this only clears the local session.
  Future<void> deleteAccount({required String password}) async {
    await _api.delete('/auth/me', body: {'password': password});
    await logout();
  }

  Future<void> logout() async {
    // Must happen before the auth token is cleared below — the backend
    // route this hits requires a valid session to know whose device-token
    // list to remove this device from. Best-effort: if it fails (offline,
    // say), the token just sits there until Firebase eventually reports it
    // dead, rather than blocking sign-out on it.
    await _unregisterDeviceFromPush?.call();
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    _api.setAuthToken(null);
    _currentUser = null;
    notifyListeners();
  }
}