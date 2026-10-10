import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_garden/src/features/garden/garden_screen.dart';
import 'package:pomodoro_garden/src/features/journal/journal_screen.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/features/timer/timer_screen.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../support/app_harness.dart';

/// The title shown by the currently visible tab — i.e. the one `IndexedStack`
/// is not hiding. Every tab's subtree stays in the widget tree, so
/// `find.text` alone would match all four.
String _visibleTitle(WidgetTester tester) {
  final titles = tester
      .widgetList<Text>(find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(Text),
      ))
      .map((text) => text.data)
      .whereType<String>()
      .toList();

  final visible = titles.where((title) {
    final finder = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(title),
    );
    return tester.any(finder.hitTestable());
  }).toList();

  expect(visible, hasLength(1), reason: 'Expected exactly one visible tab');
  return visible.single;
}

void main() {
  testWidgets('launches on the garden tab', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(_visibleTitle(tester), AppTab.garden.label);
  });

  testWidgets('offers exactly the four tabs, in PRD order', (tester) async {
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

  testWidgets('uses line icons in the tab bar', (tester) async {
    await pumpApp(tester);

    final icons = tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .destinations
        .cast<NavigationDestination>()
        .map((destination) => (destination.icon as Icon).icon);

    expect(
      icons,
      const [
        Icons.local_florist_outlined,
        Icons.timer_outlined,
        Icons.menu_book_outlined,
        Icons.settings_outlined,
      ],
      reason: 'PRD §5.1 asks for minimalist line icons — the outlined set.',
    );
  });

  testWidgets('shows a distinct screen for each tab', (tester) async {
    await pumpApp(tester);

    for (final tab in AppTab.values) {
      await tapTab(tester, tab);
      expect(_visibleTitle(tester), tab.label);
    }

    // Distinct types, not four copies of the same screen. The stack keeps the
    // unselected three in the tree, so look past `offstage`.
    expect(find.byType(GardenScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(TimerScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(JournalScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(SettingsScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('has no tab left waiting for its own ticket', (tester) async {
    // Every tab was a `PlaceholderScreen` after ticket 01, and each ticket
    // since has replaced one: the timer in 02, settings in 03, the garden in
    // 07 and the journal in 15. There is nothing left for a placeholder to
    // stand in for, and `placeholder_screen.dart` went with the last of them.
    await pumpApp(tester);

    for (final tab in AppTab.values) {
      await tapTab(tester, tab);
      expect(
        find.textContaining('Arrives in ticket'),
        findsNothing,
        reason: '${tab.label} is still a placeholder.',
      );
    }
  });

  group('per-tab state', () {
    testWidgets('survives switching away and back', (tester) async {
      // A viewport short enough that the journal's page overflows it, so there
      // is a real scroll position to preserve.
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
        reason: 'Nothing to preserve if the screen cannot scroll — shrink the '
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
            'held — a running animation, a scroll position — was lost.',
      );
      // Still at the bottom of the page, where the user left it. Compared
      // against the extent as it stands now rather than as it stood before:
      // the position survived, and a scroll position is always clamped to the
      // content it belongs to.
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
