import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/features/garden/decor_picker.dart';
import 'package:pip_garden/src/features/garden/plant_card.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/announcement_fakes.dart';
import '../support/app_harness.dart';
import '../support/garden_seed.dart';

// Moving and swapping through the real app: plants as well as decor, by the
// same pick-up-then-tap as `decor_arranging_test.dart`.

GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(_paint)
    .painter! as GardenPainter;

final Finder _paint = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is GardenPainter,
  skipOffstage: false,
);

/// Taps the centre of [plot]'s tile for the current camera.
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

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  // Three sessions: plants in plots 0 to 2 of twelve, the rest empty.
  Future<void> openArranging(
    WidgetTester tester, {
    FakeHaptics? haptics,
    GardenSettings? settings,
  }) async {
    await seedGarden(database, sessions: 3);
    await pumpApp(
      tester,
      database: database,
      surface: const Size(500, 900),
      haptics: haptics,
      settings: settings,
    );
    await tapTab(tester, AppTab.garden);
    await tester.tap(find.byKey(DecorKeys.arrange));
    await settle(tester);
  }

  Future<void> place(
    WidgetTester tester,
    DecorKind kind,
    GardenPlot plot,
  ) async {
    await _tapPlot(tester, plot);
    await tester.tap(find.byKey(DecorKeys.kind(kind)));
    await settle(tester);
  }

  Future<Map<String, GardenPlot?>> storedPlants() async => {
        for (final plant in await DriftPlantRepository(database).plants())
          plant.id: plant.plot,
      };

  group('picking up a plant', () {
    testWidgets('says which plant is in hand', (tester) async {
      await openArranging(tester);
      expect(_guidance(tester), ArrangeBar.choosingGuidance);

      final plant = _painter(tester).layout.plantIn(_plot(0))!;
      await _tapPlot(tester, _plot(0));

      expect(
        _guidance(tester),
        ArrangeBar.holdingGuidance(plant.species.label.toLowerCase()),
      );
      expect(find.byType(PlantMark), findsOneWidget);
      expect(find.byType(PlantCard), findsNothing);
    });

    testWidgets('can be left but not removed', (tester) async {
      await openArranging(tester);
      await _tapPlot(tester, _plot(0));

      expect(find.byKey(DecorKeys.remove), findsNothing);

      await tester.tap(find.byKey(DecorKeys.putDown));
      await settle(tester);

      expect(_guidance(tester), ArrangeBar.choosingGuidance);
      expect(await storedPlants(), containsPair('seeded-plant-0', _plot(0)));
    });

    testWidgets('marks its plot in the garden until put down', (tester) async {
      await openArranging(tester);
      expect(_painter(tester).held, isNull);

      await _tapPlot(tester, _plot(0));
      expect(_painter(tester).held, _plot(0));

      // Tapping it again puts it down where it was.
      await _tapPlot(tester, _plot(0));
      expect(_painter(tester).held, isNull);
      expect(await storedPlants(), containsPair('seeded-plant-0', _plot(0)));
    });

    testWidgets('held decor is marked too', (tester) async {
      await openArranging(tester);
      await place(tester, DecorKind.bench, _plot(5));

      await _tapPlot(tester, _plot(5));

      expect(_painter(tester).held, _plot(5));
    });
  });

  group('moving', () {
    testWidgets('a plant to an empty plot', (tester) async {
      await openArranging(tester);
      final plant = _painter(tester).layout.plantIn(_plot(0))!;

      await _tapPlot(tester, _plot(0));
      await _tapPlot(tester, _plot(7));

      final layout = _painter(tester).layout;
      // The same plant, with only its plot changed.
      expect(layout.plantIn(_plot(7)), plant.inPlot(_plot(7)));
      expect(layout.plantIn(_plot(0)), isNull);
      expect(layout.plants, hasLength(3));
      expect(await storedPlants(), containsPair(plant.id, _plot(7)));
    });

    testWidgets('leaves nothing in hand, still arranging', (tester) async {
      await openArranging(tester);

      await _tapPlot(tester, _plot(0));
      await _tapPlot(tester, _plot(7));

      expect(_painter(tester).held, isNull);
      expect(_guidance(tester), ArrangeBar.choosingGuidance);
    });

    testWidgets('survives a relaunch', (tester) async {
      await openArranging(tester);
      await _tapPlot(tester, _plot(0));
      await _tapPlot(tester, _plot(7));

      await pumpApp(tester, database: database, surface: const Size(500, 900));
      await tapTab(tester, AppTab.garden);

      expect(_painter(tester).layout.plantIn(_plot(7))?.id, 'seeded-plant-0');
    });

    testWidgets('the vacated plot takes decor', (tester) async {
      await openArranging(tester);
      await _tapPlot(tester, _plot(0));
      await _tapPlot(tester, _plot(7));

      await place(tester, DecorKind.lantern, _plot(0));

      expect(
        _painter(tester).layout.decorIn(_plot(0))?.kind,
        DecorKind.lantern,
      );
    });
  });

  group('swapping', () {
    testWidgets('two plants', (tester) async {
      await openArranging(tester);
      final first = _painter(tester).layout.plantIn(_plot(0))!;
      final second = _painter(tester).layout.plantIn(_plot(1))!;

      await _tapPlot(tester, _plot(0));
      await _tapPlot(tester, _plot(1));

      final layout = _painter(tester).layout;
      expect(layout.plantIn(_plot(1))?.id, first.id);
      expect(layout.plantIn(_plot(0))?.id, second.id);
      expect(
        await storedPlants(),
        allOf(
          containsPair(first.id, _plot(1)),
          containsPair(second.id, _plot(0)),
        ),
      );
    });

    testWidgets('a plant with decor', (tester) async {
      await openArranging(tester);
      await place(tester, DecorKind.bench, _plot(5));
      final bench = _painter(tester).layout.decor.single;

      await _tapPlot(tester, _plot(0));
      await _tapPlot(tester, _plot(5));

      final layout = _painter(tester).layout;
      expect(layout.plantIn(_plot(5))?.id, 'seeded-plant-0');
      expect(layout.decorIn(_plot(0)), bench.movedTo(_plot(0)));
    });

    testWidgets('decor with a plant', (tester) async {
      await openArranging(tester);
      await place(tester, DecorKind.bench, _plot(5));

      await _tapPlot(tester, _plot(5));
      await _tapPlot(tester, _plot(0));

      final layout = _painter(tester).layout;
      expect(layout.plantIn(_plot(5))?.id, 'seeded-plant-0');
      expect(layout.decorIn(_plot(0))?.kind, DecorKind.bench);
    });

    testWidgets('decor with decor', (tester) async {
      await openArranging(tester);
      await place(tester, DecorKind.bench, _plot(5));
      await place(tester, DecorKind.pond, _plot(7));
      final bench = _painter(tester).layout.decorIn(_plot(5))!;
      final pond = _painter(tester).layout.decorIn(_plot(7))!;

      await _tapPlot(tester, _plot(5));
      await _tapPlot(tester, _plot(7));

      final layout = _painter(tester).layout;
      expect(layout.decorIn(_plot(7)), bench.movedTo(_plot(7)));
      expect(layout.decorIn(_plot(5)), pond.movedTo(_plot(5)));
      // Swapped, not switched: nothing is left in hand.
      expect(_painter(tester).held, isNull);
      expect(
        await DriftDecorRepository(database).decor(),
        unorderedEquals([bench.movedTo(_plot(7)), pond.movedTo(_plot(5))]),
      );
    });
  });

  group('haptic', () {
    testWidgets('one tick per move, none for picking up', (tester) async {
      final haptics = FakeHaptics();
      await openArranging(tester, haptics: haptics);

      await _tapPlot(tester, _plot(0));
      expect(haptics.arrangings, 0);

      await _tapPlot(tester, _plot(7));
      expect(haptics.arrangings, 1);

      await _tapPlot(tester, _plot(1));
      await _tapPlot(tester, _plot(2));
      expect(haptics.arrangings, 2);
    });

    testWidgets('none for putting down in place', (tester) async {
      final haptics = FakeHaptics();
      await openArranging(tester, haptics: haptics);

      await _tapPlot(tester, _plot(0));
      await _tapPlot(tester, _plot(0));

      expect(haptics.arrangings, 0);
    });

    testWidgets('none with haptics switched off', (tester) async {
      final haptics = FakeHaptics();
      await openArranging(
        tester,
        haptics: haptics,
        settings: GardenSettings.defaults.withHaptics(enabled: false),
      );

      await _tapPlot(tester, _plot(0));
      await _tapPlot(tester, _plot(7));

      expect(_painter(tester).layout.plantIn(_plot(7)), isNotNull);
      expect(haptics.arrangings, 0);
    });
  });

  testWidgets('outside arranging a plant still opens its card',
      (tester) async {
    await seedGarden(database, sessions: 3);
    await pumpApp(tester, database: database, surface: const Size(500, 900));
    await tapTab(tester, AppTab.garden);

    await _tapPlot(tester, _plot(0));

    expect(find.byType(PlantCard), findsOneWidget);
    expect(_painter(tester).held, isNull);
  });
}
