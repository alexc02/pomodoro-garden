import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_journal_repository.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/features/garden/decor_picker.dart';
import 'package:pip_garden/src/features/garden/garden_screen.dart';
import 'package:pip_garden/src/features/shelf/shelf_screen.dart';
import 'package:pip_garden/src/features/shelf/species_sheet.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/celebrations.dart';
import '../support/event_log.dart';
import '../support/garden_seed.dart';

// Shelf edge cases: screen-reader activation, an emptied garden, double
// taps, the largest text size, reset and a full garden.

GardenPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paint).painter! as GardenPainter;

final Finder _paint = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is GardenPainter,
  skipOffstage: false,
);

Future<void> _tapPlot(WidgetTester tester, GardenPlot plot) async {
  final origin = tester.getTopLeft(_paint);
  await tester.tapAt(origin + _painter(tester).projection.centreOf(plot));
  await settle(tester);
}

GardenPlot _plot(int index) => GardenPlots.inPlacementOrder[index];

void main() {
  late AppDatabase database;
  late DriftPlantRepository stored;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
    stored = DriftPlantRepository(database);
  });

  Future<void> shelveAll() async {
    for (final plant in await stored.plants()) {
      await stored.save(plant.inPlot(null));
    }
  }

  testWidgets('a screen reader can open a found spot', (tester) async {
    final handle = tester.ensureSemantics();
    await seedGarden(database, sessions: 3);
    await pumpApp(tester, database: database, surface: const Size(400, 900));
    await tapTab(tester, AppTab.shelf);
    final species = (await stored.plants()).first.species;

    final node = tester.getSemantics(find.byKey(ShelfKeys.spot(species)));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel(RegExp('^${species.label},')));
    await settle(tester);
    expect(find.byType(SpeciesSheet), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a screen reader can choose a shelved plant in the picker',
      (tester) async {
    final handle = tester.ensureSemantics();
    await seedGarden(database, sessions: 3);
    final first = (await stored.plants()).last;
    await stored.save(first.inPlot(null));
    await pumpApp(tester, database: database, surface: const Size(500, 900));
    await tester.tap(find.byKey(DecorKeys.arrange));
    await settle(tester);
    await _tapPlot(tester, _plot(7));

    final node =
        tester.getSemantics(find.byKey(DecorKeys.shelved(first.species)));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('a garden emptied onto the shelf does not ask for a first '
      'session', (tester) async {
    await seedGarden(database, sessions: 3);
    await shelveAll();
    await pumpApp(tester, database: database, surface: const Size(400, 800));

    expect(_painter(tester).layout.plants, isEmpty);
    expect(_painter(tester).layout.shelved, hasLength(3));
    expect(find.textContaining('first plant'), findsNothing);
    await tester.tap(find.byKey(GardenScreen.shelvedCaption));
    await settle(tester);
    expect(find.byType(ShelfScreen).hitTestable(), findsOneWidget);
  });

  testWidgets('a double tap on "Plant in garden" plants once',
      (tester) async {
    await seedGarden(database, sessions: 3);
    final plant = (await stored.plants()).first;
    await stored.save(plant.inPlot(null));
    await pumpApp(tester, database: database, surface: const Size(400, 900));
    await tapTab(tester, AppTab.shelf);
    final spot = find.byKey(ShelfKeys.spot(plant.species));
    await tester.ensureVisible(spot);
    await settle(tester);
    await tester.tap(spot);
    await settle(tester);

    final button = find.byKey(SpeciesSheet.plantOut(plant));
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await settle(tester);

    expect(
      await eventsNamed(database, AnalyticsEventName.plantReplanted),
      hasLength(1),
    );
  });

  for (final dark in [false, true]) {
    testWidgets('nothing overflows on a small phone at the largest text '
        '(dark: $dark)', (tester) async {
      if (dark) useDarkMode(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await seedGarden(database, sessions: 9);
      final plants = await stored.plants();
      for (final plant in plants.take(6)) {
        await stored.save(plant.inPlot(null));
      }
      await pumpApp(tester, database: database, surface: const Size(375, 667));

      expect(tester.takeException(), isNull, reason: 'garden at launch');

      // Shelf tab, top to bottom.
      await tapTab(tester, AppTab.shelf);
      expect(tester.takeException(), isNull, reason: 'shelf on arrival');
      final scroll = find.descendant(
        of: find.byType(ShelfScreen),
        matching: find.byType(Scrollable),
      );
      for (var n = 0; n < 12; n++) {
        await tester.drag(scroll, const Offset(0, -400));
        await settle(tester, over: const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull, reason: 'shelf, scrolled');

      // A species sheet with stored plants.
      final species = plants.first.species;
      final spot = find.byKey(ShelfKeys.spot(species));
      await tester.ensureVisible(spot);
      await settle(tester);
      await tester.tap(spot);
      await settle(tester);
      expect(find.byType(SpeciesSheet), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'species sheet');
      // The sheet can fill the screen at this text size, leaving no barrier
      // to tap; close it the way the back gesture does.
      Navigator.of(tester.element(find.byType(SpeciesSheet))).pop();
      await settle(tester);
      expect(find.byType(SpeciesSheet), findsNothing);

    });
  }

  testWidgets('the picker strip fits at the largest text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seedGarden(database, sessions: 9);
    for (final plant in (await stored.plants()).take(6)) {
      await stored.save(plant.inPlot(null));
    }
    await pumpApp(tester, database: database, surface: const Size(500, 900));
    await tester.tap(find.byKey(DecorKeys.arrange));
    await settle(tester);

    await _tapPlot(tester, _plot(7));

    expect(find.text('From your shelf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resetting the garden empties the shelf', (tester) async {
    await seedGarden(database, sessions: 3);
    await shelveAll();
    await pumpApp(tester, database: database, surface: const Size(400, 900));
    await tapTab(tester, AppTab.shelf);
    expect(find.text('3 plants on your shelf'), findsOneWidget);

    await tapTab(tester, AppTab.settings);
    await tester.tap(
      await scrollToSetting(tester, const Key('settings.resetGarden')),
    );
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    await tester.tap(find.text('Reset my garden'));
    await settle(tester);

    await tapTab(tester, AppTab.shelf);
    expect(find.text('Nothing found yet.'), findsOneWidget);
    expect(find.textContaining('on your shelf'), findsNothing);
  });

  testWidgets('shelving at a full garden makes room, and says so',
      (tester) async {
    await seedGarden(database, sessions: 202);
    await pumpApp(tester, database: database, surface: const Size(500, 900));
    await dismissCelebrations(tester);
    expect(find.byKey(GardenScreen.fullCaption), findsOneWidget);
    final before = _painter(tester).layout;
    expect(before.plants, hasLength(200));

    await tester.tap(find.byKey(DecorKeys.arrange));
    await settle(tester);
    // Front-most plot: nothing overlaps it.
    final front = before.plots.last;
    await _tapPlot(tester, front);
    await tester.tap(find.byKey(DecorKeys.shelve));
    await settle(tester);
    await tester.tap(find.byKey(DecorKeys.done));
    await settle(tester);

    final after = _painter(tester).layout;
    expect(after.plants, hasLength(199));
    expect(after.plotCount, 200);
    expect(after.emptyPlots, 1);
    expect(find.byKey(GardenScreen.fullCaption), findsNothing);

    // And a stored plant can now come back.
    final waiting = after.shelved.first;
    await tapTab(tester, AppTab.shelf);
    final spot = find.byKey(ShelfKeys.spot(waiting.species));
    await tester.ensureVisible(spot);
    await settle(tester);
    await tester.tap(spot);
    await settle(tester);
    final first = tester
        .widgetList<TextButton>(find.descendant(
          of: find.byType(SpeciesSheet),
          matching: find.byType(TextButton),
        ))
        .first;
    expect(first.onPressed, isNotNull);
  });

  testWidgets('the full-garden caption steps aside while arranging',
      (tester) async {
    await seedGarden(database, sessions: 202);
    await pumpApp(tester, database: database, surface: const Size(500, 900));
    await dismissCelebrations(tester);
    expect(find.byKey(GardenScreen.fullCaption), findsOneWidget);

    await tester.tap(find.byKey(DecorKeys.arrange));
    await settle(tester);
    expect(find.byKey(GardenScreen.fullCaption), findsNothing);

    await tester.tap(find.byKey(DecorKeys.done));
    await settle(tester);
    expect(find.byKey(GardenScreen.fullCaption), findsOneWidget);
  });

  testWidgets('shelf names keep to whole words at the largest text',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seedGarden(database, sessions: 9);
    await pumpApp(tester, database: database, surface: const Size(402, 874));
    await tapTab(tester, AppTab.shelf);

    // One spot per line: each gets the card's full width.
    final row = find.byKey(ShelfKeys.row(PlantType.wildflower));
    final spots = [
      for (final species in PlantSpecies.of(PlantType.wildflower))
        tester.getRect(
          find.byKey(ShelfKeys.spot(species), skipOffstage: false),
        ),
    ];
    expect(spots.map((spot) => spot.left).toSet(), hasLength(1));
    expect(spots.first.width, greaterThan(tester.getSize(row).width * 0.7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the arrange bar fits the smallest phone at the largest text',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seedGarden(database, sessions: 3);
    await pumpApp(tester, database: database, surface: const Size(320, 568));

    await tester.tap(find.byKey(DecorKeys.arrange));
    await settle(tester);

    expect(find.byKey(DecorKeys.done), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the journal counts the same plots the garden draws',
      (tester) async {
    await seedGarden(database, sessions: 40);
    final plants = await stored.plants();
    for (final plant in plants.take(15)) {
      await stored.save(plant.inPlot(null));
    }
    await pumpApp(tester, database: database, surface: const Size(400, 900));
    await dismissCelebrations(tester);

    final layout = _painter(tester).layout;
    final journal = await DriftJournalRepository(database).plantsEver();
    final lifetime = JournalLifetime.of(
      sessions: const SessionTally(sessions: 40, focus: Duration.zero),
      plants: journal,
    );
    expect(lifetime.plots, layout.plotCount);
  });
}
