import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/group_service.dart';
import 'screens/login_screen.dart';
import 'screens/groups_screen.dart';

void main() {
  runApp(const SplitNaijaApp());
}

class SplitNaijaApp extends StatelessWidget {
  const SplitNaijaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    final authService = AuthService(apiClient);
    final groupService = GroupService(apiClient);

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<AuthService>.value(value: authService),
        Provider<GroupService>.value(value: groupService),
      ],
      child: MaterialApp(
        title: 'SplitNaija',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00A651)), // Nigerian green
          useMaterial3: true,
        ),
        home: _StartupGate(authService: authService),
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

  @override
  void initState() {
    super.initState();
    widget.authService.restoreSession().then((token) {
      setState(() {
        _loggedIn = token != null;
        _checking = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _loggedIn
        ? GroupsScreen(authService: widget.authService)
        : LoginScreen(authService: widget.authService);
  }
}
