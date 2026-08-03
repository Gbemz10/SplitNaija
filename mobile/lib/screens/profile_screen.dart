import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/user_avatar.dart';
import 'change_password_screen.dart';
import 'delete_account_screen.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'recipient_setup_screen.dart';

/// Account tab, reached both as the 4th bottom-nav tab and by tapping the
/// profile icon on the Groups header. Same flat white, black-header,
/// F7F6FA-card language as Groups/Wallet/Activity, no default AppBar and
/// no plain Card+ListTile rows.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthService>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    // Reached two ways: as the Account tab (nothing to pop back to) and by
    // tapping the profile icon on the Groups header (a real pushed route,
    // needs its own back arrow since there's no AppBar to supply one).
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.white,
      body: user == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingMd, kSpacingLg, 0),
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: kSpacingXl),
                      children: [
                        Row(
                          children: [
                            if (canPop) ...[
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
                            ],
                            const Text(
                              'Account',
                              style: TextStyle(
                                fontFamily: kFontFamily,
                                color: Colors.black,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacingXs),
                        Text(
                          'Your profile and payout details.',
                          style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: kSpacingLg),
                        _IdentityCard(
                          name: user.displayName,
                          phone: user.phoneNumber,
                          userId: user.id,
                          photoUrl: user.photoUrl,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                          ),
                        ),
                        const SizedBox(height: kSpacingLg),
                        Text('Payments', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: kSpacingMd),
                        _PayoutRow(hasPayoutAccount: user.hasPayoutAccount),
                        const SizedBox(height: kSpacingLg),
                        Text('Security', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: kSpacingMd),
                        _SecurityRow(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change password',
                          subtitle: 'Update the password you sign in with.',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                          ),
                        ),
                        const SizedBox(height: kSpacingSm),
                        _SecurityRow(
                          icon: Icons.delete_forever_rounded,
                          label: 'Delete account',
                          subtitle: 'Permanently remove your account.',
                          danger: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
                          ),
                        ),
                        const SizedBox(height: kSpacingLg),
                        Text('Session', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: kSpacingMd),
                        _LogoutRow(onTap: () => _logout(context)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Who's-signed-in card up top — tappable through to Edit Profile, where
/// name and photo can actually be changed. Falls back to initials (per an
/// earlier call, still the right call for contexts with several people at
/// once like member lists) until a real photo is set.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.phone,
    required this.userId,
    required this.onTap,
    this.photoUrl,
  });
  final String name;
  final String phone;
  final String userId;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F6FA),
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(kSpacingMd),
          child: Row(
            children: [
              UserAvatar(name: name, seed: userId, photoUrl: photoUrl, radius: 28),
              const SizedBox(width: kSpacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(phone, style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.hasPayoutAccount});
  final bool hasPayoutAccount;

  @override
  Widget build(BuildContext context) {
    final tint = hasPayoutAccount ? kSeedColor : const Color(0xFFB8720A);
    return Material(
      color: const Color(0xFFF7F6FA),
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecipientSetupScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(kSpacingMd),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tint.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(
                  hasPayoutAccount ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: tint,
                ),
              ),
              const SizedBox(width: kSpacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPayoutAccount ? 'Payout account set up' : 'No payout account yet',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasPayoutAccount
                          ? 'Group members can settle up with you.'
                          : 'Set this up so group members can pay you back.',
                      style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row in the Security section — same card language as [_PayoutRow], but
/// the destructive one (delete account) tints red instead of the neutral
/// F7F6FA background, so it reads as sensitive before it's even tapped.
class _SecurityRow extends StatelessWidget {
  const _SecurityRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    const dangerColor = Color(0xFFD32F2F);
    final tint = danger ? dangerColor : kBrandPurple;
    return Material(
      color: danger ? dangerColor.withOpacity(0.05) : const Color(0xFFF7F6FA),
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(kSpacingMd),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tint.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, color: tint),
              ),
              const SizedBox(width: kSpacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontWeight: FontWeight.w700, color: danger ? dangerColor : Colors.black),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Styled like a real destructive action, tinted red, rather than a plain
/// outlined button, since logging out ends the current session even
/// though it's easily reversible.
class _LogoutRow extends StatelessWidget {
  const _LogoutRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFD32F2F);
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(kSpacingMd),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: color, size: 20),
              SizedBox(width: kSpacingMd),
              Text('Log out', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
