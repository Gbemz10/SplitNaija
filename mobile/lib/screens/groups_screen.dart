import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/brand_button.dart';
import '../widgets/brand_sheet.dart';
import '../widgets/group_avatar.dart';
import '../widgets/refreshable_state.dart';
import '../widgets/user_avatar.dart';
import 'group_detail_screen.dart';
import 'profile_screen.dart';

/// Home screen after login — flat white, no branded banner. The greeting
/// carries the brand instead of a logo lockup: big, black, first thing you
/// read.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends RefreshableState<GroupsScreen> {
  List<Group>? _groups;
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
      final groups = await context.read<GroupService>().listMyGroups();
      if (!mounted) return;
      setState(() => _groups = groups);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _createGroupDialog() async {
    final name = await showBrandInputSheet(
      context,
      title: 'New group',
      subtitle: 'Create a group',
      label: 'Group name',
      primaryLabel: 'Create group',
      minLength: 5,
      helperText: 'At least 5 characters',
    );
    // The sheet's own button is disabled below 5 characters, but this
    // guards the same way in case it's ever called from somewhere else.
    if (name != null && name.trim().length >= 5 && mounted) {
      try {
        await context.read<GroupService>().createGroup(name.trim());
        _load();
      } catch (e) {
        if (mounted) showApiError(context, e);
      }
    }
  }

  Future<void> _joinGroupDialog() async {
    final code = await showBrandInputSheet(
      context,
      title: 'Join a group',
      subtitle: 'Ask whoever made the group for their invite code.',
      label: 'Invite code',
      primaryLabel: 'Join group',
      textCapitalization: TextCapitalization.characters,
    );
    if (code != null && code.trim().isNotEmpty && mounted) {
      try {
        final member = await context.read<GroupService>().joinGroup(code.trim());
        _load();
        if (!mounted) return;
        // A passive toast either way, not a blocking alert — joining a
        // group you already belong to (your own, or one you'd joined
        // before) isn't an error, it just needs a quick "nothing to do
        // here" nudge instead of silently doing nothing.
        _showJoinToast(
          member.alreadyMember
              ? "You're already in ${member.groupName ?? 'this group'}"
              : 'Joined ${member.groupName ?? 'the group'}',
        );
      } catch (e) {
        if (mounted) showApiError(context, e);
      }
    }
  }

  void _showJoinToast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        ),
      );
  }

  Future<bool> _confirmAndDeleteGroup(Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BrandDialog(
        title: 'Delete group?',
        content: Text(
          'This removes "${group.name}" and its expenses for everyone in it. This can\'t be undone.',
        ),
        primaryLabel: 'Delete',
        danger: true,
        icon: Icons.delete_outline_rounded,
        onPrimary: () => Navigator.pop(context, true),
      ),
    );
    if (confirmed != true) return false;

    try {
      await context.read<GroupService>().deleteGroup(group.id);
      if (mounted) setState(() => _groups?.removeWhere((g) => g.id == group.id));
      return true;
    } catch (e) {
      // Return false so the card animates back into place instead of
      // vanishing — it wasn't actually deleted (e.g. a 403 if this isn't
      // the group's creator).
      if (mounted) showApiError(context, e);
      return false;
    }
  }

  /// Sum of every group's net balance, client-side, the same "You are owed
  /// $40 overall" rollup Splitwise shows above the list so the person
  /// doesn't have to add it up themselves. Null while groups haven't
  /// loaded yet.
  int? get _overallNetKobo {
    final groups = _groups;
    if (groups == null) return null;
    return groups.fold<int>(0, (sum, g) => sum + (g.netBalanceKobo ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final firstName = (user?.displayName ?? '').split(' ').first;
    final overallNet = _overallNetKobo;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            firstName.isEmpty ? 'Welcome' : 'Hey, $firstName',
                            style: const TextStyle(
                              fontFamily: kFontFamily,
                              color: Colors.black,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: kSpacingSm),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          ),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1EFF7),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE4E0EF)),
                            ),
                            // Once a real photo is set, show it — until
                            // then this stays a generic placeholder (not
                            // initials, not filled), since "your profile"
                            // shouldn't pretend to be an actual photo when
                            // there isn't one.
                            child: user?.photoUrl != null
                                ? UserAvatar(name: '', seed: user!.id, photoUrl: user.photoUrl, radius: 20)
                                : const Icon(Icons.person_outline_rounded, color: kBrandPurple, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpacingXs),
                    Text(
                      "Here's what your crew's been up to.",
                      style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w500),
                    ),
                    if (overallNet != null && overallNet != 0) ...[
                      const SizedBox(height: kSpacingMd),
                      _OverallBalanceBadge(netKobo: overallNet),
                    ],
                    const SizedBox(height: kSpacingLg),
                    Row(
                      children: [
                        Text('Your groups', style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        BrandOutlinedButton(
                          label: 'Join',
                          icon: Icons.group_add_outlined,
                          onPressed: _joinGroupDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpacingMd),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: AsyncView<List<Group>>(
                          loading: _groups == null && _error == null,
                          error: _error,
                          data: _groups,
                          onRetry: _load,
                          builder: (context, groups) => groups.isEmpty
                              ? _EmptyGroups(onCreate: _createGroupDialog)
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 100),
                                  itemCount: groups.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: kSpacingSm),
                                  itemBuilder: (context, i) {
                                    final group = groups[i];
                                    return Dismissible(
                                      key: ValueKey(group.id),
                                      direction: DismissDirection.startToEnd,
                                      confirmDismiss: (_) => _confirmAndDeleteGroup(group),
                                      background: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(horizontal: kSpacingLg),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD32F2F),
                                          borderRadius: BorderRadius.circular(kRadius),
                                        ),
                                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                                      ),
                                      child: _GroupCard(
                                        group: group,
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
                                          );
                                          _load();
                                        },
                                      ),
                                    );
                                  },
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
        floatingActionButton: FloatingActionButton(
          backgroundColor: kBrandPurple,
          foregroundColor: Colors.white,
          onPressed: _createGroupDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

/// The rollup pill above the list, "You're owed ₦X overall" / "You owe ₦X
/// overall", summing every group's balance so the person gets the headline
/// number without doing the math themselves.
class _OverallBalanceBadge extends StatelessWidget {
  const _OverallBalanceBadge({required this.netKobo});
  final int netKobo;

  @override
  Widget build(BuildContext context) {
    final owed = netKobo > 0;
    final color = owed ? kSeedColor : const Color(0xFFD32F2F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpacingMd, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            owed ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: kSpacingXs),
          Flexible(
            child: Text(
              owed
                  ? "You're owed ${formatKobo(netKobo.abs())} overall"
                  : 'You owe ${formatKobo(netKobo.abs())} overall',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});
  final Group group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final memberCount = group.memberCount;
    final net = group.netBalanceKobo;

    // Splitwise's convention (and the one that tested best in their own
    // redesign write-ups): a color-coded balance right under the group
    // name so you know who stands where without opening it, green for
    // owed to you, red for you owe. Falls back to the member count when
    // there's nothing to settle, rather than showing both and cluttering
    // the row.
    Widget? secondLine;
    if (net != null && net != 0) {
      final owed = net > 0;
      final color = owed ? kSeedColor : const Color(0xFFD32F2F);
      secondLine = Text(
        owed ? "You're owed ${formatKobo(net.abs())}" : 'You owe ${formatKobo(net.abs())}',
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
      );
    } else if (memberCount != null) {
      secondLine = Text(
        memberCount == 1 ? '1 member' : '$memberCount members',
        style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 13),
      );
    }

    return Material(
      color: const Color(0xFFF7F6FA),
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(kSpacingMd),
          child: Row(
            children: [
              GroupAvatar(name: group.name, seed: group.id),
              const SizedBox(width: kSpacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (secondLine != null) ...[
                      const SizedBox(height: 2),
                      secondLine,
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder + a min-height ConstrainedBox, not a fixed-height
    // SizedBox — this keeps the content pull-to-refreshable (it's still a
    // scroll view) while actually centering in whatever space is left
    // above the FAB, instead of guessing a fraction of the screen height.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _EmptyIllustration(),
                    const SizedBox(height: kSpacingLg),
                    const Text(
                      'No groups yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: kSpacingXs),
                    Text(
                      'Create a group to start splitting bills, or join one with an invite code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black.withOpacity(0.55)),
                    ),
                    const SizedBox(height: kSpacingLg),
                    SizedBox(
                      width: 220,
                      child: BrandButton(label: 'Create a group', onPressed: onCreate),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A small "friends gathered around a bill" scene, built entirely from
/// shapes/icons (no external asset) — a group of people around a receipt,
/// standing in for "nothing split here yet" instead of just the app logo.
class _EmptyIllustration extends StatelessWidget {
  const _EmptyIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(color: kBrandPurple.withOpacity(0.08), shape: BoxShape.circle),
          ),
          Positioned(top: 12, left: 6, child: _personDot(kPieColors[2], 30)),
          Positioned(top: 4, right: 10, child: _personDot(kPieColors[3], 26)),
          Positioned(bottom: 10, left: 20, child: _personDot(kPieColors[4], 24)),
          Positioned(bottom: 6, right: 0, child: _personDot(kPieColors[1], 28)),
          Transform.rotate(
            angle: -0.06,
            child: Container(
              width: 88,
              height: 108,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: kBrandPurple.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.receipt_long_rounded, color: kBrandPurple, size: 18),
                  ),
                  const SizedBox(height: 10),
                  _line(46),
                  const SizedBox(height: 6),
                  _line(32),
                  const SizedBox(height: 6),
                  _line(38),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(Icons.person_rounded, color: Colors.white, size: size * 0.6),
    );
  }

  Widget _line(double width) {
    return Container(
      width: width,
      height: 6,
      decoration: BoxDecoration(color: const Color(0xFFE9E7F0), borderRadius: BorderRadius.circular(3)),
    );
  }
}
