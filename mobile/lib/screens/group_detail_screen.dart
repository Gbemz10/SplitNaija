import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import 'add_expense_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.group, required this.authService});
  final Group group;
  final AuthService authService;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  List<SuggestedSettlement> _settlements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groupService = context.read<GroupService>();
    final settlements = await groupService.getSuggestedSettlements(widget.group.id);
    setState(() {
      _settlements = settlements;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddExpenseScreen(groupId: widget.group.id)),
          );
          _load();
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Suggested settlements', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_settlements.isEmpty)
                    const Text('All settled up.', style: TextStyle(color: Colors.grey))
                  else
                    ..._settlements.map(
                      (s) => Card(
                        child: ListTile(
                          title: Text('${s.fromUserId} → ${s.toUserId}'),
                          trailing: Text(
                            formatKobo(s.amountKobo),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () {
                            // TODO: trigger POST /settlements to kick off the
                            // Paystack transfer for this suggested transaction
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
