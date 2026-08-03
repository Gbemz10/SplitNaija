import 'package:flutter/material.dart';
import '../theme.dart';
import 'bouncing_dots.dart';

/// The purple filled CTA button used across the app wherever an action is
/// the primary/most-likely-to-be-tapped one on a screen (start a group,
/// save an expense, confirm a payout account...). Kept separate from the
/// auth-flow's `AuthPrimaryButton` (same look, different file) so screens
/// outside the auth flow don't have to import auth-specific widgets.
class BrandButton extends StatelessWidget {
  const BrandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: kBrandPurple,
        disabledBackgroundColor: kBrandPurple.withOpacity(0.5),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      ),
      child: loading
          ? const BouncingDots(color: Colors.white, size: 6)
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: kSpacingSm)],
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
    );
  }
}

/// A lighter-weight secondary action — outlined, brand-purple text/border.
/// Used next to a [BrandButton] or wherever an action shouldn't compete
/// visually with the primary one.
class BrandOutlinedButton extends StatelessWidget {
  const BrandOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: kBrandPurple,
        side: const BorderSide(color: kBrandPurple),
        padding: const EdgeInsets.symmetric(horizontal: kSpacingMd, vertical: kSpacingSm),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        // The app-wide OutlinedButtonTheme (theme.dart) sets minimumSize to
        // Size.fromHeight(52) — that's Size(double.infinity, 52), meant for
        // buttons that fill their own row/column. This button sits inline
        // in a Row next to other content, so it must override that with a
        // finite min width, or the Row's bounded width vs. the theme's
        // infinite min width crashes layout ("BoxConstraints forces an
        // infinite width").
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// A confirmation dialog, not a bottom sheet — research on destructive
/// actions is consistent that a sheet undersells the gravity of something
/// irreversible and gets swiped away without being read, while a centered
/// dialog demands a deliberate stop. What needed fixing was the *look*: a
/// tinted icon circle, centered title/message that actually restates the
/// consequence, and a full-width primary action instead of two cramped
/// AlertDialog buttons squeezed into a corner.
class BrandDialog extends StatelessWidget {
  const BrandDialog({
    super.key,
    required this.title,
    required this.content,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryEnabled = true,
    this.danger = false,
    this.icon,
  });

  final String title;
  final Widget content;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryEnabled;

  /// Red instead of brand-purple, for irreversible/destructive actions
  /// (deleting a group, etc.) where the color itself should signal that.
  final bool danger;

  /// Defaults to a delete icon when [danger] is set, a question mark
  /// otherwise — pass something more specific (e.g. a payment icon for a
  /// settle-up confirmation) when that reads better.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accentColor = danger ? const Color(0xFFD32F2F) : kBrandPurple;
    final resolvedIcon = icon ?? (danger ? Icons.delete_outline_rounded : Icons.help_outline_rounded);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: kSpacingLg, vertical: kSpacingXl),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingXl, kSpacingLg, kSpacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accentColor.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(resolvedIcon, color: accentColor, size: 28),
            ),
            const SizedBox(height: kSpacingMd),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
            ),
            const SizedBox(height: kSpacingSm),
            DefaultTextStyle(
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 14, height: 1.4),
              child: content,
            ),
            const SizedBox(height: kSpacingLg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: primaryEnabled ? onPrimary : null,
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  disabledBackgroundColor: accentColor.withOpacity(0.4),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
                ),
                child: Text(primaryLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
            const SizedBox(height: kSpacingXs),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black54,
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A text field styled to match the brand — rounded, white background with
/// a thin border (not a solid tinted fill, which read as "a grey box with
/// text pasted on top" rather than an actual input), purple focus border —
/// for use inside [BrandDialog] or any non-auth screen. (Auth screens have
/// their own `AuthTextField`, which additionally handles floating labels
/// tuned for that flow's taller layout.)
class BrandTextField extends StatefulWidget {
  const BrandTextField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.prefixText,
    this.maxLength,
    this.helperText,
    this.enablePasteSuggestion = true,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final String? prefixText;
  final int? maxLength;
  final String? helperText;

  /// iOS shows its own "Paste / Scan Text" bubble automatically the
  /// instant an empty field gets focus, if there's compatible content on
  /// the clipboard — separate from the long-press selection menu. Useful
  /// for a field like an invite code (people paste those in from a
  /// message), but distracting on a field like a group name that nobody's
  /// pasting into. Set false to suppress it for this field.
  final bool enablePasteSuggestion;

  /// Masks input with dots and adds a show/hide eye toggle — for
  /// passwords (current/new password fields, delete-account confirmation).
  /// The field starts masked; tapping the eye reveals it, same convention
  /// as the auth flow's own password fields.
  final bool obscureText;

  @override
  State<BrandTextField> createState() => _BrandTextFieldState();
}

class _BrandTextFieldState extends State<BrandTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      maxLength: widget.maxLength,
      obscureText: _obscured,
      contextMenuBuilder: widget.enablePasteSuggestion
          ? null // null falls back to the platform default menu
          : (context, state) => const SizedBox.shrink(),
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
      // Without these, TextField/InputDecoration fall back to
      // colorScheme.primary for the label and cursor — and since the app's
      // ColorScheme is seeded from kSeedColor (green, for balance/status
      // elsewhere), the label and cursor rendered green here even though
      // nothing about this field is a "positive" status. Grey label always,
      // purple cursor, matching the rest of the brand.
      cursorColor: kBrandPurple,
      decoration: InputDecoration(
        labelText: widget.label,
        // Explicit, not relying on TextField's own default — the label
        // sits inside the box like a placeholder until this field is
        // focused or has text, then floats up to the border. Not floated
        // all the time.
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: TextStyle(color: Colors.black.withOpacity(0.45), fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(color: Colors.black.withOpacity(0.5), fontWeight: FontWeight.w600),
        helperText: widget.helperText,
        helperStyle: TextStyle(color: Colors.black.withOpacity(0.45), fontSize: 12),
        prefixText: widget.prefixText,
        counterText: widget.maxLength != null ? '' : null,
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.black.withOpacity(0.4),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: Color(0xFFE4E0EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: Color(0xFFE4E0EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: kBrandPurple, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: kSpacingMd, vertical: kSpacingMd),
      ),
    );
  }
}
