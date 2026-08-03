import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../utils/phone.dart';
import '../widgets/async_view.dart';
import '../widgets/brand_button.dart';

/// Invite screen — flat white, custom header, branded card/fields/buttons
/// instead of the stock AppBar/Card/TextField/FilledButton look (which was
/// pulling its greens straight from the app-wide seeded ColorScheme).
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.group});
  final Group group;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.group.inviteCode));
    if (!mounted) return;
    _showToast('Invite code copied');
  }

  Future<void> _addByPhone() async {
    if (_phoneController.text.trim().isEmpty || _nameController.text.trim().isEmpty) return;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    setState(() => _sending = true);
    try {
      await context.read<GroupService>().inviteMember(widget.group.id, phone, name);
      if (!mounted) return;
      _phoneController.clear();
      _nameController.clear();
      await _sendWhatsAppInvite(name: name, phone: phone);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        ),
      );
  }

  /// Hands off to WhatsApp with the invite already typed out — a
  /// click-to-chat `wa.me` link, not the full WhatsApp Business API (that
  /// needs a Meta-approved business account and message templates neither
  /// of which exist yet). This works with zero extra setup: it opens a
  /// chat with this exact number and pre-fills the message, the person
  /// just taps send. The link inside points at the backend's own
  /// server-rendered preview page (see GET /groups/preview/:inviteCode)
  /// rather than a raw API endpoint, so it actually renders something
  /// readable in their browser before they've installed the app.
  Future<void> _sendWhatsAppInvite({required String name, required String phone}) async {
    final baseUrl = context.read<ApiClient>().baseUrl;
    final previewLink = '$baseUrl/groups/preview/${widget.group.inviteCode}';
    final message = 'Hi $name! I added you to "${widget.group.name}" on SplitNaija so we can split expenses '
        'together. Take a look: $previewLink';
    final e164Digits = toE164Nigeria(phone).replaceFirst('+', '');
    final uri = Uri.parse('https://wa.me/$e164Digits?text=${Uri.encodeComponent(message)}');

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    _showToast(
      launched
          ? 'Added — opening WhatsApp to send the invite.'
          : "Added, but couldn't open WhatsApp. They'll appear as pending until they sign up.",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                        'Invite to group',
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
                        Text('Share this code', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: kSpacingSm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(kSpacingLg),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F6FA),
                            borderRadius: BorderRadius.circular(kRadius),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: kBrandPurple.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.qr_code_2_rounded, color: kBrandPurple, size: 26),
                              ),
                              const SizedBox(height: kSpacingMd),
                              Text(
                                widget.group.inviteCode,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: kSpacingSm),
                              Text(
                                'Anyone with this code can join "${widget.group.name}" from the app.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 13),
                              ),
                              const SizedBox(height: kSpacingMd),
                              SizedBox(
                                width: double.infinity,
                                child: BrandOutlinedButton(
                                  label: 'Copy code',
                                  icon: Icons.copy_outlined,
                                  onPressed: _copyCode,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: kSpacingXl),
                        Text("Don't have the app yet?", style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: kSpacingXs),
                        Text(
                          'Add them by phone number — we\'ll open WhatsApp with an invite ready to send. '
                          'They\'ll show as "Pending" in the group until they sign up.',
                          style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: kSpacingMd),
                        BrandTextField(
                          controller: _nameController,
                          label: 'Their name',
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: kSpacingMd),
                        BrandTextField(
                          controller: _phoneController,
                          label: 'Phone number',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: kSpacingMd),
                        BrandButton(
                          label: 'Add & invite via WhatsApp',
                          icon: Icons.chat_bubble_outline_rounded,
                          loading: _sending,
                          onPressed: _addByPhone,
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
    );
  }
}
