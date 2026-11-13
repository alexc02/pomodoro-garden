import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/features/garden/decor_picker.dart';
import 'package:pip_garden/src/features/shelf/shelf_screen.dart';
import 'package:pip_garden/src/features/shelf/species_sheet.dart';
import 'package:pip_garden/src/features/timer/timer_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/garden_seed.dart';

// Every tab, the arrange bar, a species sheet and a running session, on each
// screen size the app runs on, at every system text size up to the largest
// accessibility one. Nothing may overflow or throw. `Headline` keeps the
// headings in shape; this checks everything around them.

const _screens = {
  'small Android phone': Size(320, 568),
  'iPhone SE': Size(375, 667),
  'iPhone': Size(402, 874),
  'iPad': Size(1032, 1376),
};

const _textSizes = [1.0, 1.35, 2.0, 3.1];

void main() {
  for (final MapEntry(key: name, value: screen) in _screens.entries) {
    for (final text in _textSizes) {
      for (final dark in [false, true]) {
        testWidgets(
            '$name, text at ${text}x, ${dark ? 'dark' : 'light'}',
            (tester) async {
          if (dark) useDarkMode(tester);
          tester.platformDispatcher.textScaleFactorTestValue = text;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          // Before anything is grown: the empty states are the wordiest.
          final empty = AppDatabase.forTesting();
          addTearDown(empty.close);
          await pumpApp(tester, database: empty, surface: screen);
          for (final tab in AppTab.values) {
            await tapTab(tester, tab);
            expect(
              tester.takeException(),
              isNull,
              reason: '${tab.name} tab, nothing grown',
            );
          }
          await killApp(tester);

          final database = AppDatabase.forTesting();
          addTearDown(database.close);
          await seedGarden(database, sessions: 9);
          final stored = DriftPlantRepository(database);
          final plants = await stored.plants();
          for (final plant in plants.take(4)) {
            await stored.save(plant.inPlot(null));
          }

          await pumpApp(tester, database: database, surface: screen);
          expect(tester.takeException(), isNull, reason: 'garden');

          for (final tab in AppTab.values) {
            await tapTab(tester, tab);
            expect(tester.takeException(), isNull, reason: '${tab.name} tab');

            // To the bottom of anything that scrolls, and back.
            final scrolls = find.byType(Scrollable).hitTestable();
            if (tab != AppTab.garden && tester.any(scrolls)) {
              for (var n = 0; n < 6; n++) {
                await tester.drag(scrolls.first, const Offset(0, -500));
                await settle(tester, over: const Duration(milliseconds: 120));
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '${tab.name} tab, scrolled',
                );
              }
              await tester.drag(scrolls.first, const Offset(0, 6000));
              await settle(tester, over: const Duration(milliseconds: 120));
            }
          }

          // A species sheet with stored plants in it.
          await tapTab(tester, AppTab.shelf);
          final spot = find.byKey(ShelfKeys.spot(plants.first.species));
          await tester.ensureVisible(spot);
          await settle(tester);
          await tester.tap(spot, warnIfMissed: false);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: 'species sheet');
          if (tester.any(find.byType(SpeciesSheet))) {
            Navigator.of(tester.element(find.byType(SpeciesSheet))).pop();
            await settle(tester);
          }

          // The arrange bar.
          await tapTab(tester, AppTab.garden);
          await tester.tap(find.byKey(DecorKeys.arrange));
          await settle(tester);
          expect(tester.takeException(), isNull, reason: 'arrange bar');
          await tester.tap(find.byKey(DecorKeys.done));
          await settle(tester);

          // A session under way: the timer's heading, times and controls,
          // then the garden's timer bar.
          await tapTab(tester, AppTab.timer);
          // Can be below the fold at large text; the screen scrolls to it.
          final start = find.descendant(
            of: find.byType(TimerScreen),
            matching: find.text('Plant it'),
          );
          await tester.ensureVisible(start);
          await settle(tester);
          expect(start.hitTestable(), findsOneWidget, reason: 'start button');
          await tester.tap(start);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: 'timer, running');
          await tapTab(tester, AppTab.garden);
          expect(tester.takeException(), isNull, reason: 'garden, running');
        });
      }
    }
  }
}
