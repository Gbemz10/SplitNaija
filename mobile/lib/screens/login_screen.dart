import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../utils/phone.dart';
import '../widgets/async_view.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/pie_logo.dart';
import 'auth/forgot_password_screen.dart';
import 'auth/get_started_screen.dart';
import 'main_shell.dart';

/// The default screen after the splash animation for a signed-out user.
/// Phone + password — no email, no country picker (Nigeria-only).
///
/// Layout: a purple hero header (logo + greeting, scattered with small
/// "confetti" chips in the pie palette — a nod to slices/shares, not just
/// generic decoration) over a white sheet with rounded top corners holding
/// the actual form. Same idea Cash App/Duolingo/Robinhood variously use for
/// auth screens: a branded block up top, a neutral card for the task below.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!isLikelyValidNigerianPhone(_phoneController.text)) {
      setState(() => _error = 'Enter a valid Nigerian phone number.');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().login(
            phoneNumber: toE164Nigeria(_phoneController.text),
            password: _passwordController.text,
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The header is dark purple, so status bar icons/time need to be
      // light to stay readable — without this they default to dark on
      // most devices and disappear against the background.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // White, not purple — the purple only lives in the header
        // Container below. If this were purple, the bottom safe-area
        // inset (home indicator strip) would show a stray sliver of
        // purple under the white card instead of matching it.
        backgroundColor: Colors.white,
        body: Column(
          children: [
            const _Header(),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: Align(
                    // Align(topCenter), not Center — Center would give the
                    // scroll view loose constraints, which makes it shrink
                    // to its content height and then center that (short)
                    // box in the leftover space, pushing the fields down
                    // with dead space above and below. topCenter still
                    // caps width on tablets/desktop/web, but keeps the
                    // fields anchored to the top like a normal form.
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingXl, kSpacingLg, kSpacingLg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuthTextField(
                              label: 'Mobile number',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              prefixText: '+234  ',
                            ),
                            const SizedBox(height: kSpacingMd),
                            AuthTextField(
                              label: 'Password',
                              controller: _passwordController,
                              obscureText: true,
                            ),
                            const SizedBox(height: kSpacingSm),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                        ),
                                style: TextButton.styleFrom(
                                  foregroundColor: kBrandPurple,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Forgot password?',
                                    style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            if (_error != null) AuthErrorText(_error!),
                            const SizedBox(height: kSpacingLg),
                            AuthPrimaryButton(label: 'Log in', onPressed: _login, loading: _loading),
                            const SizedBox(height: kSpacingMd),
                            AuthFooterLink(
                              question: "Don't have an account yet?",
                              actionLabel: 'Sign up',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const GetStartedScreen()),
                              ),
                            ),
                            const SizedBox(height: kSpacingSm),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The purple hero block: logo badge, greeting, subtitle, scattered with
/// small rotated "confetti" chips in the pie palette — a subtle nod to
/// slices/shares rather than generic decoration, cheap to draw (no images),
/// and clipped so they can never overflow the header on any device size.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kBrandPurple, Color(0xFF551FAD)],
          ),
        ),
        child: Stack(
          // `alignment` (not a Center/Align wrapper below) does the
          // horizontal centering on wide screens — Center/Align would
          // expand to fill the *height* the Stack offers too (it's
          // technically bounded, just generously so), which would blow
          // the header up to fill the whole screen instead of sizing to
          // its content. A plain ConstrainedBox only caps width and
          // leaves height alone, so this centers without that side effect.
          alignment: Alignment.topCenter,
          children: [
            Positioned(top: -16, left: 28, child: _confettiChip(kPieColors[1], 26, -18)),
            Positioned(top: 36, right: -14, child: _confettiChip(kPieColors[2], 46, 22)),
            Positioned(bottom: -18, right: 60, child: _confettiChip(kPieColors[4], 34, 14)),
            Positioned(bottom: 22, left: -16, child: _confettiChip(kPieColors[3], 40, -30)),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingXl, kSpacingLg, kSpacingXxl),
                  child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const PieLogo(size: 44),
                        ),
                        const SizedBox(height: kSpacingLg),
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: kSpacingXs),
                        Text(
                          'Log in to split bills and settle up with your crew.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _confettiChip(Color color, double size, double angleDegrees) {
    return Transform.rotate(
      angle: angleDegrees * 3.1415926535 / 180,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.4),
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
      ),
    );
  }
}
