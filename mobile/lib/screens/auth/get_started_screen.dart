import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../utils/phone.dart';
import '../../widgets/async_view.dart';
import '../../widgets/auth_widgets.dart';
import 'otp_verify_screen.dart';

/// First screen of the signup wizard, reached from Login's "Sign up" link.
/// Nigeria-only — no country picker — so the number is always sent to the
/// backend as +234XXXXXXXXXX regardless of how the user typed it.
class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
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
      await context.read<AuthService>().requestOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(phoneNumber: phone, purpose: OtpPurpose.signup),
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
      totalSteps: 4,
      currentStep: 1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeadline("Let's get started"),
          const SizedBox(height: kSpacingXl),
          AuthTextField(
            label: 'Mobile number',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixText: '+234  ',
            autofocus: true,
          ),
          const SizedBox(height: kSpacingSm),
          const Text(
            'By continuing, you confirm that you are authorized to use this phone '
            'number and agree to receive an SMS text. Carrier fees may apply.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          if (_error != null) AuthErrorText(_error!),
        ],
      ),
      bottomButton: AuthPrimaryButton(label: 'Next', onPressed: _continue, loading: _loading),
      footer: AuthFooterLink(
        question: 'Already have an account?',
        actionLabel: 'Log in',
        onTap: () => Navigator.of(context).pop(),
      ),
    );
  }
}
