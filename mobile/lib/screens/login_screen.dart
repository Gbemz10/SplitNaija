import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'groups_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  Future<void> _requestOtp() async {
    setState(() => _loading = true);
    try {
      await widget.authService.requestOtp(_phoneController.text.trim());
      setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _error = 'Could not send code — check the number and try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _loading = true);
    try {
      await widget.authService.verifyOtp(
        _phoneController.text.trim(),
        _codeController.text.trim(),
        displayName: 'New User', // TODO: collect this on first signup
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GroupsScreen(authService: widget.authService)),
      );
    } catch (e) {
      setState(() => _error = 'Invalid code. Please try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'SplitNaija',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_otpSent,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Enter OTP',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : (_otpSent ? _verifyOtp : _requestOtp),
                child: Text(_loading ? 'Please wait...' : (_otpSent ? 'Verify' : 'Send code')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
