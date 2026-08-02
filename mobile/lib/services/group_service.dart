import '../models/models.dart';
import 'api_client.dart';

class GroupService {
  GroupService(this._api);
  final ApiClient _api;

  Future<Group> createGroup(String name) async {
    final data = await _api.post('/groups', {'name': name});
    return Group.fromJson(data);
  }

  Future<Group> joinGroup(String inviteCode) async {
    final data = await _api.post('/groups/join', {'inviteCode': inviteCode});
    return Group.fromJson(data);
  }

  // TODO: backend needs a GET /groups (list-my-groups) endpoint — see
  // README "suggested next steps". Wire this up once that's added.
  Future<List<Group>> listMyGroups() async => [];

  Future<List<Expense>> listExpenses(String groupId) async {
    final data = await _api.getList('/expenses/group/$groupId');
    return data.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> addExpense({
    required String groupId,
    required String description,
    required int amountKobo,
    required List<String> participantIds,
    String template = 'GENERIC',
  }) {
    return _api.post('/expenses', {
      'groupId': groupId,
      'description': description,
      'amountKobo': amountKobo,
      'template': template,
      'split': {'type': 'EQUAL', 'participantIds': participantIds},
    });
  }

  Future<List<SuggestedSettlement>> getSuggestedSettlements(String groupId) async {
    final data = await _api.get('/balances/group/$groupId');
    return (data['suggestedSettlements'] as List)
        .map((s) => SuggestedSettlement.fromJson(s as Map<String, dynamic>))
        .toList();
  }
}
