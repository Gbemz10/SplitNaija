import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'bouncing_dots.dart';

/// Back arrow + segmented step indicator shared by every screen in the
/// signup wizard and the password-reset flow. Pass `totalSteps: 0` for
/// screens that aren't part of a numbered flow (e.g. plain Login) — the
/// progress bar is simply omitted and the back arrow gets more breathing
/// room instead.
class AuthTopBar extends StatelessWidget {
  const AuthTopBar({
    super.key,
    this.onBack,
    this.totalSteps = 0,
    this.currentStep = 0,
  });

  /// Called when the back arrow is tapped. Defaults to popping the route.
  final VoidCallback? onBack;

  /// Number of segments to draw.
  final int totalSteps;

  /// 1-based index of how many segments should render as "active" (filled).
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          // Plain InkWell around a bare Icon — not IconButton. IconButton's
          // built-in minimum tap target (48x48 by default in Material 3,
          // and it doesn't fully go away just from zeroing padding/
          // constraints) was still insetting the glyph from the screen's
          // left edge, so it never lined up with the body text below it.
          // This has zero inherited padding: its left edge is the icon's
          // left edge, full stop.
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Icon(Icons.arrow_back, color: Colors.black, size: 24),
              ),
            ),
          ),
          const Spacer(),
          if (totalSteps > 0)
            SizedBox(
              width: 56,
              child: Row(
                children: List.generate(totalSteps, (i) {
                  final isLast = i == totalSteps - 1;
                  final active = i < currentStep;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: isLast ? 0.0 : 4.0),
                      height: 3,
                      decoration: BoxDecoration(
                        color: active ? kBrandPurple : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// Large bold screen title used at the top of every auth screen, e.g.
/// "Let's get started", "Create a password".
class AuthHeadline extends StatelessWidget {
  const AuthHeadline(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.15));
  }
}

/// Text field styled to match the auth flow: label always floating inside
/// the box, squarer corners than the rest of the app ([kAuthRadius]), a
/// purple focus ring, and a built-in show/hide toggle when [obscureText].
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefixText,
    this.helperText,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? prefixText;
  final String? helperText;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(kAuthRadius),
      borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
    );

    return TextField(
      controller: widget.controller,
      obscureText: widget.obscureText && _obscured,
      keyboardType: widget.keyboardType,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      textCapitalization: widget.textCapitalization,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        prefixText: widget.prefixText,
        prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
        // Default (auto) behavior: the label sits centered as a placeholder
        // until the field is focused or filled, then floats up to the
        // border line — not pinned there permanently.
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kAuthRadius),
          borderSide: const BorderSide(color: kBrandPurple, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: kSpacingMd, vertical: kSpacingMd),
      ),
    );
  }
}

/// Full-width purple call-to-action button used across the auth flow —
/// squarer corners than [kRadius] elsewhere in the app, per the "shouldn't
/// be as rounded" design note.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kBrandPurple,
          disabledBackgroundColor: kBrandPurple.withOpacity(0.5),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAuthRadius)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: loading ? const BouncingDots(color: Colors.white, size: 6) : Text(label),
      ),
    );
  }
}

/// Live checklist under the password field ("Use 8 to 20 characters", ...),
/// each line turning purple-green with a filled check once satisfied.
class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({super.key, required this.password});
  final String password;

  bool get _hasValidLength => password.length >= 8 && password.length <= 20;

  bool get _hasTwoKinds {
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    final kinds = [hasLetter, hasNumber, hasSymbol].where((met) => met).length;
    return kinds >= 2;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Requirement(met: _hasValidLength, text: 'Use 8 to 20 characters'),
        const SizedBox(height: kSpacingXs),
        _Requirement(
          met: _hasTwoKinds,
          text: 'Use 2 of the following: letters, numbers, or symbols (like !@#\$%^)',
        ),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.met, required this.text});
  final bool met;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 18,
          color: met ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
        ),
        const SizedBox(width: kSpacingSm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: met ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom-of-screen prompt like "Don't have an account yet?  Sign up" —
/// [actionLabel] is rendered as a purple, bold, tappable link.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({super.key, required this.question, required this.actionLabel, required this.onTap});

  final String question;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(question, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: kBrandPurple,
              padding: const EdgeInsets.symmetric(horizontal: kSpacingXs),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Six-box code entry for OTP screens — auto-advances focus as each digit
/// is typed. [onChanged] fires with the concatenated code after every edit.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({super.key, this.length = 6, required this.onChanged});

  final int length;
  final ValueChanged<String> onChanged;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    // Each node gets its own key handler so backspace on an already-empty
    // box jumps back and clears the previous one — otherwise you'd have to
    // tap into every box individually to delete, which is unusable.
    _nodes = List.generate(
      widget.length,
      (i) => FocusNode(
        onKeyEvent: (node, event) {
          final isBackspace = event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace;
          if (isBackspace && _controllers[i].text.isEmpty && i > 0) {
            _controllers[i - 1].clear();
            _nodes[i - 1].requestFocus();
            _emit();
          }
          return KeyEventResult.ignored;
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(_controllers.map((c) => c.text).join());

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    }
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(kAuthRadius),
      borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        return SizedBox(
          width: 44,
          height: 52,
          child: TextField(
            controller: _controllers[i],
            focusNode: _nodes[i],
            autofocus: i == 0,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            keyboardType: TextInputType.number,
            // `maxLength` (even with counterText: '') was the likely cause
            // of digits not rendering — Material's counter/affix layout
            // logic for maxLength fields doesn't always play nicely with a
            // custom font. inputFormatters achieve the same "one digit per
            // box" constraint without touching that code path.
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black),
            decoration: InputDecoration(
              // The default OutlineInputBorder content padding (~20 top +
              // bottom) barely leaves room for a 20px glyph inside a 52px
              // box — that's what was clipping digits down to a sliver.
              // isDense + an explicit small padding fixes it.
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              border: border,
              enabledBorder: border,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kAuthRadius),
                borderSide: const BorderSide(color: kBrandPurple, width: 1.5),
              ),
            ),
            onChanged: (value) => _onChanged(i, value),
          ),
        );
      }),
    );
  }
}

/// Common page shell for every auth screen: back arrow (+ optional step
/// progress) up top, scrollable middle content, and a button (with an
/// optional footer link) pinned to the bottom — the CTA sits in a fixed
/// spot on every reference screen, and this keeps that true even when the
/// keyboard is up or the content is taller than the screen.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    this.onBack,
    this.totalSteps = 0,
    this.currentStep = 0,
    required this.body,
    required this.bottomButton,
    this.footer,
  });

  final VoidCallback? onBack;
  final int totalSteps;
  final int currentStep;
  final Widget body;
  final Widget bottomButton;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          // Caps width on tablets/desktop/web (see kMaxContentWidth) — a
          // no-op on phones, which are already narrower than the cap.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTopBar(onBack: onBack, totalSteps: totalSteps, currentStep: currentStep),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
                      child: body,
                    ),
                  ),
                  bottomButton,
                  if (footer != null) ...[
                    const SizedBox(height: kSpacingMd),
                    footer!,
                  ],
                  const SizedBox(height: kSpacingSm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error banner used across the auth flow — small, red, sits above
/// the primary button.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: kSpacingSm),
      child: Text(message, style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w500)),
    );
  }
}
