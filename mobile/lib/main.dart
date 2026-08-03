import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/activity_service.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/group_service.dart';
import 'services/settlement_service.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const SplitNaijaApp());
}

/// A `StatefulWidget`, not stateless — the services below must be built
/// exactly once and then stay put. They used to be created inline inside a
/// `StatelessWidget.build()`, which Flutter re-runs on every hot reload;
/// each re-run silently replaced the authenticated `ApiClient`/`AuthService`
/// with brand-new, never-`restoreSession()`'d ones (session restore only
/// runs once, in `_StartupGateState.initState()`), so any authenticated
/// call made after a hot reload failed with "Missing auth token" even
/// though the person was still very much logged in. `late final` instance
/// fields on a `State` are initialized once when the State is created, and
/// State survives hot reload as long as the widget tree shape doesn't
/// change — so `build()` re-running here just reuses the same instances.
class SplitNaijaApp extends StatefulWidget {
  const SplitNaijaApp({super.key});

  @override
  State<SplitNaijaApp> createState() => _SplitNaijaAppState();
}

class _SplitNaijaAppState extends State<SplitNaijaApp> {
  late final _apiClient = ApiClient();
  late final _authService = AuthService(_apiClient);
  late final _groupService = GroupService(_apiClient);
  late final _settlementService = SettlementService(_apiClient);
  late final _activityService = ActivityService(_apiClient);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        ChangeNotifierProvider<AuthService>.value(value: _authService),
        Provider<GroupService>.value(value: _groupService),
        Provider<SettlementService>.value(value: _settlementService),
        Provider<ActivityService>.value(value: _activityService),
      ],
      // `AnnotatedRegion` styles are sticky — a screen that requests light
      // (white) status bar icons, like Login's purple header, leaves that
      // style in place on whatever screen comes after it unless something
      // resets it. This root-level region is that reset: it's always
      // there as the fallback once a screen with its own override (e.g.
      // Login) is no longer on top, so white-background screens reliably
      // get dark icons back instead of inheriting invisible white ones.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: MaterialApp(
          title: 'SplitNaija',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: _StartupGate(authService: _authService),
        ),
      ),
    );
  }
}

/// Restores a saved session (if any) before deciding whether to show
/// the login screen or drop straight into the app.
class _StartupGate extends StatefulWidget {
  const _StartupGate({required this.authService});
  final AuthService authService;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _checking = true;
  bool _loggedIn = false;

  // Keep the loading animation on screen for at least this long, even if
  // session restore finishes instantly, so it doesn't flash by unseen.
  // Matches the splash animation's own 3400ms duration, plus a short hold
  // on the finished wordmark so the entrance actually registers.
  static const _minSplashDuration = Duration(milliseconds: 3800);

  @override
  void initState() {
    super.initState();
    Future.wait([
      widget.authService.restoreSession(),
      Future<void>.delayed(_minSplashDuration),
    ]).then((results) {
      if (!mounted) return;
      setState(() {
        _loggedIn = results[0] as bool;
        _checking = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const SplitNaijaSplashScreen();
    }
    return _loggedIn ? const MainShell() : const LoginScreen();
  }
}