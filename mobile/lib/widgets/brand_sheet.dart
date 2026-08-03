import 'package:flutter/material.dart';
import '../theme.dart';
import 'brand_button.dart';

/// A bottom sheet for collecting a single line of input — "New group",
/// "Join a group", etc. Replaces the old centered `AlertDialog` popup with
/// something closer to how PayPal/Cash App-style flows ask for a quick bit
/// of text: a card that rises from the bottom, a headline instead of a
/// title bar, a close (X) in the corner, one field, one full-width button.
///
/// Returns the entered text on submit, or null if dismissed without one.
Future<String?> showBrandInputSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required String label,
  required String primaryLabel,
  TextCapitalization textCapitalization = TextCapitalization.none,
  TextInputType? keyboardType,
  String? prefixText,
  int minLength = 1,
  String? helperText,
  bool enablePasteSuggestion = true,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true, // lets the sheet ride up above the keyboard
    backgroundColor: Colors.transparent,
    builder: (context) => _BrandInputSheet(
      title: title,
      subtitle: subtitle,
      label: label,
      primaryLabel: primaryLabel,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      prefixText: prefixText,
      minLength: minLength,
      helperText: helperText,
      enablePasteSuggestion: enablePasteSuggestion,
    ),
  );
}

class _BrandInputSheet extends StatefulWidget {
  const _BrandInputSheet({
    required this.title,
    this.subtitle,
    required this.label,
    required this.primaryLabel,
    required this.textCapitalization,
    this.keyboardType,
    this.prefixText,
    this.minLength = 1,
    this.helperText,
    this.enablePasteSuggestion = true,
  });

  final String title;
  final String? subtitle;
  final String label;
  final String primaryLabel;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final String? prefixText;
  final int minLength;
  final String? helperText;
  final bool enablePasteSuggestion;

  @override
  State<_BrandInputSheet> createState() => _BrandInputSheetState();
}

class _BrandInputSheetState extends State<_BrandInputSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _valid = false;
  bool _focusScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final isValid = _controller.text.trim().length >= widget.minLength;
      if (isValid != _valid) setState(() => _valid = isValid);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusScheduled) return;
    _focusScheduled = true;

    // `autofocus` doesn't reliably raise the keyboard here — this widget
    // builds while the modal bottom sheet is still sliding up, and a focus
    // request made mid-transition can get dropped. The previous fix for
    // that used a flat 250ms delay, which just traded "no keyboard" for
    // "keyboard (and iOS's automatic Paste-suggestion bubble for an empty
    // field) pops in abruptly on an already-settled sheet" — a guessed
    // delay that didn't line up with the sheet's actual transition length.
    // Listening for the route's own animation to finish ties the focus
    // request to when the sheet has *actually* finished moving, so the
    // keyboard rises as a continuation of that motion instead of a
    // separate, late pop-in.
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _focusNode.requestFocus();
      return;
    }
    void onStatusChange(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(onStatusChange);
        if (mounted) _focusNode.requestFocus();
      }
    }

    animation.addStatusListener(onStatusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_valid) return;
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    // The white/rounded decoration goes on the OUTER Container, and the
    // keyboard-avoiding bottom padding goes INSIDE it — not the other way
    // around. Container paints across its entire box, and its size grows
    // to include that inner padding, so putting the padding inside means
    // the white now extends all the way down behind where the keyboard
    // sits. Previously the padding was outside, which pushed the white box
    // up and left that strip completely transparent — so the system
    // keyboard's own rounded top corners revealed the modal's grey scrim
    // through the gaps instead of blending into the sheet.
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingMd, kSpacingLg, kSpacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and close button share a row so they're always
                // vertically aligned with each other, regardless of how
                // long the title text is — rather than floating the close
                // button at a fixed offset that only lines up by luck.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                    ),
                    // Plain InkWell around a bare Icon, not IconButton —
                    // IconButton's built-in minimum tap target doesn't fully
                    // go away just from zeroing padding/constraints (bit us
                    // once before on the auth back button), which would
                    // throw off the alignment this row exists to fix.
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, color: Colors.black54, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: kSpacingXs),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(color: Colors.black.withOpacity(0.55)),
                  ),
                ],
                const SizedBox(height: kSpacingLg),
                BrandTextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  label: widget.label,
                  textCapitalization: widget.textCapitalization,
                  keyboardType: widget.keyboardType,
                  prefixText: widget.prefixText,
                  enablePasteSuggestion: widget.enablePasteSuggestion,
                ),
                if (widget.helperText != null) ...[
                  const SizedBox(height: 6),
                  // Flush left, no extra indent — matching the title and
                  // subtitle above it (and the field's own outer border),
                  // not the label text floating inside the field, which
                  // sits further in because of the field's own internal
                  // padding.
                  Text(
                    widget.helperText!,
                    style: TextStyle(color: Colors.black.withOpacity(0.45), fontSize: 12),
                  ),
                ],
                const SizedBox(height: kSpacingLg),
                BrandButton(
                  label: widget.primaryLabel,
                  onPressed: _valid ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
