import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/features/shelf/shelf_screen.dart';
import 'package:pip_garden/src/features/shelf/species_sheet.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';

// The shelf tab through the real app: a spot per species in rows by type,
// what each spot gives away before and after its species is grown, and the
// sheet behind a found one. The counting itself is in the domain's
// shelf_test.dart.

var _next = 0;

/// A plant of [species], in the garden unless [shelved].
Plant _plant(
  PlantSpecies species, {
  bool shelved = false,
  DateTime? plantedAt,
  Duration duration = const Duration(minutes: 25),
}) {
  final n = _next++;
  return Plant(
    id: 'plant-$n',
    sessionId: 'session-$n',
    type: species.type,
    species: species,
    stage: GrowthStage.mature,
    // Local on purpose, like plant_card_test: shown in local time.
    plantedAt: plantedAt ?? DateTime(2026, 3, 14, 15, 30),
    sessionDuration: duration,
    plot: shelved ? null : GardenPlots.inPlacementOrder[n],
  );
}

/// Opens the app on the shelf tab with exactly [plants].
Future<void> _openShelf(WidgetTester tester, List<Plant> plants) async {
  _next = 0;
  final database = AppDatabase.forTesting();
  addTearDown(database.close);

  final garden = DriftPlantRepository(database);
  for (final plant in plants) {
    await garden.save(plant);
  }

  await pumpApp(tester, database: database, surface: const Size(400, 900));
  await tapTab(tester, AppTab.shelf);
}

Finder _in(Finder of, String text) =>
    find.descendant(of: of, matching: find.text(text), skipOffstage: false);

Finder _spot(PlantSpecies species) =>
    find.byKey(ShelfKeys.spot(species), skipOffstage: false);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settle(tester);
}

