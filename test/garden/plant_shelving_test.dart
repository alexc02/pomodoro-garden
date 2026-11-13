import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/features/garden/decor_picker.dart';
import 'package:pip_garden/src/features/shelf/shelf_screen.dart';
import 'package:pip_garden/src/features/shelf/species_sheet.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/announcement_fakes.dart';
import '../support/app_harness.dart';
import '../support/celebrations.dart';
import '../support/event_log.dart';
import '../support/garden_seed.dart';

// Plants between the garden and the shelf, through the real app: out by the
// arrange bar, back by the picker for a chosen plot or by the shelf's own
// button for the nearest free one.

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

String _guidance(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(DecorKeys.guidance)).data!;

void main() {
  late AppDatabase database;
  late DriftPlantRepository stored;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
    stored = DriftPlantRepository(database);
  });

  Future<Map<String, GardenPlot?>> plots() async =>
      {for (final plant in await stored.plants()) plant.id: plant.plot};

  Future<Plant> seeded(int n) async =>
      (await stored.plants()).singleWhere((p) => p.id == 'seeded-plant-$n');

  /// Three sessions: plants in plots 0 to 2 of twelve. [shelved] are taken
  /// out before launch.
  Future<void> open(
    WidgetTester tester, {
    List<int> shelved = const [],
    bool arranging = true,
    FakeHaptics? haptics,
    Clock? clock,
  }) async {
    await seedGarden(database, sessions: 3);
    for (final n in shelved) {
      await stored.save((await seeded(n)).inPlot(null));
    }
    await pumpApp(
      tester,
      database: database,
      surface: const Size(500, 900),
      haptics: haptics,
      clock: clock,
    );
    if (!arranging) return;
    await tester.tap(find.byKey(DecorKeys.arrange));
    await settle(tester);
  }

  Future<void> shelveFromGarden(WidgetTester tester, int plot) async {
    await _tapPlot(tester, _plot(plot));
    await tester.tap(find.byKey(DecorKeys.shelve));
    await settle(tester);
  }

  Future<void> openSheet(WidgetTester tester, PlantSpecies species) async {
    await tapTab(tester, AppTab.shelf);
    final spot = find.byKey(ShelfKeys.spot(species));
    await tester.ensureVisible(spot);
    await settle(tester);
    await tester.tap(spot);
    await settle(tester);
  }

  TextButton plantOutButton(WidgetTester tester, Plant plant) =>
      tester.widget<TextButton>(find.byKey(SpeciesSheet.plantOut(plant)));

  group('moving a plant to the shelf', () {
    testWidgets('is offered for a plant in hand', (tester) async {
      await open(tester);
      expect(find.byKey(DecorKeys.shelve), findsNothing);

      await _tapPlot(tester, _plot(0));

      expect(find.byKey(DecorKeys.shelve), findsOneWidget);
      expect(find.text('Move to shelf'), findsOneWidget);
    });

    testWidgets('is not offered for decor, which is removed instead',
        (tester) async {
      await open(tester);
      await _tapPlot(tester, _plot(7));
      await tester.tap(find.byKey(DecorKeys.kind(DecorKind.bench)));
      await settle(tester);

      await _tapPlot(tester, _plot(7));

      expect(find.byKey(DecorKeys.remove), findsOneWidget);
      expect(find.byKey(DecorKeys.shelve), findsNothing);
    });

    testWidgets('takes it out of its plot and keeps it', (tester) async {
      await open(tester);
      final before = await seeded(0);

      await shelveFromGarden(tester, 0);

      expect(await seeded(0), before.inPlot(null));
      expect(await plots(), {
        'seeded-plant-0': null,
        'seeded-plant-1': _plot(1),
        'seeded-plant-2': _plot(2),
      });
    });

    testWidgets('leaves its soil behind, empty', (tester) async {
      await open(tester);
      final plotsBefore = _painter(tester).layout.plotCount;

      await shelveFromGarden(tester, 0);

      final layout = _painter(tester).layout;
      expect(layout.plotCount, plotsBefore);
      expect(layout.isEmpty(_plot(0)), isTrue);
      expect(layout.shelved.single.id, 'seeded-plant-0');
    });

    testWidgets('leaves nothing in hand, still arranging', (tester) async {
      await open(tester);

      await shelveFromGarden(tester, 0);

      expect(_guidance(tester), ArrangeBar.choosingGuidance);
      expect(find.byKey(DecorKeys.done), findsOneWidget);
    });

    testWidgets('survives a relaunch', (tester) async {
      await open(tester);
      await shelveFromGarden(tester, 1);

      await killApp(tester);
      await pumpApp(tester, database: database, surface: const Size(500, 900));

      expect(_painter(tester).layout.shelved.single.id, 'seeded-plant-1');
      expect(_painter(tester).layout.plantIn(_plot(1)), isNull);
    });

    testWidgets('ticks once and is logged', (tester) async {
      final haptics = FakeHaptics();
      await open(tester, haptics: haptics);
      final species = (await seeded(0)).species;

      await shelveFromGarden(tester, 0);

      expect(haptics.arrangings, 1);
      final event = await theEventNamed(
        database,
        AnalyticsEventName.plantShelved,
      );
      expect(event.parameters, {'species': species.name});
    });

    testWidgets('raises no "garden is full" caption', (tester) async {
      await open(tester);
      await shelveFromGarden(tester, 0);
      await tester.tap(find.byKey(DecorKeys.done));
      await settle(tester);

      expect(find.textContaining('garden is full'), findsNothing);
    });

    testWidgets('shows up on the shelf tab', (tester) async {
      await open(tester);
      final species = (await seeded(0)).species;
      await shelveFromGarden(tester, 0);

      await tapTab(tester, AppTab.shelf);

      expect(find.text('1 plant on your shelf'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(ShelfKeys.spot(species))).label,
        contains('1 on your shelf'),
      );
    });

    testWidgets('lets the next session take the freed plot', (tester) async {
      final clock = FixedClock(testInstant);
      await open(tester, clock: clock);
      await shelveFromGarden(tester, 0);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      final grown = (await stored.plants())
          .singleWhere((plant) => !plant.id.startsWith('seeded'));
      expect(grown.plot, _plot(0));
      expect((await seeded(0)).plot, isNull, reason: 'still on the shelf');
    });
  });

  group('a milestone plant', () {
    testWidgets('can be shelved without being awarded again', (tester) async {
      await seedGarden(database, sessions: 10);
      // Already awarded, standing at the front where no other plant overlaps
      // it, so the tap can't land on a neighbour.
      final front = [for (var n = 10; n < 16; n++) _plot(n)]
          .reduce((a, b) => b.depth > a.depth ? b : a);
      await stored.save(Plant.forMilestone(
        Milestone.ten,
        id: 'bonsai',
        plantedAt: testInstant,
        plot: front,
      ));
      await pumpApp(tester, database: database, surface: const Size(500, 900));

      await tester.tap(find.byKey(DecorKeys.arrange));
      await settle(tester);
      await _tapPlot(tester, front);
      expect(_guidance(tester), contains('bonsai tree'));
      await tester.tap(find.byKey(DecorKeys.shelve));
      await settle(tester);

      await killApp(tester);
      await pumpApp(tester, database: database, surface: const Size(500, 900));
      await waitForCelebration(tester);

      final awards = (await stored.plants()).where((p) => p.isBonus);
      expect(awards.single.id, 'bonsai');
      expect(awards.single.plot, isNull);
      expect(await stored.awardedMilestones(), {Milestone.ten});
    });
  });

  group('the picker for an empty plot', () {
    testWidgets('offers only decor while the shelf is empty', (tester) async {
      await open(tester);

      await _tapPlot(tester, _plot(7));

      expect(find.byKey(DecorKeys.kind(DecorKind.bench)), findsOneWidget);
      expect(find.text('From your shelf'), findsNothing);
    });

    testWidgets('offers each stored species once, with its count',
        (tester) async {
      await open(tester, shelved: [0, 1]);
      final first = (await seeded(0)).species;
      final second = (await seeded(1)).species;

      await _tapPlot(tester, _plot(7));

      // Above the objects, so it's seen without scrolling.
      expect(find.text('From your shelf').hitTestable(), findsOneWidget);
      expect(find.byKey(DecorKeys.shelved(first)), findsOneWidget);
      expect(find.byKey(DecorKeys.shelved(second)), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(DecorKeys.shelved(first))).label,
        '${first.label}, 1 on your shelf',
      );
      expect(
        tester.getTopLeft(find.byKey(DecorKeys.shelved(first))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(DecorKeys.kind(DecorKind.bench))).dy,
        ),
      );
    });

    testWidgets('plants the one chosen in the plot tapped', (tester) async {
      final haptics = FakeHaptics();
      await open(tester, shelved: [0], haptics: haptics);
      final plant = await seeded(0);

      await _tapPlot(tester, _plot(7));
      await tester.tap(find.byKey(DecorKeys.shelved(plant.species)));
      await settle(tester);

      expect((await seeded(0)).plot, _plot(7));
      expect(_painter(tester).layout.plantIn(_plot(7))?.id, plant.id);
      expect(_painter(tester).layout.shelved, isEmpty);
      expect(_guidance(tester), ArrangeBar.choosingGuidance);
      expect(haptics.arrangings, 1);

      final event = await theEventNamed(
        database,
        AnalyticsEventName.plantReplanted,
      );
      expect(
        event.parameters,
        {'species': plant.species.name, 'picked_plot': true},
      );
    });

    testWidgets('dismissed, plants nothing', (tester) async {
      await open(tester, shelved: [0]);

      await _tapPlot(tester, _plot(7));
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);

      expect((await seeded(0)).plot, isNull);
    });
  });

  group('"Plant in garden" on the shelf', () {
    testWidgets('puts the plant in the nearest free plot', (tester) async {
      await open(tester, shelved: [1], arranging: false);
      final plant = await seeded(1);

      await openSheet(tester, plant.species);
      await tester.tap(find.byKey(SpeciesSheet.plantOut(plant)));
      await settle(tester);

      expect((await seeded(1)).plot, _plot(1));
      final event = await theEventNamed(
        database,
        AnalyticsEventName.plantReplanted,
      );
      expect(event.parameters['picked_plot'], isFalse);
    });

    testWidgets('takes the plant off the open sheet', (tester) async {
      await open(tester, shelved: [1], arranging: false);
      final plant = await seeded(1);

      await openSheet(tester, plant.species);
      await tester.tap(find.byKey(SpeciesSheet.plantOut(plant)));
      await settle(tester);

      expect(find.byKey(SpeciesSheet.plantOut(plant)), findsNothing);
      expect(find.text('It\'s in your garden.'), findsOneWidget);
    });

    testWidgets('goes round decor rather than displacing it', (tester) async {
      await seedGarden(database, sessions: 3);
      await stored.save((await seeded(0)).inPlot(null));
      // The freed plot now has a bench in it.
      await DriftDecorRepository(database).save(Decor(
        id: 'bench',
        kind: DecorKind.bench,
        plot: _plot(0),
        placedAt: testInstant,
      ));
      await pumpApp(tester, database: database, surface: const Size(500, 900));
      final plant = await seeded(0);

      await openSheet(tester, plant.species);
      await tester.tap(find.byKey(SpeciesSheet.plantOut(plant)));
      await settle(tester);

      expect((await seeded(0)).plot, _plot(3));
      expect(await DriftDecorRepository(database).occupiedPlots(), {_plot(0)});
    });

    testWidgets('waits for a running session to end', (tester) async {
      await open(tester, shelved: [1], arranging: false);
      final plant = await seeded(1);
      await startSession(tester);

      await openSheet(tester, plant.species);

      expect(plantOutButton(tester, plant).onPressed, isNull);
      expect(
        find.text('You can plant these once your session ends.'),
        findsOneWidget,
      );
    });

    testWidgets('waits for a paused session too', (tester) async {
      // Paused, the session still has its plant to place.
      await open(tester, shelved: [1], arranging: false);
      final plant = await seeded(1);
      await startSession(tester);
      await pauseSession(tester);

      await openSheet(tester, plant.species);

      expect(plantOutButton(tester, plant).onPressed, isNull);
      expect(
        find.text('You can plant these once your session ends.'),
        findsOneWidget,
      );
    });

    testWidgets('is held back when every plot is taken', (tester) async {
      await seedGarden(database, sessions: 202);
      await pumpApp(tester, database: database, surface: const Size(500, 900));
      await dismissCelebrations(tester);
      final plant =
          (await stored.plants()).firstWhere((plant) => plant.isShelved);

      await openSheet(tester, plant.species);

      expect(plantOutButton(tester, plant).onPressed, isNull);
      expect(find.textContaining('no free plot'), findsOneWidget);
    });
  });
}
