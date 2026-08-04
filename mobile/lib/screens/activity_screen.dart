import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/expense_templates.dart';
import '../models/models.dart';
import '../services/activity_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/refreshable_state.dart';
import 'activity_detail_screen.dart';

/// Activity tab — a single merged feed of expenses added and settlements
/// sent/received across every group the user is in, newest first. Backed
/// by `GET /activity`, which does the cross-group aggregation server-side
/// (this screen used to fetch every group's expenses individually and
/// merge them client-side — one call now instead of N+1).
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends RefreshableState<ActivityScreen> {
  List<_ActivityEntry>? _entries;
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
      final items = await context.read<ActivityService>().listActivity();
      if (!mounted) return;
      final currentUserId = context.read<AuthService>().currentUser?.id;
      setState(() => _entries = items.map((item) => _toEntry(item, currentUserId)).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  static _ActivityEntry _toEntry(ActivityItem item, String? currentUserId) {
    if (item.isExpense) {
      final info = templateInfo(item.template ?? 'GENERIC');
      return _ActivityEntry(
        raw: item,
        date: item.createdAt,
        icon: info.icon,
        iconColor: kBrandPurple,
        title: item.description ?? 'Expense',
        subtitle: '${item.payerDisplayName ?? "Someone"} paid · ${item.groupName}',
        amountText: formatKobo(item.amountKobo),
      );
    }

    final isMine = item.fromUserId == currentUserId;
    return _ActivityEntry(
      raw: item,
      date: item.createdAt,
      icon: isMine ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
      iconColor: _settlementColor(item.status ?? 'PENDING'),
      title: isMine ? 'You paid ${item.toDisplayName}' : '${item.fromDisplayName} paid you',
      subtitle: '${item.groupName} · settlement',
      amountText: formatKobo(item.amountKobo),
    );
  }

  static Color _settlementColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return kSeedColor;
      case 'FAILED':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFFB8720A);
    }
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
                  const Text(
                    'Activity',
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: kSpacingXs),
                  Text(
                    'Expenses and settlements across your groups.',
                    style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: kSpacingLg),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      color: kBrandPurple,
                      backgroundColor: Colors.white,
                      child: AsyncView<List<_ActivityEntry>>(
                        loading: _entries == null && _error == null,
                        error: _error,
                        data: _entries,
                        onRetry: _load,
                        builder: (context, entries) => entries.isEmpty
                            ? const _EmptyActivity()
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 24),
                                itemCount: entries.length,
                                separatorBuilder: (_, __) => const SizedBox(height: kSpacingSm),
                                itemBuilder: (context, i) => _ActivityTile(entry: entries[i], onDeleted: _load),
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

class _ActivityEntry {
  _ActivityEntry({
    required this.raw,
    required this.date,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amountText,
  });

  // The original item this row summarizes — carried along so tapping the
  // row can open the full detail screen without a second fetch.
  final ActivityItem raw;
  final DateTime date;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amountText;
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry, required this.onDeleted});
  final _ActivityEntry entry;

  // Called when the detail screen reports the expense was deleted (it pops
  // back with `true`) — refreshes this list so the deleted row doesn't
  // linger until the next pull-to-refresh.
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F6FA),
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () async {
          final deleted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => ActivityDetailScreen(item: entry.raw)),
          );
          if (deleted == true) {
            onDeleted();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Expense deleted.')),
              );
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(kSpacingMd),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: entry.iconColor.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(entry.icon, color: entry.iconColor, size: 20),
              ),
              const SizedBox(width: kSpacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle,
                      style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: kSpacingSm),
              Text(entry.amountText, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

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
                    child: const Icon(Icons.timeline_rounded, color: kBrandPurple, size: 28),
                  ),
                  const SizedBox(height: kSpacingMd),
                  const Text('No activity yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: kSpacingXs),
                  Text(
                    'Expenses and settlements across your groups will show up here.',
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
