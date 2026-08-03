import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/expense_templates.dart';
import '../models/models.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/brand_button.dart';

/// How the expense is divided among the selected participants.
enum _SplitMode { equal, custom, percentage }

/// Add-expense form — flat white, custom header, branded fields and chips
/// instead of the stock Material AppBar/TextField/ChoiceChip look (which
/// was pulling its colors straight from the app-wide seeded ColorScheme,
/// hence the green save button and green selected chips that didn't match
/// anything else in the app). Keeps the same simplified single-screen flow
/// Splitwise's own UX write-ups point to: one description field, one
/// amount, a small fixed set of templates rather than open-ended options,
/// and immediate feedback (the button's own loading state, then popping
/// back) rather than a separate confirmation step.
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
  final Set<String> _selectedParticipantIds = {};

  // Equal (the common case) by default; custom reveals one editable naira
  // amount per selected person, percentage reveals one editable percentage
  // — both for "I ate more than everyone else" and similar uneven cases.
  _SplitMode _splitMode = _SplitMode.equal;
  final Map<String, TextEditingController> _customAmountControllers = {};
  final Map<String, FocusNode> _customFocusNodes = {};
  final Map<String, TextEditingController> _percentageControllers = {};
  final Map<String, FocusNode> _percentageFocusNodes = {};

  final _scrollController = ScrollController();

  List<GroupMember>? _members;
  Object? _loadError;
  bool _saving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    // Only matters in custom-amount mode (percentage's total is independent
    // of the naira amount), but cheap enough to always listen — keeps the
    // remaining/over indicator live as the total changes.
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _descriptionController.dispose();
    _amountController.dispose();
    _scrollController.dispose();
    for (final c in _customAmountControllers.values) {
      c.dispose();
    }
    for (final f in _customFocusNodes.values) {
      f.dispose();
    }
    for (final c in _percentageControllers.values) {
      c.dispose();
    }
    for (final f in _percentageFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// Dismisses the keyboard and un-focuses whatever field was active, and
  /// scrolls back to the top — tapping anywhere outside a field shouldn't
  /// leave its purple focus border lit, or leave the form scrolled to
  /// wherever the keyboard had pushed it while editing a field further down.
  void _dismissAndResetScroll() {
    FocusScope.of(context).unfocus();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  void _onAmountChanged() {
    if (_splitMode == _SplitMode.custom) setState(() {});
  }

  int get _amountKobo => ((double.tryParse(_amountController.text.trim()) ?? 0) * 100).round();

  int get _customTotalKobo => _customAmountControllers.values.fold<int>(
        0,
        (sum, c) => sum + ((double.tryParse(c.text.trim()) ?? 0) * 100).round(),
      );

  int get _customRemainingKobo => _amountKobo - _customTotalKobo;

  double get _percentageTotal => _percentageControllers.values.fold<double>(
        0,
        (sum, c) => sum + (double.tryParse(c.text.trim()) ?? 0),
      );

  double get _percentageRemaining => 100 - _percentageTotal;

  /// Keeps both the custom-amount and percentage controller maps in sync
  /// with whoever's currently selected — called on every participant
  /// change and mode switch, regardless of which mode is active, so
  /// switching back and forth between Custom and Percent doesn't lose
  /// whatever was already typed in the other one. Fields start blank, not
  /// prefilled with an equal-split guess — that used to make "Fully
  /// allocated" show green before anyone had actually entered anything,
  /// misleading for modes that exist specifically for *uneven* splits.
  void _syncSplitControllers() {
    final ids = _selectedParticipantIds.toList();
    _customAmountControllers.removeWhere((id, controller) {
      final drop = !ids.contains(id);
      if (drop) {
        controller.dispose();
        _customFocusNodes.remove(id)?.dispose();
      }
      return drop;
    });
    _percentageControllers.removeWhere((id, controller) {
      final drop = !ids.contains(id);
      if (drop) {
        controller.dispose();
        _percentageFocusNodes.remove(id)?.dispose();
      }
      return drop;
    });

    for (final id in ids) {
      _customAmountControllers.putIfAbsent(id, () => TextEditingController());
      _customFocusNodes.putIfAbsent(id, () => FocusNode());
      _percentageControllers.putIfAbsent(id, () => TextEditingController());
      _percentageFocusNodes.putIfAbsent(id, () => FocusNode());
    }
  }

  Future<void> _loadMembers() async {
    try {
      final members = await context.read<GroupService>().getGroupMembers(widget.groupId);
      if (!mounted) return;
      setState(() {
        _members = members;
        // Only registered members have a userId, which is what
        // ExpenseSplit.userId references — pre-select all of them.
        _selectedParticipantIds.addAll(
          members.where((m) => m.userId != null).map((m) => m.userId!),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  Future<void> _save() async {
    final amountNaira = double.tryParse(_amountController.text.trim());
    setState(() => _validationError = null);
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _validationError = 'Add a description.');
      return;
    }
    if (amountNaira == null || amountNaira <= 0) {
      setState(() => _validationError = 'Enter a valid amount.');
      return;
    }
    if (_selectedParticipantIds.isEmpty) {
      setState(() => _validationError = 'Select at least one participant.');
      return;
    }

    Map<String, int>? customShares;
    Map<String, double>? percentageShares;
    if (_splitMode == _SplitMode.custom) {
      final remaining = _customRemainingKobo;
      if (remaining != 0) {
        setState(() => _validationError = remaining > 0
            ? '${formatKobo(remaining)} left to allocate.'
            : '${formatKobo(-remaining)} over the total, adjust the amounts.');
        return;
      }
      customShares = {
        for (final id in _selectedParticipantIds)
          id: ((double.tryParse(_customAmountControllers[id]?.text.trim() ?? '0') ?? 0) * 100).round(),
      };
    } else if (_splitMode == _SplitMode.percentage) {
      final remaining = _percentageRemaining;
      // Matches the backend's own tolerance (calculateSplits rejects
      // anything off by more than 0.01) so the client never rejects
      // something the server would've accepted, or vice versa.
      if (remaining.abs() > 0.01) {
        setState(() => _validationError = remaining > 0
            ? '${_formatPct(remaining)}% left to allocate.'
            : '${_formatPct(-remaining)}% over 100%, adjust the percentages.');
        return;
      }
      percentageShares = {
        for (final id in _selectedParticipantIds)
          id: double.tryParse(_percentageControllers[id]?.text.trim() ?? '0') ?? 0,
      };
    }

    setState(() => _saving = true);
    try {
      await context.read<GroupService>().addExpense(
            groupId: widget.groupId,
            description: _descriptionController.text.trim(),
            amountKobo: (amountNaira * 100).round(),
            participantIds: _splitMode == _SplitMode.equal ? _selectedParticipantIds.toList() : null,
            customShares: customShares,
            percentageShares: percentageShares,
            template: _template,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissAndResetScroll,
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
                          'Add expense',
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpacingLg),
                    Expanded(
                      child: AsyncView<List<GroupMember>>(
                        loading: _members == null && _loadError == null,
                        error: _loadError,
                        data: _members,
                        onRetry: _loadMembers,
                        builder: (context, members) => ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: kSpacingXl),
                          children: [
                            BrandTextField(
                              controller: _descriptionController,
                              label: 'What was this for?',
                            ),
                            const SizedBox(height: kSpacingMd),
                            BrandTextField(
                              controller: _amountController,
                              label: 'Amount',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              prefixText: '₦ ',
                            ),
                            const SizedBox(height: kSpacingLg),
                            Text('Template', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: kSpacingSm),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: kExpenseTemplates.entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: kSpacingSm),
                                    child: _SelectChip(
                                      label: entry.value.label,
                                      icon: entry.value.icon,
                                      selected: _template == entry.key,
                                      onTap: () => setState(() => _template = entry.key),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: kSpacingLg),
                            Text('Split between', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: kSpacingXs),
                            Text(
                              switch (_splitMode) {
                                _SplitMode.equal => 'Split evenly among everyone selected.',
                                _SplitMode.custom => 'Enter how much each person owes.',
                                _SplitMode.percentage => 'Enter what percentage each person owes.',
                              },
                              style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 13),
                            ),
                            const SizedBox(height: kSpacingSm),
                            Wrap(
                              spacing: kSpacingSm,
                              runSpacing: kSpacingSm,
                              children: members.map((m) {
                                final eligible = m.userId != null;
                                final selected = eligible && _selectedParticipantIds.contains(m.userId);
                                return _SelectChip(
                                  label: eligible ? m.displayName : '${m.displayName} (not joined yet)',
                                  selected: selected,
                                  showCheck: true,
                                  enabled: eligible,
                                  onTap: eligible
                                      ? () => setState(() {
                                            if (selected) {
                                              _selectedParticipantIds.remove(m.userId);
                                            } else {
                                              _selectedParticipantIds.add(m.userId!);
                                            }
                                            // A custom/percentage split needs at
                                            // least two people to divide anything
                                            // between.
                                            if (_selectedParticipantIds.length <= 1) {
                                              _splitMode = _SplitMode.equal;
                                            }
                                            _syncSplitControllers();
                                          })
                                      : null,
                                );
                              }).toList(),
                            ),
                            if (_selectedParticipantIds.length > 1) ...[
                              const SizedBox(height: kSpacingMd),
                              _SplitModeToggle(
                                mode: _splitMode,
                                onChanged: (mode) => setState(() {
                                  _splitMode = mode;
                                  _syncSplitControllers();
                                }),
                              ),
                            ],
                            if (_splitMode == _SplitMode.custom) ...[
                              const SizedBox(height: kSpacingMd),
                              ...members
                                  .where((m) => m.userId != null && _selectedParticipantIds.contains(m.userId))
                                  .map(
                                    (m) => _SplitAmountRow(
                                      name: m.displayName,
                                      controller: _customAmountControllers[m.userId]!,
                                      focusNode: _customFocusNodes[m.userId]!,
                                      prefixText: '₦',
                                      onChanged: () => setState(() {}),
                                    ),
                                  ),
                              _SplitRemainingBanner(
                                settled: _customRemainingKobo == 0,
                                label: _customRemainingKobo == 0
                                    ? 'Fully allocated'
                                    : _customRemainingKobo > 0
                                        ? '${formatKobo(_customRemainingKobo)} left to allocate'
                                        : '${formatKobo(-_customRemainingKobo)} over the total',
                              ),
                            ] else if (_splitMode == _SplitMode.percentage) ...[
                              const SizedBox(height: kSpacingMd),
                              ...members
                                  .where((m) => m.userId != null && _selectedParticipantIds.contains(m.userId))
                                  .map(
                                    (m) => _SplitAmountRow(
                                      name: m.displayName,
                                      controller: _percentageControllers[m.userId]!,
                                      focusNode: _percentageFocusNodes[m.userId]!,
                                      suffixText: '%',
                                      onChanged: () => setState(() {}),
                                    ),
                                  ),
                              _SplitRemainingBanner(
                                settled: _percentageRemaining.abs() <= 0.01,
                                label: _percentageRemaining.abs() <= 0.01
                                    ? 'Fully allocated'
                                    : _percentageRemaining > 0
                                        ? '${_formatPct(_percentageRemaining)}% left to allocate'
                                        : '${_formatPct(-_percentageRemaining)}% over 100%',
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
                            BrandButton(label: 'Save expense', loading: _saving, onPressed: _save),
                          ],
                        ),
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

/// Trims a whole-number percentage down to "20" instead of "20.0", but
/// keeps one decimal place for anything that actually needs it ("33.3").
String _formatPct(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

/// A single pill used for both the template picker and the participant
/// picker — purple tint/border when selected (matching the rest of the
/// app's interactive/selection color, not the seeded green the default
/// ChoiceChip/FilterChip were pulling from), a muted grey when not, and a
/// visibly disabled state for a not-yet-joined participant who can't be
/// split with.
class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    this.icon,
    this.showCheck = false,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final bool showCheck;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? Colors.black.withOpacity(0.35)
        : selected
            ? kBrandPurple
            : Colors.black.withOpacity(0.65);
    final background = !enabled
        ? Colors.black.withOpacity(0.04)
        : selected
            ? kBrandPurple.withOpacity(0.12)
            : const Color(0xFFF7F6FA);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: kSpacingMd, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected && enabled ? Border.all(color: kBrandPurple.withOpacity(0.4)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showCheck && selected && enabled) ...[
                Icon(Icons.check_rounded, size: 16, color: color),
                const SizedBox(width: 6),
              ] else if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A three-option segmented switch — "Equal" (the default, the common
/// case), "Custom" (naira amounts), and "Percent" (percentages), all
/// summing to the same total a different way. The classic iOS/Material
/// segmented-control pattern: a pill slides behind whichever label is
/// active rather than each segment just swapping its own background color
/// in place, which read as an abrupt jump instead of a single continuous
/// motion.
class _SplitModeToggle extends StatelessWidget {
  const _SplitModeToggle({required this.mode, required this.onChanged});
  final _SplitMode mode;
  final ValueChanged<_SplitMode> onChanged;

  static const _duration = Duration(milliseconds: 260);
  static const _modes = _SplitMode.values;
  static const _labels = {
    _SplitMode.equal: 'Equal',
    _SplitMode.custom: 'Custom',
    _SplitMode.percentage: 'Percent',
  };

  @override
  Widget build(BuildContext context) {
    final index = _modes.indexOf(mode);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF7F6FA), borderRadius: BorderRadius.circular(999)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / _modes.length;
          return Stack(
            children: [
              AnimatedAlign(
                duration: _duration,
                curve: Curves.easeOutCubic,
                // Maps segment index 0..N-1 onto Alignment's -1..1 x-axis,
                // so the sliding pill lands under whichever segment (of
                // however many there are) is currently selected.
                alignment: Alignment(-1 + 2 * index / (_modes.length - 1), 0),
                child: Container(
                  width: segmentWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: kBrandPurple,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(color: kBrandPurple.withOpacity(0.28), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                ),
              ),
              Row(
                children: _modes
                    .map((m) => Expanded(child: _segment(_labels[m]!, m == mode, () => onChanged(m))))
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        height: double.infinity,
        child: AnimatedDefaultTextStyle(
          duration: _duration,
          curve: Curves.easeOutCubic,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black.withOpacity(0.6),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// One editable amount for a custom or percentage split — a name and a
/// small right-aligned field (₦ prefix or % suffix, never both), rather
/// than [BrandTextField]'s full floating-label treatment which is too
/// heavy repeated once per person.
class _SplitAmountRow extends StatelessWidget {
  const _SplitAmountRow({
    required this.name,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.prefixText,
    this.suffixText,
  });
  final String name;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final String? prefixText;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacingSm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: kSpacingSm),
          SizedBox(
            width: 112,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              onChanged: (_) => onChanged(),
              cursorColor: kBrandPurple,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black),
              decoration: InputDecoration(
                prefixText: prefixText,
                suffixText: suffixText,
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF7F6FA),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBrandPurple, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live running total for a custom or percentage split — green and settled
/// once everything's allocated, red with the shortfall or overage
/// otherwise, so there's no guessing why Save won't go through. The caller
/// computes [label] (kobo-formatted for custom, "%"-suffixed for
/// percentage) since the two modes format their numbers differently.
class _SplitRemainingBanner extends StatelessWidget {
  const _SplitRemainingBanner({required this.settled, required this.label});
  final bool settled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = settled ? kSeedColor : const Color(0xFFD32F2F);
    return Container(
      margin: const EdgeInsets.only(top: kSpacingXs),
      padding: const EdgeInsets.symmetric(horizontal: kSpacingMd, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(kRadius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(settled ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
