import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/auth_widgets.dart';
import 'create_password_screen.dart';
import 'reset_password_screen.dart';

enum OtpPurpose { signup, forgotPassword }

/// Matches the backend's OTP_TTL_MINUTES in services/otp.ts — keep these in
/// sync if that ever changes.
const _otpTtl = Duration(minutes: 10);

/// Shared "enter the code we sent you" screen for both signup and
/// forgot-password. Tapping Next does an eager, non-consuming check so a
/// wrong code is rejected right here — the code then travels forward and
/// gets checked (and consumed) for real, together with the password
/// (signup) or new password (reset), by whichever screen comes next.
class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.phoneNumber,
    required this.purpose,
  });

  final String phoneNumber;
  final OtpPurpose purpose;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  String _code = '';
  bool _resending = false;
  bool _checking = false;
  String? _error;
  String? _info;

  Timer? _ticker;
  late Duration _remaining = _otpTtl;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _ticker?.cancel();
    setState(() => _remaining = _otpTtl);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds <= 1) {
        timer.cancel();
        setState(() => _remaining = Duration.zero);
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  String get _remainingLabel {
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      final auth = context.read<AuthService>();
      if (widget.purpose == OtpPurpose.signup) {
        await auth.requestOtp(widget.phoneNumber);
      } else {
        await auth.forgotPassword(widget.phoneNumber);
      }
      if (mounted) {
        setState(() => _info = 'A new code is on its way.');
        _startCountdown();
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _continue() async {
    if (_code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final valid = await context.read<AuthService>().checkOtp(
            phoneNumber: widget.phoneNumber,
            code: _code,
          );
      if (!valid) {
        if (mounted) setState(() => _error = 'That code is incorrect or has expired.');
        return;
      }
      if (!mounted) return;
      final route = widget.purpose == OtpPurpose.signup
          ? MaterialPageRoute(
              builder: (_) => CreatePasswordScreen(phoneNumber: widget.phoneNumber, code: _code),
            )
          : MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(phoneNumber: widget.phoneNumber, code: _code),
            );
      Navigator.of(context).push(route);
    } catch (e) {
      if (mounted) setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining == Duration.zero;

    return AuthScaffold(
      totalSteps: widget.purpose == OtpPurpose.signup ? 4 : 3,
      currentStep: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeadline('Verify OTP'),
          const SizedBox(height: kSpacingLg),
          Text(
            'We sent a code to ${widget.phoneNumber}.',
            style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: kSpacingLg),
          OtpCodeInput(onChanged: (code) => setState(() => _code = code)),
          const SizedBox(height: kSpacingMd),
          Text(
            expired ? 'Code expired' : 'Code expires in $_remainingLabel',
            style: TextStyle(
              color: expired ? const Color(0xFFDC2626) : const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: kSpacingSm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _resending ? null : _resend,
              style: TextButton.styleFrom(
                foregroundColor: kBrandPurple,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Resend the code', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          if (_info != null) ...[
            const SizedBox(height: kSpacingSm),
            Text(_info!, style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w500)),
          ],
          if (_error != null) AuthErrorText(_error!),
        ],
      ),
      bottomButton: AuthPrimaryButton(label: 'Next', onPressed: _continue, loading: _checking),
    );
  }
}
