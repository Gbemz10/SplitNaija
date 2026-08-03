import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/auth_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.phoneNumber, required this.code});

  final String phoneNumber;
  final String code;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  String _password = '';
  bool _loading = false;
  String? _error;

  bool get _isValid => _password.length >= 8 && _password.length <= 20 && _hasTwoKinds;

  bool get _hasTwoKinds {
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(_password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(_password);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(_password);
    return [hasLetter, hasNumber, hasSymbol].where((met) => met).length >= 2;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().resetPassword(
            phoneNumber: widget.phoneNumber,
            code: widget.code,
            newPassword: _password,
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Text('Password updated, log in with your new password.')),
      );
    } catch (e) {
      setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      totalSteps: 3,
      currentStep: 3,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeadline('Create a new password'),
          const SizedBox(height: kSpacingLg),
          AuthTextField(
            label: 'New password',
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            onChanged: (v) => setState(() => _password = v),
          ),
          const SizedBox(height: kSpacingMd),
          PasswordRequirements(password: _password),
          if (_error != null) AuthErrorText(_error!),
        ],
      ),
      bottomButton: AuthPrimaryButton(
        label: 'Reset password',
        onPressed: _isValid ? _submit : null,
        loading: _loading,
      ),
    );
  }
}
