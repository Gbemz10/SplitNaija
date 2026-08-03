import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/nigerian_banks.dart';
import '../services/auth_service.dart';
import '../services/settlement_service.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/brand_button.dart';

/// Lets a user register the bank account that settlements pay out to.
/// Required before anyone else can settle up with them (backend rejects
/// with "Recipient has not set up a payout account yet" otherwise).
///
/// Flat white / branded-field language matching the rest of the app, and a
/// searchable bank picker (a plain dropdown meant scrolling through ~20+
/// banks to find one) instead of the stock DropdownButtonFormField.
class RecipientSetupScreen extends StatefulWidget {
  const RecipientSetupScreen({super.key});

  @override
  State<RecipientSetupScreen> createState() => _RecipientSetupScreenState();
}

class _RecipientSetupScreenState extends State<RecipientSetupScreen> {
  final _accountNumberController = TextEditingController();
  NigerianBank? _bank;
  bool _saving = false;
  String? _resolvedName;
  String? _validationError;

  // Starts on the read-only "here's what's on file" view when a payout
  // account already exists — flips to true (via "Change account") to reveal
  // the same form used for first-time setup, pre-filled with the current
  // bank so changing it isn't a blank-slate re-entry of everything.
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _editing = !(user?.hasPayoutAccount ?? false);
    final bankCode = user?.bankCode;
    if (bankCode != null) {
      _bank = kNigerianBanks.firstWhere(
        (b) => b.code == bankCode,
        orElse: () => NigerianBank(bankCode, bankCode),
      );
    }
    final accountNumber = user?.accountNumber;
    if (accountNumber != null) {
      _accountNumberController.text = accountNumber;
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickBank() async {
    final picked = await _showBankPicker(context, _bank);
    if (picked != null) {
      setState(() {
        _bank = picked;
        _resolvedName = null;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _validationError = null);
    if (_bank == null) {
      setState(() => _validationError = 'Choose your bank.');
      return;
    }
    if (_accountNumberController.text.trim().length < 10) {
      setState(() => _validationError = 'Enter your 10-digit account number.');
      return;
    }

    setState(() {
      _saving = true;
      _resolvedName = null;
    });
    try {
      final account = await context.read<SettlementService>().setUpRecipient(
            bankCode: _bank!.code,
            accountNumber: _accountNumberController.text.trim(),
          );
      if (!mounted) return;
      final authService = context.read<AuthService>();
      final current = authService.currentUser;
      if (current != null) {
        authService.updateCurrentUser(current.copyWith(
          paystackRecipientCode: account.paystackRecipientCode,
          bankCode: account.bankCode,
          accountNumber: account.accountNumber,
          accountName: account.accountName,
        ));
      }
      setState(() {
        _resolvedName = account.accountName;
        _editing = false;
      });
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
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
                        const Text(
                          'Payout account',
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
                        children: [
                          Text(
                            'Group members will pay this bank account when they settle up with you.',
                            style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: kSpacingLg),
                          if (!_editing && user != null && user.hasPayoutAccount)
                            _PayoutDetailsCard(
                              bankName: kNigerianBanks
                                  .firstWhere(
                                    (b) => b.code == user.bankCode,
                                    orElse: () => NigerianBank(user.bankCode ?? 'Bank', user.bankCode ?? ''),
                                  )
                                  .name,
                              accountNumber: user.accountNumber ?? '',
                              accountName: user.accountName ?? '',
                              onChangeAccount: () => setState(() {
                                _editing = true;
                                _resolvedName = null;
                              }),
                            )
                          else ...[
                            _BankPickerField(bank: _bank, onTap: _pickBank),
                            const SizedBox(height: kSpacingMd),
                            BrandTextField(
                              controller: _accountNumberController,
                              label: 'Account number',
                              keyboardType: TextInputType.number,
                              maxLength: 10,
                            ),
                            if (_resolvedName != null) ...[
                              const SizedBox(height: kSpacingMd),
                              Container(
                                padding: const EdgeInsets.all(kSpacingMd),
                                decoration: BoxDecoration(
                                  color: kSeedColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(kRadius),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: kSeedColor),
                                    const SizedBox(width: kSpacingSm),
                                    Expanded(
                                      child: Text(
                                        'Confirmed: $_resolvedName',
                                        style: const TextStyle(color: kSeedColor, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_validationError != null) ...[
                              const SizedBox(height: kSpacingMd),
                              Text(
                                _validationError!,
                                style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w500),
                              ),
                            ],
                            const SizedBox(height: kSpacingLg),
                            BrandButton(
                              label: 'Confirm account',
                              loading: _saving,
                              onPressed: _submit,
                            ),
                            if (user != null && user.hasPayoutAccount) ...[
                              const SizedBox(height: kSpacingMd),
                              Center(
                                child: TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() {
                                            _editing = false;
                                            _validationError = null;
                                            _bank = user.bankCode != null
                                                ? kNigerianBanks.firstWhere(
                                                    (b) => b.code == user.bankCode,
                                                    orElse: () => NigerianBank(user.bankCode!, user.bankCode!),
                                                  )
                                                : null;
                                            _accountNumberController.text = user.accountNumber ?? '';
                                          }),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.black.withOpacity(0.5), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only "here's what's on file" view shown once a payout account
/// already exists, instead of dropping the person back into a blank
/// bank/account-number form every time they open this screen.
class _PayoutDetailsCard extends StatelessWidget {
  const _PayoutDetailsCard({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.onChangeAccount,
  });
  final String bankName;
  final String accountNumber;
  final String accountName;
  final VoidCallback onChangeAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(kSpacingMd),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F6FA),
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: kSeedColor.withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(Icons.check_circle_rounded, color: kSeedColor, size: 22),
                  ),
                  const SizedBox(width: kSpacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(accountName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(bankName, style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpacingMd),
              const Divider(height: 1, color: Color(0xFFEFEDF4)),
              const SizedBox(height: kSpacingMd),
              Row(
                children: [
                  Text(
                    'Account number',
                    style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(accountNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: kSpacingMd),
        BrandOutlinedButton(label: 'Change account', icon: Icons.edit_outlined, onPressed: onChangeAccount),
      ],
    );
  }
}

/// The tappable field that opens the searchable bank picker — styled to
/// match [BrandTextField] (same white/bordered box, same label position)
/// so it reads as part of the same form instead of a different control type.
class _BankPickerField extends StatelessWidget {
  const _BankPickerField({required this.bank, required this.onTap});
  final NigerianBank? bank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // InputDecorator, not a hand-rolled label-over-value Column — that
    // stacked two lines of text inside the same content padding
    // BrandTextField uses for a single line, so it came out visibly
    // taller, and its "Bank" label just sat inside the box as plain text
    // instead of on the border the way a real floating label does. This
    // renders through the exact same decoration machinery as the other
    // field, so it matches height-for-height and the label floats onto
    // the border the same way once a bank is chosen.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: InputDecorator(
          isEmpty: bank == null,
          decoration: InputDecoration(
            labelText: 'Bank',
            labelStyle: TextStyle(color: Colors.black.withOpacity(0.45), fontWeight: FontWeight.w500),
            floatingLabelStyle: TextStyle(color: Colors.black.withOpacity(0.5), fontWeight: FontWeight.w600),
            suffixIcon: Icon(Icons.expand_more_rounded, color: Colors.black.withOpacity(0.4)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadius),
              borderSide: const BorderSide(color: Color(0xFFE4E0EF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadius),
              borderSide: const BorderSide(color: Color(0xFFE4E0EF)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: kSpacingMd, vertical: kSpacingMd),
          ),
          child: Text(
            bank?.name ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Opens a searchable bottom sheet over [kNigerianBanks] instead of making
/// people scroll through the whole list to find their bank.
Future<NigerianBank?> _showBankPicker(BuildContext context, NigerianBank? current) {
  return showModalBottomSheet<NigerianBank>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _BankPickerSheet(current: current),
  );
}

class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet({this.current});
  final NigerianBank? current;

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchController = TextEditingController();
  late List<NigerianBank> _results = kNigerianBanks;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _results = query.isEmpty
          ? kNigerianBanks
          : kNigerianBanks.where((b) => b.name.toLowerCase().contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingLg, kSpacingLg, kSpacingMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choose your bank',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, color: Colors.black54),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpacingMd),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  cursorColor: kBrandPurple,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Search banks',
                    hintStyle: TextStyle(color: Colors.black.withOpacity(0.4)),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.black.withOpacity(0.4)),
                    filled: true,
                    fillColor: const Color(0xFFF7F6FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(kRadius),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(kRadius),
                      borderSide: const BorderSide(color: kBrandPurple, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: kSpacingSm),
                  ),
                ),
                const SizedBox(height: kSpacingSm),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: _results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
                          child: Center(
                            child: Text(
                              'No banks match that search.',
                              style: TextStyle(color: Colors.black.withOpacity(0.5)),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEFEDF4)),
                          itemBuilder: (context, i) {
                            final bank = _results[i];
                            final selected = bank.code == widget.current?.code;
                            // Wrapped in its own Material, not a bare
                            // ListTile — the sheet's own outer Container is
                            // an opaque white DecoratedBox sitting between
                            // this and showModalBottomSheet's Material, which
                            // silently swallows ListTile's ink splashes
                            // without one of its own to paint on instead.
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  bank.name,
                                  style: TextStyle(
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    color: selected ? kBrandPurple : Colors.black,
                                  ),
                                ),
                                trailing: selected ? const Icon(Icons.check_rounded, color: kBrandPurple) : null,
                                onTap: () => Navigator.pop(context, bank),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