void main() {
  group('with nothing grown', () {
    testWidgets('still lays out every row and spot', (tester) async {
      await _openShelf(tester, const []);

      expect(find.text('Nothing found yet.'), findsOneWidget);
      for (final type in PlantType.values) {
        expect(
          find.byKey(ShelfKeys.row(type), skipOffstage: false),
          findsOneWidget,
        );
      }
      for (final species in PlantSpecies.values) {
        expect(_spot(species), findsOneWidget);
      }
    });

    testWidgets('names no species, only how to grow one', (tester) async {
      await _openShelf(tester, const []);

      for (final species in PlantSpecies.values) {
        expect(
          find.text(species.label, skipOffstage: false),
          findsNothing,
          reason: '${species.name} is a surprise until it is grown',
        );
      }
      expect(_in(_spot(PlantSpecies.poppy), 'Not yet grown'), findsOneWidget);
      expect(
        _in(find.byKey(ShelfKeys.row(PlantType.wildflower)), '0 of 9'),
        findsOneWidget,
      );
      // Where it fits beside the heading, the count sits at the card's far
      // edge. (A short heading: the test font is wider than the real one.)
      final herbs = find.byKey(ShelfKeys.row(PlantType.herb));
      expect(
        tester.getRect(_in(herbs, '0 of 7')).right,
        greaterThan(tester.getRect(herbs).right - 40),
      );
    });

    testWidgets('says which spots are seasonal or rare without naming them',
        (tester) async {
      await _openShelf(tester, const []);

      expect(_in(_spot(PlantSpecies.snowdrop), 'Winter only'), findsOneWidget);
      expect(_in(_spot(PlantSpecies.edelweiss), 'Rare'), findsOneWidget);
      expect(_in(_spot(PlantSpecies.poppy), 'Rare'), findsNothing);
      expect(
        tester.getSemantics(_spot(PlantSpecies.snowdrop)).label,
        'Not yet grown, winter only',
      );
      expect(find.text('Snowdrop', skipOffstage: false), findsNothing);
    });

    testWidgets('a spot not yet found opens nothing', (tester) async {
      await _openShelf(tester, const []);

      await tester.tap(_spot(PlantSpecies.poppy));
      await settle(tester);

      expect(find.byType(SpeciesSheet), findsNothing);
    });
  });

  group('row headings', () {
    test('say which sessions grow the row', () {
      expect(
        [for (final type in PlantType.values) ShelfScreen.rowRoute(type)],
        [
          '5 to 14 minute sessions',
          '15 to 24 minute sessions',
          '25 to 34 minute sessions',
          '35 to 49 minute sessions',
          '50 to 74 minute sessions',
          '75 minute sessions and longer',
          'Awarded for sessions completed',
        ],
      );
    });

    test('name every type', () {
      final headings = PlantType.values.map(ShelfScreen.rowHeading).toSet();
      expect(headings, hasLength(PlantType.values.length));
    });
  });

  group('a milestone spot', () {
    testWidgets('shows its threshold until it is awarded', (tester) async {
      await _openShelf(tester, const []);

      final spot = _spot(PlantSpecies.cherryBlossomGrove);
      await _scrollTo(tester, spot);

      expect(_in(spot, 'At 250 sessions'), findsOneWidget);
      expect(find.text('Cherry blossom grove'), findsNothing);
    });

    testWidgets('has its name and no marks once awarded', (tester) async {
      await _openShelf(tester, [
        Plant.forMilestone(
          Milestone.ten,
          id: 'bonus',
          plantedAt: DateTime(2026, 3, 14),
          plot: const GardenPlot(0, 0),
        ),
      ]);

      final spot = _spot(PlantSpecies.bonsai);
      await _scrollTo(tester, spot);

      expect(_in(spot, 'Bonsai tree'), findsOneWidget);
      expect(_in(spot, 'Awarded'), findsOneWidget);
      expect(
        find.descendant(of: spot, matching: find.byType(MasteryPips)),
        findsNothing,
      );
    });
  });

  group('a found species', () {
    testWidgets('shows its name, its count and its marks', (tester) async {
      await _openShelf(tester, [
        for (var n = 0; n < 6; n++) _plant(PlantSpecies.poppy),
      ]);

      final spot = _spot(PlantSpecies.poppy);
      expect(_in(spot, 'Poppy'), findsOneWidget);
      expect(_in(spot, '6 grown'), findsOneWidget);
      expect(
        tester
            .widget<MasteryPips>(
              find.descendant(of: spot, matching: find.byType(MasteryPips)),
            )
            .earned,
        2,
      );
      expect(find.text('One of fifty-two found.'), findsOneWidget);
      expect(
        _in(find.byKey(ShelfKeys.row(PlantType.wildflower)), '1 of 9'),
        findsOneWidget,
      );
    });

    testWidgets('counts plants in the garden, with none stored',
        (tester) async {
      await _openShelf(tester, [_plant(PlantSpecies.poppy)]);

      expect(_in(_spot(PlantSpecies.poppy), '1 grown'), findsOneWidget);
      expect(find.textContaining('on your shelf'), findsNothing);
      expect(
        tester.getSemantics(_spot(PlantSpecies.poppy)).label,
        'Poppy, 1 grown, 1 of 4 marks, none on your shelf',
      );
    });

    testWidgets('says how many are stored on it', (tester) async {
      await _openShelf(tester, [
        _plant(PlantSpecies.poppy),
        _plant(PlantSpecies.poppy, shelved: true),
        _plant(PlantSpecies.poppy, shelved: true),
        _plant(PlantSpecies.poppy, shelved: true),
      ]);

      expect(_in(_spot(PlantSpecies.poppy), '×3'), findsOneWidget);
      expect(_in(_spot(PlantSpecies.poppy), '4 grown'), findsOneWidget);
      expect(find.text('3 plants on your shelf'), findsOneWidget);
    });
  });

  group('the species sheet', () {
    testWidgets('lists each stored plant by day and session', (tester) async {
      await _openShelf(tester, [
        _plant(PlantSpecies.oak),
        _plant(
          PlantSpecies.oak,
          shelved: true,
          plantedAt: DateTime(2026, 3, 3, 9),
          duration: const Duration(minutes: 90),
        ),
        _plant(
          PlantSpecies.oak,
          shelved: true,
          plantedAt: DateTime(2026, 5, 20, 9),
          duration: const Duration(minutes: 75),
        ),
      ]);

      final spot = _spot(PlantSpecies.oak);
      await _scrollTo(tester, spot);
      await tester.tap(spot);
      await settle(tester);

      final sheet = find.byType(SpeciesSheet);
      expect(_in(sheet, 'Oak'), findsOneWidget);
      expect(_in(sheet, 'Large tree'), findsOneWidget);
      expect(_in(sheet, '3 grown · next mark at 5'), findsOneWidget);
      expect(_in(sheet, '1 hour 30 minutes'), findsOneWidget);
      expect(_in(sheet, '1 hour 15 minutes'), findsOneWidget);

      // Newest first.
      expect(
        tester.getTopLeft(_in(sheet, '20 May 2026')).dy,
        lessThan(tester.getTopLeft(_in(sheet, '3 March 2026')).dy),
      );
    });

    testWidgets('says so when every one of them is planted', (tester) async {
      await _openShelf(tester, [
        _plant(PlantSpecies.tulip),
        _plant(PlantSpecies.tulip),
      ]);

      final spot = _spot(PlantSpecies.tulip);
      await _scrollTo(tester, spot);
      await tester.tap(spot);
      await settle(tester);

      expect(find.text('All 2 are in your garden.'), findsOneWidget);
    });

    test('runs out of marks to promise after the hundredth', () {
      final spot = Shelf.of([
        for (var n = 0; n < 100; n++) _plant(PlantSpecies.mint, shelved: true),
      ]).spotFor(PlantSpecies.mint);

      expect(SpeciesSheet.progress(spot), '100 grown · every mark earned');
    });
  });

  testWidgets('a session finished on the timer shows up here', (tester) async {
    final clock = FixedClock(testInstant);
    await pumpApp(tester, clock: clock, surface: const Size(400, 900));
    await tapTab(tester, AppTab.shelf);
    expect(find.text('Nothing found yet.'), findsOneWidget);

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);
    await tapTab(tester, AppTab.shelf);

    expect(find.text('One of fifty-two found.'), findsOneWidget);
  });

  testWidgets('keeps its place while a session finishes on another tab',
      (tester) async {
    // It used to jump back to the top: the plants reloading showed the
    // blank loading page for a frame, which threw away the scroll position.
    final clock = FixedClock(testInstant);
    await pumpApp(tester, clock: clock, surface: const Size(400, 900));
    await tapTab(tester, AppTab.shelf);

    final scrollable = find
        .descendant(
          of: find.byType(ShelfScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scrollable, const Offset(0, -1500));
    await settle(tester);
    final scrolled = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(scrolled, greaterThan(0));

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);
    await tapTab(tester, AppTab.shelf);

    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      scrolled,
    );
  });
}
