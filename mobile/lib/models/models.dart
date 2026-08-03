class Group {
  Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.memberCount,
    this.netBalanceKobo,
  });

  final String id;
  final String name;
  final String inviteCode;
  final int? memberCount;

  // Only present on `GET /groups` (the list) — positive means the group
  // owes the caller, negative means the caller owes the group, zero means
  // settled up. Null on responses that don't compute it (e.g. the row
  // returned by POST /groups right after creating one).
  final int? netBalanceKobo;

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        inviteCode: json['inviteCode'] as String,
        // `GET /groups` sends an explicit memberCount now; older/other
        // responses (e.g. the group-preview endpoint) still send a raw
        // `members` array — support both.
        memberCount: json['memberCount'] as int? ?? (json['members'] as List?)?.length,
        netBalanceKobo: json['netBalanceKobo'] as int?,
      );
}

/// The signed-in user. Returned by `POST /auth/otp/verify`.
class User {
  User({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    this.paystackRecipientCode,
    this.photoUrl,
    this.bankCode,
    this.accountNumber,
    this.accountName,
  });

  final String id;
  final String phoneNumber;
  final String displayName;
  final String? paystackRecipientCode;

  // A base64 data URI (e.g. "data:image/jpeg;base64,...."), not a CDN
  // link — there's no object storage service, so the backend stores this
  // inline on the User row. Null until the person sets one via Edit Profile.
  final String? photoUrl;

  // Set together with paystackRecipientCode by POST /settlements/recipients
  // — the backend already returns these on every user object (toPublicUser
  // just strips passwordHash), so the payout screen can show "here's what
  // you already have on file" instead of a blank form every time it opens.
  final String? bankCode;
  final String? accountNumber;
  final String? accountName;

  bool get hasPayoutAccount => paystackRecipientCode != null;

  User copyWith({
    String? paystackRecipientCode,
    String? displayName,
    Object? photoUrl = _unset,
    String? bankCode,
    String? accountNumber,
    String? accountName,
  }) =>
      User(
        id: id,
        phoneNumber: phoneNumber,
        displayName: displayName ?? this.displayName,
        paystackRecipientCode: paystackRecipientCode ?? this.paystackRecipientCode,
        photoUrl: identical(photoUrl, _unset) ? this.photoUrl : photoUrl as String?,
        bankCode: bankCode ?? this.bankCode,
        accountNumber: accountNumber ?? this.accountNumber,
        accountName: accountName ?? this.accountName,
      );

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        phoneNumber: json['phoneNumber'] as String,
        displayName: json['displayName'] as String,
        paystackRecipientCode: json['paystackRecipientCode'] as String?,
        photoUrl: json['photoUrl'] as String?,
        bankCode: json['bankCode'] as String?,
        accountNumber: json['accountNumber'] as String?,
        accountName: json['accountName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'paystackRecipientCode': paystackRecipientCode,
        'photoUrl': photoUrl,
        'bankCode': bankCode,
        'accountNumber': accountNumber,
        'accountName': accountName,
      };
}

/// Sentinel so `copyWith(photoUrl: null)` can mean "explicitly clear the
/// photo" instead of being indistinguishable from "don't touch it" — a
/// plain `String?` default of null can't tell those two cases apart.
const _unset = Object();

/// A row from `GET /groups/:groupId/members` — includes non-app-users added
/// by phone only (`userId` is null, `isRegistered` is false) until they sign up.
class GroupMember {
  GroupMember({
    required this.id,
    required this.groupId,
    this.userId,
    required this.phoneNumber,
    required this.displayName,
    required this.joinedAt,
    required this.isRegistered,
    this.groupName,
    this.alreadyMember = false,
    this.photoUrl,
  });

  final String id;
  final String groupId;
  final String? userId;
  final String phoneNumber;
  final String displayName;
  final DateTime joinedAt;
  final bool isRegistered;

  // Only present on the `POST /groups/join` response, not on
  // `GET /groups/:groupId/members` — null/false everywhere else.
  final String? groupName;
  final bool alreadyMember;

  // Pulled from the linked User row (only present for registered members —
  // phone-only invitees have no User yet, so this stays null for them,
  // same as it would for a registered member who's never set one).
  final String? photoUrl;

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
        userId: json['userId'] as String?,
        phoneNumber: json['phoneNumber'] as String,
        displayName: json['displayName'] as String,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        isRegistered: json['isRegistered'] as bool,
        groupName: json['groupName'] as String?,
        alreadyMember: json['alreadyMember'] as bool? ?? false,
        photoUrl: json['photoUrl'] as String?,
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
    required this.template,
    required this.createdAt,
    required this.splits,
    this.payerDisplayName,
    this.category,
    this.note,
  });

  final String id;
  final String description;
  final int amountKobo;
  final String payerId;
  final String? payerDisplayName;
  final String template;
  final String? category;
  final String? note;
  final DateTime createdAt;
  final List<ExpenseSplit> splits;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        description: json['description'] as String,
        amountKobo: json['amountKobo'] as int,
        payerId: json['payerId'] as String,
        // Only present on GET /expenses/group/:groupId, which includes `payer`.
        payerDisplayName: (json['payer'] as Map<String, dynamic>?)?['displayName'] as String?,
        template: json['template'] as String? ?? 'GENERIC',
        category: json['category'] as String?,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
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

