class Group {
  Group({required this.id, required this.name, this.memberCount});

  final String id;
  final String name;
  final int? memberCount;

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        memberCount: (json['members'] as List?)?.length,
      );
}

class ExpenseSplit {
  ExpenseSplit({required this.userId, required this.shareKobo});
  final String userId;
  final int shareKobo;

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) => ExpenseSplit(
        userId: json['userId'] as String,
        shareKobo: json['shareKobo'] as int,
      );
}

class Expense {
  Expense({
    required this.id,
    required this.description,
    required this.amountKobo,
    required this.payerId,
    required this.splits,
  });

  final String id;
  final String description;
  final int amountKobo;
  final String payerId;
  final List<ExpenseSplit> splits;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        description: json['description'] as String,
        amountKobo: json['amountKobo'] as int,
        payerId: json['payerId'] as String,
        splits: (json['splits'] as List? ?? [])
            .map((s) => ExpenseSplit.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

/// A suggested settle-up transaction from the debt-simplification endpoint.
class SuggestedSettlement {
  SuggestedSettlement({
    required this.fromUserId,
    required this.toUserId,
    required this.amountKobo,
  });

  final String fromUserId;
  final String toUserId;
  final int amountKobo;

  factory SuggestedSettlement.fromJson(Map<String, dynamic> json) => SuggestedSettlement(
        fromUserId: json['fromUserId'] as String,
        toUserId: json['toUserId'] as String,
        amountKobo: json['amountKobo'] as int,
      );
}

/// Formats an integer kobo amount as a naira string, e.g. 150000 -> "₦1,500.00"
String formatKobo(int kobo) {
  final naira = kobo / 100;
  return '₦${naira.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d)(\.\d+)?$)'),
        (m) => '${m[1]},',
      )}';
}
