import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/refreshable_state.dart';
import 'activity_screen.dart';
import 'groups_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';

/// The signed-in app's persistent shell: four tabs (Groups, Activity,
/// Wallet, Account) behind a bottom nav bar. Each tab is a full `Scaffold`
/// in its own right — nesting them inside this shell's body is the
/// standard Flutter pattern and keeps each tab's own AppBar/FAB local to
/// it, rather than trying to hoist those into one shared outer Scaffold.
///
/// `IndexedStack` (not swapping the child directly) keeps every tab's
/// scroll position and already-loaded data alive when switching away and
/// back, instead of re-fetching each time.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // One key per refreshable tab so switching to it can call its own
  // `refresh()` — the IndexedStack below keeps every tab alive once built,
  // so without this a tab's data only ever loaded once, the first time you
  // visited it, and never again (e.g. Activity not showing an expense you'd
  // just added on the Groups tab until the app was restarted).
  final _groupsKey = GlobalKey<RefreshableState<GroupsScreen>>();
  final _activityKey = GlobalKey<RefreshableState<ActivityScreen>>();
  final _walletKey = GlobalKey<RefreshableState<WalletScreen>>();

  late final _tabs = [
    GroupsScreen(key: _groupsKey),
    ActivityScreen(key: _activityKey),
    WalletScreen(key: _walletKey),
    const ProfileScreen(),
  ];

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    switch (index) {
      case 0:
        _groupsKey.currentState?.refresh();
        break;
      case 1:
        _activityKey.currentState?.refresh();
        break;
      case 2:
        _walletKey.currentState?.refresh();
        break;
    }
  }

  static const _items = [
    _NavItemData(icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, label: 'Groups'),
    _NavItemData(icon: Icons.timeline_outlined, activeIcon: Icons.timeline_rounded, label: 'Activity'),
    _NavItemData(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Wallet',
    ),
    _NavItemData(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      // The white background/shadow goes on the outer Container, and
      // SafeArea is the *inner* child — not the other way around. SafeArea
      // only pads its child away from the home indicator; it doesn't paint
      // anything itself. Wrapping it around the white Container left the
      // safe-area inset at the very bottom showing the scaffold's own
      // (off-white) background instead of white, which read as the nav
      // bar not quite reaching the edge of the screen.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (i) {
                return _NavTabButton(
                  data: _items[i],
                  selected: i == _index,
                  onTap: () => _selectTab(i),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// A single bottom-nav tab. The selected icon animates to a slightly
/// larger scale with a bouncy overshoot curve — a small, deliberate motion
/// so it's obvious which tab is active, not just a color/fill swap.
class _NavTabButton extends StatelessWidget {
  const _NavTabButton({required this.data, required this.selected, required this.onTap});

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  static const _animationDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final color = selected ? kBrandPurple : Colors.black.withOpacity(0.4);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.18 : 1.0,
                duration: _animationDuration,
                curve: Curves.easeOutBack,
                child: Icon(selected ? data.activeIcon : data.icon, color: color, size: 26),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: _animationDuration,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(data.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
