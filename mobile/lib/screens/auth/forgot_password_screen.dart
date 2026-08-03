import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../utils/phone.dart';
import '../../widgets/async_view.dart';
import '../../widgets/auth_widgets.dart';
import 'otp_verify_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!isLikelyValidNigerianPhone(_phoneController.text)) {
      setState(() => _error = 'Enter a valid Nigerian phone number.');
      return;
    }
    final phone = toE164Nigeria(_phoneController.text);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().forgotPassword(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(phoneNumber: phone, purpose: OtpPurpose.forgotPassword),
        ),
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
      currentStep: 1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeadline('Reset your password'),
          const SizedBox(height: kSpacingSm),
          const Text(
            "Enter the number on your account and we'll send you a code to reset your password.",
            style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: kSpacingXl),
          AuthTextField(
            label: 'Mobile number',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixText: '+234  ',
            autofocus: true,
          ),
          if (_error != null) AuthErrorText(_error!),
        ],
      ),
      bottomButton: AuthPrimaryButton(label: 'Next', onPressed: _continue, loading: _loading),
    );
  }
}
