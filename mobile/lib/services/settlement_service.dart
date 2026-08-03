import '../models/models.dart';
import 'api_client.dart';

class SettlementService {
  SettlementService(this._api);
  final ApiClient _api;

  /// Registers the caller's payout bank account with Paystack. Required
  /// before this user can *receive* any settlement.
  Future<PayoutAccount> setUpRecipient({
    required String bankCode,
    required String accountNumber,
  }) async {
    final data = await _api.post('/settlements/recipients', {
      'bankCode': bankCode,
      'accountNumber': accountNumber,
    });
    return PayoutAccount.fromJson(data);
  }

  Future<Settlement> createSettlement({
    required String groupId,
    required String toUserId,
    required int amountKobo,
  }) async {
    final data = await _api.post('/settlements', {
      'groupId': groupId,
      'toUserId': toUserId,
      'amountKobo': amountKobo,
    });
    return Settlement.fromJson(data);
  }

  /// Every settlement the caller has sent or received, newest first —
  /// powers the Wallet tab's history list.
  Future<List<SettlementRecord>> listSettlements() async {
    final data = await _api.getList('/settlements');
    return data.map((s) => SettlementRecord.fromJson(s as Map<String, dynamic>)).toList();
  }
}