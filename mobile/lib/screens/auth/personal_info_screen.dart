import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/auth_widgets.dart';
import '../main_shell.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({
    super.key,
    required this.phoneNumber,
    required this.code,
    required this.password,
  });

  final String phoneNumber;
  final String code;
  final String password;

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _termsRecognizer = TapGestureRecognizer();
  final _privacyRecognizer = TapGestureRecognizer();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'Enter your first and last name.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().signup(
            phoneNumber: widget.phoneNumber,
            code: widget.code,
            password: widget.password,
            displayName: '$firstName $lastName',
          );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
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
      totalSteps: 4,
      currentStep: 4,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeadline('Enter personal info'),
          const SizedBox(height: kSpacingLg),
          AuthTextField(
            label: 'Legal first name',
            controller: _firstNameController,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: kSpacingMd),
          AuthTextField(
            label: 'Legal last name',
            controller: _lastNameController,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: kSpacingLg),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.4),
              children: [
                const TextSpan(text: 'By creating a SplitNaija account, you confirm you’re at '
                    'least 18 years old and agree to our '),
                TextSpan(
                  text: 'Terms of Service',
                  style: const TextStyle(color: kBrandPurple, fontWeight: FontWeight.w700),
                  recognizer: _termsRecognizer,
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: const TextStyle(color: kBrandPurple, fontWeight: FontWeight.w700),
                  recognizer: _privacyRecognizer,
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          if (_error != null) AuthErrorText(_error!),
        ],
      ),
      bottomButton: AuthPrimaryButton(
        label: 'Agree and Create Account',
        onPressed: _createAccount,
        loading: _loading,
      ),
    );
  }
}
