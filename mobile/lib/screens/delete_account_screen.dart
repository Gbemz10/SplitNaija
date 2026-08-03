import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/bouncing_dots.dart';
import '../widgets/brand_button.dart';
import 'login_screen.dart';

/// A full screen, not just a dialog — deleting an account needs the
/// password re-entered (the backend's last confirmation before it scrubs
/// personal data for good), and that needs its own field, validation, and
/// error state that a quick yes/no dialog doesn't have room for. The
/// destructive-dialog pattern used elsewhere (delete group, delete
/// settlement) is for single-tap confirmations with nothing to type.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  bool _confirmedUnderstanding = false;
  bool _deleting = false;
  String? _validationError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() => _validationError = null);
    if (!_confirmedUnderstanding) {
      setState(() => _validationError = 'Confirm you understand this can\'t be undone.');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _validationError = 'Enter your password to confirm.');
      return;
    }

    setState(() => _deleting = true);
    try {
      await context.read<AuthService>().deleteAccount(password: _passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const dangerColor = Color(0xFFD32F2F);
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingMd, kSpacingLg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.of(context).maybePop(),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.arrow_back, color: Colors.black, size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: kSpacingSm),
                        const Text(
                          'Delete account',
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(kSpacingMd),
                            decoration: BoxDecoration(
                              color: dangerColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(kRadius),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: dangerColor, size: 22),
                                const SizedBox(width: kSpacingSm),
                                Expanded(
                                  child: Text(
                                    'This signs you out for good. Your name, photo, phone number, '
                                    'and payout details are permanently removed and can\'t be recovered. '
                                    'Expenses and settlements you\'re part of stay visible to your other '
                                    'group members, since it\'s their shared history too.',
                                    style: TextStyle(color: dangerColor, fontWeight: FontWeight.w500, fontSize: 13, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: kSpacingLg),
                          BrandTextField(
                            controller: _passwordController,
                            label: 'Confirm your password',
                            obscureText: true,
                          ),
                          const SizedBox(height: kSpacingMd),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(kRadius),
                              onTap: () => setState(() => _confirmedUnderstanding = !_confirmedUnderstanding),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: kSpacingXs),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: _confirmedUnderstanding,
                                      activeColor: dangerColor,
                                      onChanged: (v) => setState(() => _confirmedUnderstanding = v ?? false),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 14),
                                        child: Text(
                                          'I understand this can\'t be undone.',
                                          style: TextStyle(color: Colors.black.withOpacity(0.7), fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_validationError != null) ...[
                            const SizedBox(height: kSpacingSm),
                            Text(
                              _validationError!,
                              style: const TextStyle(color: dangerColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                          const SizedBox(height: kSpacingLg),
                          FilledButton(
                            onPressed: _deleting ? null : _delete,
                            style: FilledButton.styleFrom(
                              backgroundColor: dangerColor,
                              disabledBackgroundColor: dangerColor.withOpacity(0.4),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
                            ),
                            child: _deleting
                                ? const BouncingDots(color: Colors.white, size: 6)
                                : const Text(
                                    'Permanently delete my account',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
