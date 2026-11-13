import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/garden/garden_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/onboarding/coach_marks.dart';
import '../features/settings/settings_screen.dart';
import '../features/shelf/shelf_screen.dart';
import '../features/timer/timer_screen.dart';
import 'shell_providers.dart';
import 'tab.dart';
import 'tab_glyph.dart';
import 'torn_edge.dart';

/// The five-tab root. [IndexedStack] keeps every tab alive so scroll
/// positions and state survive switching tabs mid-session.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const Map<AppTab, Widget> _screens = {
    AppTab.garden: GardenScreen(),
    AppTab.shelf: ShelfScreen(),
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
            // Otherwise hidden tabs keep ticking (e.g. the garden's sway).
            TickerMode(
              enabled: tab == selected,
              child: _screens[tab]!,
            ),
        ],
      ),
      // Material's bar for semantics, hit targets and text scaling; the look
      // comes from the torn paper strip and the glyphs.
      bottomNavigationBar: TornEdge(
        child: NavigationBar(
          selectedIndex: selected.index,
          onDestinationSelected: (index) => ref
              .read(selectedTabProvider.notifier)
              .select(AppTab.values[index]),
          destinations: [
            for (final tab in AppTab.values)
              NavigationDestination(
                // Coach mark anchor; null for tabs without a mark.
                key: CoachMarkTargets.forTab(tab),
                icon: TabGlyph(tab),
                selectedIcon: TabGlyph(tab, selected: true),
                label: tab.label,
                tooltip: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}
