import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/features/garden/garden_header.dart';
import 'package:pip_garden/src/features/garden/garden_screen.dart';
import 'package:pip_garden/src/features/journal/journal_screen.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/features/timer/timer_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';
import 'package:pip_garden/src/shell/tab_glyph.dart';
import 'package:pip_garden/src/shell/torn_edge.dart';

import '../support/app_harness.dart';

/// Asserts [tab] is the one on screen. There are no app bars, so each tab is
/// recognised by its header; `IndexedStack` keeps every tab in the tree, so it
/// has to be hit-testable too.
void _expectShowing(WidgetTester tester, AppTab tab) {
  final heading = switch (tab) {
    AppTab.garden => find.descendant(
        of: find.byType(GardenHeader),
        matching: find.text(GardenHeader.headline(0)),
      ),
    AppTab.timer => find.descendant(
        of: find.byType(TimerScreen),
        matching: find.text('Ready to focus'),
      ),
    AppTab.journal => find.descendant(
        of: find.byType(JournalScreen),
        matching: find.text('Your journal'),
      ),
    AppTab.settings => find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.text('Settings'),
      ),
  };
  expect(heading.hitTestable(), findsOneWidget);
  expect(find.byType(AppBar), findsNothing);
}

void main() {
  testWidgets('launches on the garden tab', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    _expectShowing(tester, AppTab.garden);
  });

  testWidgets('offers exactly the four tabs, in order', (tester) async {
    await pumpApp(tester);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(bar.destinations, hasLength(4));
    expect(
      bar.destinations
          .cast<NavigationDestination>()
          .map((destination) => destination.label),
      ['Garden', 'Timer', 'Journal', 'Settings'],
    );
  });

  testWidgets('draws each tab its own line glyph', (tester) async {
    await pumpApp(tester);

    final destinations = tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .destinations
        .cast<NavigationDestination>()
        .toList();

    // Custom line drawings; selected is a heavier line, not a filled glyph.
    for (final (index, tab) in AppTab.values.indexed) {
      final icon = destinations[index].icon as TabGlyph;
      final selected = destinations[index].selectedIcon! as TabGlyph;
      expect(icon.tab, tab);
      expect(icon.selected, isFalse);
      expect(selected.tab, tab);
      expect(selected.selected, isTrue);
    }
  });

  testWidgets('the bar has a torn top edge that takes no taps',
      (tester) async {
    await pumpApp(tester);

    final bar = find.byType(NavigationBar);
    expect(
      find.ancestor(of: bar, matching: find.byType(TornEdge)),
      findsOneWidget,
    );

    // The tear overlaps the screen above the bar; taps there go through.
    final tear = find.descendant(
      of: find.byType(TornEdge),
      matching: find.byType(IgnorePointer),
    );
    expect(tester.widget<IgnorePointer>(tear.first).ignoring, isTrue);
    expect(
      tester.getRect(tear.first).top,
      lessThan(tester.getRect(bar).top),
    );
  });

  testWidgets('shows a distinct screen for each tab', (tester) async {
    await pumpApp(tester);

    for (final tab in AppTab.values) {
      await tapTab(tester, tab);
      _expectShowing(tester, tab);
    }

    // Offstage tabs stay in the tree under the stack.
    expect(find.byType(GardenScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(TimerScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(JournalScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(SettingsScreen, skipOffstage: false), findsOneWidget);
  });

  group('per-tab state', () {
    testWidgets('survives switching away and back', (tester) async {
      // Short enough that the journal scrolls.
      await pumpApp(tester, surface: const Size(320, 320));

      ScrollableState journalScroll() => tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(JournalScreen, skipOffstage: false),
              matching: find.byType(Scrollable, skipOffstage: false),
            ),
          );

      await tapTab(tester, AppTab.journal);

      final before = journalScroll();
      final extent = before.position.maxScrollExtent;
      expect(
        extent,
        greaterThan(0),
        reason: 'Nothing to preserve if the screen cannot scroll; shrink the '
            'test surface until it can.',
      );

      before.position.jumpTo(extent);
      await tester.pump();

      await tapTab(tester, AppTab.settings);
      await tapTab(tester, AppTab.journal);

      final after = journalScroll();
      expect(
        identical(before, after),
        isTrue,
        reason: 'The journal screen was rebuilt from scratch, so anything it '
            'held (an animation, a scroll position) was lost.',
      );
      // Clamped to the current extent, so compare against that.
      expect(after.position.pixels, greaterThan(0));
      expect(after.position.pixels, after.position.maxScrollExtent);
    });

    testWidgets('keeps every tab mounted while another is selected',
        (tester) async {
      await pumpApp(tester);

      await tapTab(tester, AppTab.settings);

      expect(find.byType(GardenScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(TimerScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(JournalScreen, skipOffstage: false), findsOneWidget);
    });
  });
}
