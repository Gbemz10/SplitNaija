import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/expense_templates.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../services/settlement_service.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/brand_button.dart';
import '../widgets/user_avatar.dart';
import 'activity_detail_screen.dart';
import 'add_expense_screen.dart';
import 'invite_screen.dart';

/// A single group: balances (who owes who), the expense feed, and the
/// member list. Same flat white / branded-card language as the rest of
/// the app (Groups, Wallet, Activity) instead of default Material
/// Cards/ListTiles/Chips.
class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.group});
  final Group group;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  List<GroupMember>? _members;
  List<Expense>? _expenses;
  List<SuggestedSettlement>? _settlements;
  Object? _error;

  /// "$fromUserId>$toUserId" pairs settled this screen session. The backend
  /// has no GET /settlements list scoped to a group to durably query
  /// pending state, so this only reflects what happened since this screen
  /// was opened.
  final Set<String> _pendingPairs = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final groupService = context.read<GroupService>();
      final results = await Future.wait([
        groupService.getGroupMembers(widget.group.id),
        groupService.listExpenses(widget.group.id),
        groupService.getSuggestedSettlements(widget.group.id),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<GroupMember>;
        _expenses = results[1] as List<Expense>;
        _settlements = results[2] as List<SuggestedSettlement>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  String _memberName(String userId) {
    final match = _members?.where((m) => m.userId == userId);
    if (match == null || match.isEmpty) return 'Someone';
    return match.first.displayName;
  }

  /// Null for a phone-only invitee (no User row yet) or a member who's
  /// never set a photo — both cases fall back to initials, same as before
  /// this existed.
  String? _memberPhoto(String userId) {
    final match = _members?.where((m) => m.userId == userId);
    if (match == null || match.isEmpty) return null;
    return match.first.photoUrl;
  }

  /// Adapts this screen's own [Expense] (from `GET /expenses/group/:id`)
  /// into the [ActivityItem] shape [ActivityDetailScreen] expects, so that
  /// screen's detail view + delete action can be reused here instead of
  /// building a second copy of it.
  ActivityItem _toActivityItem(Expense e) => ActivityItem(
        type: 'EXPENSE',
        id: e.id,
        groupId: widget.group.id,
        groupName: widget.group.name,
        amountKobo: e.amountKobo,
        createdAt: e.createdAt,
        description: e.description,
        template: e.template,
        payerId: e.payerId,
        payerDisplayName: e.payerDisplayName ?? _memberName(e.payerId),
        splits: e.splits
            .map((s) => ActivitySplit(
                  userId: s.userId,
                  displayName: _memberName(s.userId),
                  shareKobo: s.shareKobo,
                  photoUrl: _memberPhoto(s.userId),
                ))
            .toList(),
      );

  Future<void> _openExpense(Expense e) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ActivityDetailScreen(item: _toActivityItem(e))),
    );
    if (deleted == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted.')),
        );
      }
    }
  }

  Future<void> _pay(SuggestedSettlement s) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SettlementConfirmSheet(
        name: _memberName(s.toUserId),
        photoUrl: _memberPhoto(s.toUserId),
        seed: s.toUserId,
        amountKobo: s.amountKobo,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<SettlementService>().createSettlement(
            groupId: widget.group.id,
            toUserId: s.toUserId,
            amountKobo: s.amountKobo,
          );
      if (!mounted) return;
      setState(() => _pendingPairs.add('${s.fromUserId}>${s.toUserId}'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement started, it may take a few minutes to confirm.')),
      );
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().currentUser?.id;
    // _settlements is the whole group's simplified settlement plan — every
    // debtor/creditor pair, not just this viewer's own. Rendering it
    // unfiltered meant anyone who wasn't a party to a given pair still saw
    // it, and since the row logic only ever checked "am I the debtor"
    // (isMine = fromUserId == me) and assumed creditor otherwise, someone
    // uninvolved (net balance zero) would see "X owes you" for a debt that
    // was actually owed to a different member entirely. Only show pairs
    // this viewer is actually on one side of.
    final myVisibleSettlements = (_settlements ?? [])
        .where((s) => s.fromUserId == currentUserId || s.toUserId == currentUserId)
        .toList();

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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Plain InkWell around a bare Icon, not IconButton or
                      // AppBar's default back arrow — same reasoning as
                      // elsewhere in this app: IconButton's minimum tap
                      // target throws off tight header alignment.
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
                      Expanded(
                        child: Text(
                          widget.group.name,
                          style: const TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: kSpacingSm),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => InviteScreen(group: widget.group)),
                          ),
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: Color(0xFFF1EFF7), shape: BoxShape.circle),
                            child: const Icon(Icons.person_add_alt_1_outlined, color: kBrandPurple, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpacingLg),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      color: kBrandPurple,
                      backgroundColor: Colors.white,
                      child: AsyncView<bool>(
                        loading: _members == null && _error == null,
                        error: _error,
                        data: _members != null ? true : null,
                        onRetry: _load,
                        builder: (context, _) => ListView(
                          padding: const EdgeInsets.only(bottom: 100),
                          children: [
                            Text('Balances', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: kSpacingSm),
                            if (myVisibleSettlements.isEmpty)
                              const _AllSettledCard()
                            else
                              ...myVisibleSettlements.map((s) {
                                final isMine = s.fromUserId == currentUserId;
                                final pending = _pendingPairs.contains('${s.fromUserId}>${s.toUserId}');
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: kSpacingSm),
                                  child: _BalanceCard(
                                    isMine: isMine,
                                    pending: pending,
                                    name: isMine ? _memberName(s.toUserId) : _memberName(s.fromUserId),
                                    amountText: formatKobo(s.amountKobo),
                                    onPay: isMine && !pending ? () => _pay(s) : null,
                                  ),
                                );
                              }),
                            const SizedBox(height: kSpacingLg),
                            Text('Expenses', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: kSpacingSm),
                            if (_expenses!.isEmpty)
                              const _EmptySectionCard(
                                icon: Icons.receipt_long_outlined,
                                message: 'No expenses yet, add one to get started.',
                              )
                            else
                              ..._expenses!.map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: kSpacingSm),
                                    child: _ExpenseCard(
                                      expense: e,
                                      payerName: e.payerDisplayName ?? _memberName(e.payerId),
                                      onTap: () => _openExpense(e),
                                    ),
                                  )),
                            const SizedBox(height: kSpacingLg),
                            Text('Members', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: kSpacingSm),
                            ..._members!.map((m) => Padding(
                                  padding: const EdgeInsets.only(bottom: kSpacingSm),
                                  child: _MemberCard(member: m),
                                )),
                          ],
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: kBrandPurple,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddExpenseScreen(groupId: widget.group.id)),
          );
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AllSettledCard extends StatelessWidget {
  const _AllSettledCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpacingMd),
      decoration: BoxDecoration(color: const Color(0xFFF7F6FA), borderRadius: BorderRadius.circular(kRadius)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: kSeedColor.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(Icons.check_circle_rounded, color: kSeedColor, size: 22),
          ),
          const SizedBox(width: kSpacingMd),
          const Expanded(
            child: Text("You're all settled up", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.isMine,
    required this.pending,
    required this.name,
    required this.amountText,
    required this.onPay,
  });

  final bool isMine;
  final bool pending;
  final String name;
  final String amountText;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final color = isMine ? const Color(0xFFD32F2F) : kSeedColor;
    return Material(
      color: const Color(0xFFF7F6FA),
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onPay,
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
                      isMine ? 'You owe $name' : '$name owes you',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (pending) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Payment started, pending confirmation',
                        style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12),
                      ),
                    ] else if (onPay != null) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to settle up',
                        style: TextStyle(color: kBrandPurple, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: kSpacingSm),
              Text(amountText, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense, required this.payerName, required this.onTap});
  final Expense expense;
  final String payerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = templateInfo(expense.template);
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
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: kBrandPurple.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(info.icon, color: kBrandPurple, size: 20),
              ),
              const SizedBox(width: kSpacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.description,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paid by $payerName · ${DateFormat.yMMMd().format(expense.createdAt)}',
                      style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: kSpacingSm),
              Text(formatKobo(expense.amountKobo), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: kSpacingXs),
              Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.35), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Replaces the old plain BrandDialog ("Confirm settlement" / "Pay ₦X to
/// Name?") — functional but bare, just an icon and a sentence. This puts
/// the person and the amount front and center instead, the way an actual
/// payment confirmation should read, and adds the one bit of real
/// substance (this goes out via Paystack, not instantly) that the old copy
/// never explained. A sheet, not a centered Dialog — that pattern is
/// reserved for destructive/irreversible actions elsewhere in the app
/// (delete group, delete account); starting a payment is the common,
/// constructive action, matching the same rising-sheet language as
/// [showBrandInputSheet].
class _SettlementConfirmSheet extends StatelessWidget {
  const _SettlementConfirmSheet({
    required this.name,
    required this.photoUrl,
    required this.seed,
    required this.amountKobo,
  });

  final String name;
  final String? photoUrl;
  final String seed;
  final int amountKobo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingMd, kSpacingLg, kSpacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Confirm payment',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black),
                    ),
                  ),
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
              const SizedBox(height: kSpacingLg),
              UserAvatar(name: name, seed: seed, photoUrl: photoUrl, radius: 36),
              const SizedBox(height: kSpacingMd),
              Text(
                'To $name',
                style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                formatKobo(amountKobo),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black),
              ),
              const SizedBox(height: kSpacingMd),
              Container(
                padding: const EdgeInsets.all(kSpacingMd),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F6FA),
                  borderRadius: BorderRadius.circular(kRadius),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Colors.black.withOpacity(0.45)),
                    const SizedBox(width: kSpacingSm),
                    Expanded(
                      child: Text(
                        'This starts a bank transfer via Paystack. It may take a few minutes to confirm.',
                        style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSpacingLg),
              BrandButton(
                label: 'Pay ${formatKobo(amountKobo)}',
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});
  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final tint = member.isRegistered ? kSeedColor : const Color(0xFFB8720A);
    return Container(
      padding: const EdgeInsets.all(kSpacingMd),
      decoration: BoxDecoration(color: const Color(0xFFF7F6FA), borderRadius: BorderRadius.circular(kRadius)),
      child: Row(
        children: [
          UserAvatar(name: member.displayName, seed: member.id, photoUrl: member.photoUrl, radius: 18),
          const SizedBox(width: kSpacingMd),
          Expanded(
            child: Text(
              member.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: kSpacingSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: kSpacingSm, vertical: 4),
            decoration: BoxDecoration(color: tint.withOpacity(0.12), borderRadius: BorderRadius.circular(kRadius)),
            child: Text(
              member.isRegistered ? 'Registered' : 'Pending',
              style: TextStyle(color: tint, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpacingMd),
      decoration: BoxDecoration(color: const Color(0xFFF7F6FA), borderRadius: BorderRadius.circular(kRadius)),
      child: Row(
        children: [
          Icon(icon, color: Colors.black.withOpacity(0.35)),
          const SizedBox(width: kSpacingMd),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.black.withOpacity(0.55))),
          ),
        ],
      ),
    );
  }
}
