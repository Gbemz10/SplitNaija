import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/settlement_service.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/refreshable_state.dart';
import 'recipient_setup_screen.dart';

/// Wallet tab — payout account status up top, settlement history (sent and
/// received, across every group) below. Same flat white / black-text
/// language as the Groups tab, no separate banner.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends RefreshableState<WalletScreen> {
  List<SettlementRecord>? _settlements;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> refresh() => _load();

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final settlements = await context.read<SettlementService>().listSettlements();
      if (!mounted) return;
      setState(() => _settlements = settlements);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

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
                  const Text(
                    'Wallet',
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: kSpacingXs),
                  Text(
                    'Your payout account and settlement history.',
                    style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: kSpacingLg),
                  if (user != null) _PayoutCard(user: user),
                  const SizedBox(height: kSpacingLg),
                  Text('History', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: kSpacingMd),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: AsyncView<List<SettlementRecord>>(
                        loading: _settlements == null && _error == null,
                        error: _error,
                        data: _settlements,
                        onRetry: _load,
                        builder: (context, settlements) => settlements.isEmpty
                            ? const _EmptyWallet()
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 24),
                                itemCount: settlements.length,
                                separatorBuilder: (_, __) => const SizedBox(height: kSpacingSm),
                                itemBuilder: (context, i) => _SettlementTile(
                                  settlement: settlements[i],
                                  currentUserId: user?.id,
                                ),
                              ),
                      ),
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

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final ok = user.hasPayoutAccount;
    final tint = ok ? kSeedColor : const Color(0xFFB8720A);
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
                  ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: tint,
                ),
              ),
              const SizedBox(width: kSpacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ok ? 'Payout account set up' : 'No payout account yet',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ok
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

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({required this.settlement, required this.currentUserId});
  final SettlementRecord settlement;
  final String? currentUserId;

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return kSeedColor;
      case 'FAILED':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFFB8720A);
    }
  }

  // `status[0]` doesn't compile — Dart's String has no `[]` operator,
  // unlike JS/Python. `.substring()` is the way to grab a single character.
  String _statusLabel(String status) =>
      status.isEmpty ? status : status.substring(0, 1) + status.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final isMine = settlement.fromUserId == currentUserId;
    final color = _statusColor(settlement.status);

    return Material(
      color: const Color(0xFFF7F6FA),
      borderRadius: BorderRadius.circular(kRadius),
      child: Padding(
        padding: const EdgeInsets.all(kSpacingMd),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(
                isMine ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: kSpacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMine ? 'You paid ${settlement.toName}' : '${settlement.fromName} paid you',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${settlement.groupName} · ${DateFormat.yMMMd().format(settlement.createdAt)}',
                    style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: kSpacingSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatKobo(settlement.amountKobo), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  _statusLabel(settlement.status),
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWallet extends StatelessWidget {
  const _EmptyWallet();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(kSpacingLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: kBrandPurple.withOpacity(0.08), shape: BoxShape.circle),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: kBrandPurple, size: 28),
                  ),
                  const SizedBox(height: kSpacingMd),
                  const Text('No settlements yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: kSpacingXs),
                  Text(
                    'Payments you send or receive will show up here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black.withOpacity(0.55)),
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
