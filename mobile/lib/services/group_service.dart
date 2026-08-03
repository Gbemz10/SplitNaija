import '../models/models.dart';
import 'api_client.dart';

class GroupService {
  GroupService(this._api);
  final ApiClient _api;

  Future<Group> createGroup(String name) async {
    final data = await _api.post('/groups', {'name': name});
    return Group.fromJson(data);
  }

  Future<GroupMember> joinGroup(String inviteCode) async {
    final data = await _api.post('/groups/join', {'inviteCode': inviteCode});
    return GroupMember.fromJson(data);
  }

  Future<List<Group>> listMyGroups() async {
    final data = await _api.getList('/groups');
    return data.map((g) => Group.fromJson(g as Map<String, dynamic>)).toList();
  }

  /// Only the member who created the group (the earliest join) is allowed
  /// to do this — the backend 403s otherwise.
  Future<void> deleteGroup(String groupId) => _api.delete('/groups/$groupId');

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final data = await _api.getList('/groups/$groupId/members');
    return data.map((m) => GroupMember.fromJson(m as Map<String, dynamic>)).toList();
  }

  /// Adds a participant by phone number who hasn't installed the app yet.
  Future<GroupMember> inviteMember(String groupId, String phoneNumber, String displayName) async {
    final data = await _api.post('/groups/$groupId/members/invite', {
      'phoneNumber': phoneNumber,
      'displayName': displayName,
    });
    return GroupMember.fromJson(data);
  }

  Future<List<Expense>> listExpenses(String groupId) async {
    final data = await _api.getList('/expenses/group/$groupId');
    return data.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Pass exactly one of: [participantIds] for an even split, [customShares]
  /// (userId -> exact amountKobo, must sum to [amountKobo]) for an uneven
  /// naira split, or [percentageShares] (userId -> percentage, must sum to
  /// 100) for a percentage split. The backend's CUSTOM and PERCENTAGE split
  /// types already existed and enforce those sums themselves — this just
  /// gives mobile a way to reach all three.
  Future<Expense> addExpense({
    required String groupId,
    required String description,
    required int amountKobo,
    List<String>? participantIds,
    Map<String, int>? customShares,
    Map<String, double>? percentageShares,
    String template = 'GENERIC',
  }) async {
    assert(
      [participantIds, customShares, percentageShares].where((v) => v != null).length == 1,
      'Pass exactly one of participantIds (even split), customShares (uneven naira split), '
      'or percentageShares (percentage split).',
    );
    final Map<String, dynamic> split;
    if (customShares != null) {
      split = {
        'type': 'CUSTOM',
        'shares': customShares.entries.map((e) => {'userId': e.key, 'amountKobo': e.value}).toList(),
      };
    } else if (percentageShares != null) {
      split = {
        'type': 'PERCENTAGE',
        'shares': percentageShares.entries.map((e) => {'userId': e.key, 'percentage': e.value}).toList(),
      };
    } else {
      split = {'type': 'EQUAL', 'participantIds': participantIds};
    }

    final data = await _api.post('/expenses', {
      'groupId': groupId,
      'description': description,
      'amountKobo': amountKobo,
      'template': template,
      'split': split,
    });
    return Expense.fromJson(data);
  }

  /// Only the person who added the expense (its payer) can do this — the
  /// backend 403s otherwise.
  Future<void> deleteExpense(String expenseId) => _api.delete('/expenses/$expenseId');

  Future<List<SuggestedSettlement>> getSuggestedSettlements(String groupId) async {
    final data = await _api.get('/balances/group/$groupId');
    return (data['suggestedSettlements'] as List)
        .map((s) => SuggestedSettlement.fromJson(s as Map<String, dynamic>))
        .toList();
  }
}