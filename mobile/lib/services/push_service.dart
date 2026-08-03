import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_client.dart';

/// Wires Firebase Cloud Messaging into the app: requests notification
/// permission, grabs this device's FCM token, and keeps the backend's
/// record of it in sync via [registerCurrentDevice]/[unregisterCurrentDevice]
/// — called from AuthService at the actual sign-in/sign-out points (see
/// `attachPushService` in auth_service.dart), not reactively here, so
/// sign-out can unregister the token *before* the session's cleared.
///
/// Entirely best-effort and safe to call regardless of whether push is
/// actually set up: if there's no Firebase project configured yet (no
/// `google-services.json` dropped into android/app/), [initialize] just
/// returns quietly and every other method becomes a no-op — exactly like
/// the backend side no-ops without a service account key. See
/// PUSH_NOTIFICATIONS_SETUP.md in the repo root for the one-time setup this
/// depends on.
class PushService {
  PushService(this._api);
  final ApiClient _api;

  String? _deviceToken;
  bool _ready = false;

  /// Called for a message that arrives while the app is in the foreground.
  /// FCM only auto-shows a system notification when the app is backgrounded
  /// or terminated — in the foreground it's silent by design, so the UI
  /// layer (main.dart) hooks this to show its own banner instead.
  void Function(RemoteMessage message)? onForegroundMessage;

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // No google-services.json / no Firebase project set up yet. Push
      // just doesn't work until that's done; nothing else depends on it.
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    _deviceToken = await messaging.getToken();
    _ready = true;

    // A token can rotate (app reinstall, backup restore, etc.) — re-send it
    // whenever that happens rather than only ever registering the first one.
    messaging.onTokenRefresh.listen((token) {
      _deviceToken = token;
      unawaited(registerCurrentDevice());
    });

    FirebaseMessaging.onMessage.listen((message) {
      onForegroundMessage?.call(message);
    });
  }

  Future<void> registerCurrentDevice() async {
    if (!_ready || _deviceToken == null) return;
    try {
      await _api.post('/auth/me/push-token', {'token': _deviceToken});
    } catch (_) {
      // Best-effort — will retry on the next token refresh or app launch.
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (!_ready || _deviceToken == null) return;
    try {
      await _api.delete('/auth/me/push-token', body: {'token': _deviceToken});
    } catch (_) {
      // Best-effort — see the note in AuthService.logout() on why this
      // isn't allowed to block sign-out.
    }
  }
}
