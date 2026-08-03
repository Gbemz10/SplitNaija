import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/auth_widgets.dart';
import 'personal_info_screen.dart';

class CreatePasswordScreen extends StatefulWidget {
  const CreatePasswordScreen({super.key, required this.phoneNumber, required this.code});

  final String phoneNumber;
  final String code;

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final _passwordController = TextEditingController();
  String _password = '';

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

  void _continue() {
    if (!_isValid) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonalInfoScreen(
          phoneNumber: widget.phoneNumber,
          code: widget.code,
          password: _password,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      totalSteps: 4,
      currentStep: 3,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeadline('Create a password'),
          const SizedBox(height: kSpacingLg),
          AuthTextField(
            label: 'Create password',
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            onChanged: (v) => setState(() => _password = v),
          ),
          const SizedBox(height: kSpacingMd),
          PasswordRequirements(password: _password),
        ],
      ),
      bottomButton: AuthPrimaryButton(label: 'Next', onPressed: _isValid ? _continue : null),
    );
  }
}
