import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/brand_button.dart';

/// Reached from Account > Security. Requires the current password rather
/// than an OTP — the person already has a valid session and knows their
/// current password, which is confirmation enough for this (unlike
/// forgot-password, where they have neither).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  String? _validationError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _validationError = null);
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty) {
      setState(() => _validationError = 'Enter your current password.');
      return;
    }
    if (next.length < 8 || next.length > 20) {
      setState(() => _validationError = 'New password must be 8-20 characters.');
      return;
    }
    if (next != confirm) {
      setState(() => _validationError = "New passwords don't match.");
      return;
    }
    if (next == current) {
      setState(() => _validationError = "New password can't be the same as the current one.");
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<AuthService>().changePassword(currentPassword: current, newPassword: next);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          'Change password',
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
                          Text(
                            'Use something you don’t use anywhere else.',
                            style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: kSpacingLg),
                          BrandTextField(
                            controller: _currentController,
                            label: 'Current password',
                            obscureText: true,
                          ),
                          const SizedBox(height: kSpacingMd),
                          BrandTextField(
                            controller: _newController,
                            label: 'New password',
                            obscureText: true,
                            helperText: '8-20 characters',
                          ),
                          const SizedBox(height: kSpacingMd),
                          BrandTextField(
                            controller: _confirmController,
                            label: 'Confirm new password',
                            obscureText: true,
                          ),
                          if (_validationError != null) ...[
                            const SizedBox(height: kSpacingMd),
                            Text(
                              _validationError!,
                              style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w500),
                            ),
                          ],
                          const SizedBox(height: kSpacingLg),
                          BrandButton(label: 'Update password', loading: _saving, onPressed: _save),
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
