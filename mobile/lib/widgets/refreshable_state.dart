import 'package:flutter/material.dart';

/// A tab hosted inside [MainShell]'s `IndexedStack` stays mounted forever
/// once built — switching tabs doesn't dispose/recreate it, so a screen's
/// own `initState` fetch only ever runs once. That's exactly right for
/// keeping scroll position and already-loaded data, but it also meant
/// Activity (and Wallet) kept showing whatever they'd loaded the first
/// time you visited, even after adding a new expense elsewhere — nothing
/// re-fetched until the whole app restarted.
///
/// Extend this instead of bare `State<T>` on any tab screen, exposing its
/// existing load method as `refresh()`. `MainShell` holds a `GlobalKey` per
/// tab and calls `refresh()` on whichever one you just switched to.
abstract class RefreshableState<T extends StatefulWidget> extends State<T> {
  Future<void> refresh();
}
