import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/garden/garden_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/onboarding/coach_marks.dart';
import '../features/settings/settings_screen.dart';
import '../features/timer/timer_screen.dart';
import 'shell_providers.dart';
import 'tab.dart';

/// The four-tab shell that is the app's root.
///
/// Every tab's subtree is built once and kept alive by the [IndexedStack], so
/// switching tabs does not rebuild a screen from scratch: scroll positions,
/// text fields and in-flight animations survive. That matters here more than in
/// most apps — a running session lives on the timer tab, and the user is
/// expected to wander over to the garden and back while it runs.
///
/// Which tab is showing lives in `selectedTabProvider` rather than in this
/// widget, because the bar is no longer the only thing that chooses one: a tap
/// on the live surface arrives from the platform and has to land on the timer.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const Map<AppTab, Widget> _screens = {
    AppTab.garden: GardenScreen(),
    AppTab.timer: TimerScreen(),
    AppTab.journal: JournalScreen(),
    AppTab.settings: SettingsScreen(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: selected.index,
        children: [
          for (final tab in AppTab.values)
            // An [IndexedStack] keeps every tab's tickers running, which for a
            // screen with a continuous ambient animation on it — the garden's
            // swaying plants, REQ-023 — means paying for frames nobody can see.
            // The state the tabs are kept alive for is not in the tickers, so
            // silencing them costs nothing and saves a repaint loop per hidden
            // tab.
            TickerMode(
              enabled: tab == selected,
              child: _screens[tab]!,
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected.index,
        onDestinationSelected: (index) => ref
            .read(selectedTabProvider.notifier)
            .select(AppTab.values[index]),
        destinations: [
          for (final tab in AppTab.values)
            NavigationDestination(
              // Two of the four carry a key, so that a coach mark can find the
              // destination it is about rather than being told where the bar
              // puts it. Null on the other two, which nothing points at.
              key: CoachMarkTargets.forTab(tab),
              icon: Icon(tab.icon),
              label: tab.label,
              tooltip: tab.label,
            ),
        ],
      ),
    );
  }
}
