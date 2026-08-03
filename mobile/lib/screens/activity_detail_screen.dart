import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/expense_templates.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/bouncing_dots.dart';
import '../widgets/brand_button.dart';
import '../widgets/user_avatar.dart';

/// What tapping an Activity row opens — the full picture of one expense or
/// settlement rather than just the headline row the feed already showed.
/// Not a "transaction history" list (that's what Activity/Wallet already
/// are); this is a single record's own detail page: who paid, who it was
/// split between and for how much each, when, and in which group.
///
/// Stateful (not the plain StatelessWidget this used to be) because
/// deleting an expense needs a loading flag while the request is in
/// flight — a settlement has no delete action, so `_deleting` just stays
/// unused for that branch.
class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({super.key, required this.item});
  final ActivityItem item;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  bool _deleting = false;

  ActivityItem get item => widget.item;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BrandDialog(
        title: 'Delete expense?',
        content: const Text(
          'This removes it for everyone in the group and recalculates balances. This can\'t be undone.',
        ),
        primaryLabel: 'Delete',
        danger: true,
        icon: Icons.delete_outline_rounded,
        onPrimary: () => Navigator.pop(context, true),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await context.read<GroupService>().deleteExpense(item.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().currentUser?.id;
    final canDelete = item.isExpense && item.payerId == currentUserId;

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
                      Expanded(
                        child: Text(
                          item.isExpense ? 'Expense' : 'Settlement',
                          style: const TextStyle(
                            fontFamily: kFontFamily,
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // Only the person who added this expense sees this —
                      // everyone else in the group can view it, not delete
                      // it out from under the split.
                      if (canDelete)
                        _deleting
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: BouncingDots(color: Color(0xFFD32F2F), size: 5),
                              )
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _confirmDelete(context),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.delete_outline_rounded, color: Color(0xFFD32F2F), size: 22),
                                  ),
                                ),
                              ),
                    ],
                  ),
                  const SizedBox(height: kSpacingLg),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: kSpacingXl),
                      children: item.isExpense
                          ? _expenseContent(context, currentUserId)
                          : _settlementContent(context, currentUserId),
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

  List<Widget> _expenseContent(BuildContext context, String? currentUserId) {
    final info = templateInfo(item.template ?? 'GENERIC');
    final splits = item.splits ?? const <ActivitySplit>[];

    return [
      _HeroCard(
        icon: info.icon,
        iconColor: kBrandPurple,
        amountText: formatKobo(item.amountKobo),
        title: item.description ?? 'Expense',
        badge: info.label,
      ),
      const SizedBox(height: kSpacingLg),
      _InfoCard(rows: [
        _InfoRow(icon: Icons.person_outline_rounded, label: 'Paid by', value: item.payerDisplayName ?? 'Someone'),
        _InfoRow(icon: Icons.groups_outlined, label: 'Group', value: item.groupName),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Date',
          value: DateFormat.yMMMd().add_jm().format(item.createdAt),
        ),
      ]),
      if (splits.isNotEmpty) ...[
        const SizedBox(height: kSpacingLg),
        Text(
          splits.length == 1 ? 'Split 1 way' : 'Split ${splits.length} ways',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
        ),
        const SizedBox(height: kSpacingSm),
        ...splits.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: kSpacingSm),
              child: _SplitRow(split: s, isMe: s.userId == currentUserId),
            )),
      ],
    ];
  }

  List<Widget> _settlementContent(BuildContext context, String? currentUserId) {
    final isMine = item.fromUserId == currentUserId;
    final status = item.status ?? 'PENDING';
    final color = _statusColor(status);

    return [
      _HeroCard(
        icon: isMine ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        iconColor: color,
        amountText: formatKobo(item.amountKobo),
        title: isMine ? 'You paid ${item.toDisplayName ?? 'someone'}' : '${item.fromDisplayName ?? 'Someone'} paid you',
        badge: _statusLabel(status),
        badgeColor: color,
      ),
      const SizedBox(height: kSpacingLg),
      _InfoCard(rows: [
        _InfoRow(icon: Icons.arrow_upward_rounded, label: 'From', value: item.fromDisplayName ?? 'Someone'),
        _InfoRow(icon: Icons.arrow_downward_rounded, label: 'To', value: item.toDisplayName ?? 'Someone'),
        _InfoRow(icon: Icons.groups_outlined, label: 'Group', value: item.groupName),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Sent',
          value: DateFormat.yMMMd().add_jm().format(item.createdAt),
        ),
        _InfoRow(
          icon: Icons.check_circle_outline_rounded,
          label: 'Confirmed',
          value: item.confirmedAt != null
              ? DateFormat.yMMMd().add_jm().format(item.confirmedAt!)
              : 'Not yet',
        ),
      ]),
    ];
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return kSeedColor;
      case 'FAILED':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFFB8720A);
    }
  }

  static String _statusLabel(String status) =>
      status.isEmpty ? status : status.substring(0, 1) + status.substring(1).toLowerCase();
}

/// The big at-a-glance summary up top — icon, amount, headline, and a
/// small badge (template name, or settlement status).
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.iconColor,
    required this.amountText,
    required this.title,
    required this.badge,
    this.badgeColor,
  });

  final IconData icon;
  final Color iconColor;
  final String amountText;
  final String title;
  final String badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final chipColor = badgeColor ?? Colors.black.withOpacity(0.55);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: kSpacingLg, horizontal: kSpacingMd),
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
            decoration: BoxDecoration(color: iconColor.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: kSpacingMd),
          Text(
            amountText,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.black),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
          ),
          const SizedBox(height: kSpacingSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: kSpacingSm, vertical: 4),
            decoration: BoxDecoration(
              color: (badgeColor ?? Colors.black).withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: TextStyle(color: chipColor, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpacingMd, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6FA),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: kSpacingSm),
              child: Row(
                children: [
                  Icon(rows[i].icon, size: 18, color: Colors.black.withOpacity(0.45)),
                  const SizedBox(width: kSpacingSm),
                  Text(
                    rows[i].label,
                    style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 13),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1) const Divider(height: 1, color: Color(0xFFE9E7F0)),
          ],
        ],
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.split, required this.isMe});
  final ActivitySplit split;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpacingMd),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6FA),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(
        children: [
          UserAvatar(name: split.displayName, seed: split.userId, photoUrl: split.photoUrl, radius: 16),
          const SizedBox(width: kSpacingSm),
          Expanded(
            child: Text(
              isMe ? 'You' : split.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(formatKobo(split.shareKobo), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