/// Response shape of `POST /settlements` — a real payout in flight.
class Settlement {
  Settlement({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amountKobo,
    required this.status,
  });

  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final int amountKobo;
  final String status;

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
        fromUserId: json['fromUserId'] as String,
        toUserId: json['toUserId'] as String,
        amountKobo: json['amountKobo'] as int,
        status: json['status'] as String,
      );
}

/// A row from `GET /settlements` — every settlement the caller is on
/// either side of, across all their groups. Richer than [Settlement]
/// (which is just the immediate response to creating one): this carries
/// the group name and both parties' display names so the Wallet history
/// list doesn't need a separate lookup per row.
class SettlementRecord {
  SettlementRecord({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.fromUserId,
    required this.fromName,
    required this.toUserId,
    required this.toName,
    required this.amountKobo,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String fromUserId;
  final String fromName;
  final String toUserId;
  final String toName;
  final int amountKobo;
  final String status;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  factory SettlementRecord.fromJson(Map<String, dynamic> json) => SettlementRecord(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
        groupName: (json['group'] as Map<String, dynamic>?)?['name'] as String? ?? 'A group',
        fromUserId: json['fromUserId'] as String,
        fromName: (json['from'] as Map<String, dynamic>?)?['displayName'] as String? ?? 'Someone',
        toUserId: json['toUserId'] as String,
        toName: (json['to'] as Map<String, dynamic>?)?['displayName'] as String? ?? 'Someone',
        amountKobo: json['amountKobo'] as int,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        confirmedAt:
            json['confirmedAt'] != null ? DateTime.parse(json['confirmedAt'] as String) : null,
      );
}

/// One person's slice of an expense, as shown on the activity detail
/// screen's split breakdown — only present on EXPENSE activity items.
class ActivitySplit {
  ActivitySplit({
    required this.userId,
    required this.displayName,
    required this.shareKobo,
    this.photoUrl,
  });

  final String userId;
  final String displayName;
  final int shareKobo;
  final String? photoUrl;

  factory ActivitySplit.fromJson(Map<String, dynamic> json) => ActivitySplit(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        shareKobo: json['shareKobo'] as int,
        photoUrl: json['photoUrl'] as String?,
      );
}

/// A row from `GET /activity` — a single merged, newest-first feed of
/// expenses and settlements across every group the caller belongs to.
/// The backend tags each row with `type` and only fills in the fields
/// relevant to that type; this reads as one tagged union rather than
/// having two separate item classes with their own list-handling code.
class ActivityItem {
  ActivityItem({
    required this.type,
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.amountKobo,
    required this.createdAt,
    this.description,
    this.template,
    this.payerId,
    this.payerDisplayName,
    this.splits,
    this.fromUserId,
    this.fromDisplayName,
    this.toUserId,
    this.toDisplayName,
    this.status,
    this.confirmedAt,
  });

  final String type; // 'EXPENSE' or 'SETTLEMENT'
  final String id;
  final String groupId;
  final String groupName;
  final int amountKobo;
  final DateTime createdAt;

  // EXPENSE only
  final String? description;
  final String? template;
  final String? payerId;
  final String? payerDisplayName;
  final List<ActivitySplit>? splits;

  // SETTLEMENT only
  final String? fromUserId;
  final String? fromDisplayName;
  final String? toUserId;
  final String? toDisplayName;
  final String? status;
  final DateTime? confirmedAt;

  bool get isExpense => type == 'EXPENSE';

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        type: json['type'] as String,
        id: json['id'] as String,
        groupId: json['groupId'] as String,
        groupName: json['groupName'] as String,
        amountKobo: json['amountKobo'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        description: json['description'] as String?,
        template: json['template'] as String?,
        payerId: json['payerId'] as String?,
        payerDisplayName: json['payerDisplayName'] as String?,
        splits: (json['splits'] as List?)
            ?.map((s) => ActivitySplit.fromJson(s as Map<String, dynamic>))
            .toList(),
        fromUserId: json['fromUserId'] as String?,
        fromDisplayName: json['fromDisplayName'] as String?,
        toUserId: json['toUserId'] as String?,
        toDisplayName: json['toDisplayName'] as String?,
        status: json['status'] as String?,
        confirmedAt:
            json['confirmedAt'] != null ? DateTime.parse(json['confirmedAt'] as String) : null,
      );
}

/// Response of `POST /settlements/recipients`.
class PayoutAccount {
  PayoutAccount({
    required this.bankCode,
    required this.accountNumber,
    required this.accountName,
    required this.paystackRecipientCode,
  });

  final String bankCode;
  final String accountNumber;
  final String accountName;
  final String paystackRecipientCode;

  factory PayoutAccount.fromJson(Map<String, dynamic> json) => PayoutAccount(
        bankCode: json['bankCode'] as String,
        accountNumber: json['accountNumber'] as String,
        accountName: json['accountName'] as String,
        paystackRecipientCode: json['paystackRecipientCode'] as String,
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