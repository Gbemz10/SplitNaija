import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/group_service.dart';

// Nigeria-specific templates (PRD §7.2). Selecting one would eventually
// pre-fill category/note defaults — kept as a plain dropdown for the scaffold.
const _templates = {
  'GENERIC': 'Generic',
  'OWAMBE_CONTRIBUTION': 'Owambe / aso-ebi contribution',
  'AJO_ESUSU_ROUND': 'Ajo / esusu round',
  'SHARED_SUBSCRIPTION': 'Shared subscription',
  'RENT': 'Rent',
};

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, required this.groupId});
  final String groupId;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _template = 'GENERIC';
  bool _saving = false;

  Future<void> _save() async {
    final amountNaira = double.tryParse(_amountController.text.trim());
    if (amountNaira == null || _descriptionController.text.trim().isEmpty) return;

    setState(() => _saving = true);
    try {
      // TODO: replace with a real group-member picker for participantIds —
      // hardcoded empty here as a scaffold placeholder (see backend
      // splitCalculator.ts, which requires at least one participant)
      await context.read<GroupService>().addExpense(
            groupId: widget.groupId,
            description: _descriptionController.text.trim(),
            amountKobo: (amountNaira * 100).round(),
            participantIds: [],
            template: _template,
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'What was this for?', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₦)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _template,
              decoration: const InputDecoration(labelText: 'Template', border: OutlineInputBorder()),
              items: _templates.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _template = v ?? 'GENERIC'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}
