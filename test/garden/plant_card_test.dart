import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_plant_repository.dart';
import 'package:pomodoro_garden/src/design/typography.dart';
import 'package:pomodoro_garden/src/features/garden/garden_view.dart';
import 'package:pomodoro_garden/src/features/garden/plant_card.dart';
import 'package:pomodoro_garden/src/garden/garden_painter.dart';

import '../support/app_harness.dart';

/// REQ-020's card, through the real app: a plant is tapped and it says what it
/// is, when it was grown and how long the session was.
///
/// The arithmetic of *which* plant a tap lands on is
/// `garden_hit_test_test.dart`, which can put a point exactly where it means
/// to. What is under test here is the half that only a running app can show:
/// that a finger on the screen reaches that arithmetic at all, that the card
/// says the right things, and that all three of the ticket's dismissals work.

/// A plant standing in [plot], with everything about it pinned down.
///
/// [plantedAt] is a local `DateTime` on purpose: the repository stores it as
/// UTC and the card reads it back in local time, so a plant seeded this way
/// shows the same date whatever time zone the suite is run in.
Plant _plant({
  required String id,
  required PlantType type,
  required GardenPlot plot,
  DateTime? plantedAt,
  Duration duration = const Duration(minutes: 25),
}) =>
    Plant(
      id: id,
      sessionId: 'session-$id',
      type: type,
      species: PlantSpecies.chosenFor(type: type, seed: 'session-$id'),
      stage: GrowthStage.mature,
      plantedAt: plantedAt ?? DateTime(2026, 3, 14, 15, 30),
      sessionDuration: duration,
      plot: plot,
    );

/// The painter currently on the garden tab — the layout and the camera.
GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is GardenPainter,
        skipOffstage: false,
      ),
    )
    .painter! as GardenPainter;

/// Where [plot] is on the screen, in the coordinates a tap is made in.
Offset _screenPosition(WidgetTester tester, GardenPlot plot) =>
    tester.getTopLeft(find.byType(GardenView)) +
    _painter(tester).projection.centreOf(plot);

/// Opens the app on a garden holding exactly [plants].
Future<void> _openGarden(WidgetTester tester, List<Plant> plants) async {
  final database = AppDatabase.forTesting();
  addTearDown(database.close);

  final garden = DriftPlantRepository(database);
  for (final plant in plants) {
    await garden.save(plant);
  }

  await pumpApp(tester, database: database, surface: const Size(400, 800));
}

/// Taps the middle of [plot]'s tile, the way a user's finger does.
Future<void> _tapPlot(WidgetTester tester, GardenPlot plot) async {
  await tester.tapAt(_screenPosition(tester, plot));
  await settle(tester);
}

/// The plot at the middle of the garden — the first one anything is planted in.
final GardenPlot _middle = GardenPlots.inPlacementOrder.first;

void main() {
  group('opening a plant', () {
    testWidgets('a tap on a plant raises its card', (tester) async {
      await _openGarden(tester, [
        _plant(id: 'a', type: PlantType.flower, plot: _middle),
      ]);
      expect(find.byType(PlantCard), findsNothing);

      await _tapPlot(tester, _middle);

      expect(find.byType(PlantCard), findsOneWidget);
    });

    testWidgets('and the card says what it is, when, and for how long',
        (tester) async {
      // REQ-020's four facts, on a plant whose every field is pinned down.
      final plant = _plant(
        id: 'a',
        type: PlantType.flower,
        plot: _middle,
        plantedAt: DateTime(2026, 3, 14, 15, 30),
        duration: const Duration(minutes: 25),
      );
      await _openGarden(tester, [plant]);

      await _tapPlot(tester, _middle);

      expect(find.text(plant.species.label), findsOneWidget);
      expect(find.text('Flower'), findsOneWidget);
      expect(find.text('14 March 2026'), findsOneWidget);
      expect(find.text('25 minutes'), findsOneWidget);
      expect(find.text('Mature'), findsOneWidget);
    });

    testWidgets('a long session reads in hours as well as minutes',
        (tester) async {
      await _openGarden(tester, [
        _plant(
          id: 'a',
          type: PlantType.largeTree,
          plot: _middle,
          duration: const Duration(minutes: 90),
        ),
      ]);

      await _tapPlot(tester, _middle);

      expect(find.text('1 hour 30 minutes'), findsOneWidget);
    });

    testWidgets('and a round two hours does not say "0 minutes"',
        (tester) async {
      await _openGarden(tester, [
        _plant(
          id: 'a',
          type: PlantType.largeTree,
          plot: _middle,
          duration: const Duration(hours: 2),
        ),
      ]);

      await _tapPlot(tester, _middle);

      expect(find.text('2 hours'), findsOneWidget);
    });

    testWidgets('the species is lettered in the display face, in italic',
        (tester) async {
      // §5.1: the label on the stake in the soil. Italic is what tells a plant
      // name from a heading set in the same face.
      final plant = _plant(id: 'a', type: PlantType.herb, plot: _middle);
      await _openGarden(tester, [plant]);

      await _tapPlot(tester, _middle);

      final style = tester.widget<Text>(find.text(plant.species.label)).style;
      expect(style?.fontFamily, GardenTypography.displayFontFamily);
      expect(style?.fontStyle, FontStyle.italic);
    });
  });

  group('the line about growth', () {
    testWidgets('is one of the bundled ones', (tester) async {
      await _openGarden(tester, [
        _plant(id: 'a', type: PlantType.bush, plot: _middle),
      ]);

      await _tapPlot(tester, _middle);

      expect(
        PlantQuotes.all.where((quote) => find.text(quote).evaluate().isNotEmpty),
        hasLength(1),
      );
    });

    testWidgets('and is the same line every time the plant is opened',
        (tester) async {
      // The requirement with teeth: a card that reshuffled would read as
      // generated rather than as something the plant has always said.
      await _openGarden(tester, [
        _plant(id: 'a', type: PlantType.bush, plot: _middle),
      ]);

      await _tapPlot(tester, _middle);
      final first = PlantQuotes.all
          .firstWhere((quote) => find.text(quote).evaluate().isNotEmpty);

      for (var again = 0; again < 3; again++) {
        await tester.binding.handlePopRoute();
        await settle(tester);
        await _tapPlot(tester, _middle);

        expect(find.text(first), findsOneWidget);
      }
    });

    testWidgets('and two plants do not have to say the same thing',
        (tester) async {
      // Not a promise that any two differ — the set is finite — but the garden
      // as a whole has more than one thing to say.
      final plots = GardenPlots.inPlacementOrder;
      await _openGarden(tester, [
        for (var n = 0; n < 8; n++)
          _plant(id: 'plant-$n', type: PlantType.herb, plot: plots[n]),
      ]);

      final said = <String>{};
      for (var n = 0; n < 8; n++) {
        await _tapPlot(tester, plots[n]);
        said.add(
          PlantQuotes.all
              .firstWhere((quote) => find.text(quote).evaluate().isNotEmpty),
        );
        await tester.binding.handlePopRoute();
        await settle(tester);
      }

      expect(said.length, greaterThan(1));
    });
  });

  group('a tap that is not on a plant', () {
    testWidgets('on bare soil does nothing', (tester) async {
      await _openGarden(tester, [
        _plant(id: 'a', type: PlantType.wildflower, plot: _middle),
      ]);

      final layout = _painter(tester).layout;
      final bare = layout.plots.firstWhere(
        (plot) => layout.plantIn(plot) == null && plot.x.abs() > 1,
      );
      await _tapPlot(tester, bare);

      expect(find.byType(PlantCard), findsNothing);
    });

    testWidgets('on a plot the garden has not unlocked does nothing',
        (tester) async {
      await _openGarden(tester, [
        _plant(id: 'a', type: PlantType.wildflower, plot: _middle),
      ]);

      final layout = _painter(tester).layout;
      final locked = GardenPlots.inPlacementOrder
          .firstWhere((plot) => !layout.plots.contains(plot));
      final point = _screenPosition(tester, locked);
      // The tap has to land on the garden for the test to mean anything.
      expect(
        tester.getRect(find.byType(GardenView)).contains(point),
        isTrue,
        reason: '$locked is off screen; this test tapped nothing at all',
      );

      await tester.tapAt(point);
      await settle(tester);

      expect(find.byType(PlantCard), findsNothing);
    });
  });

  group('dismissing the card', () {
    /// Opens one plant's card, ready to be got rid of.
    Future<void> openCard(WidgetTester tester) async {
      await _openGarden(tester, [
        _plant(id: 'a', type: PlantType.flower, plot: _middle),
      ]);
      await _tapPlot(tester, _middle);
      expect(find.byType(PlantCard), findsOneWidget);
    }

    testWidgets('a swipe down puts it away', (tester) async {
      await openCard(tester);

      await tester.fling(find.byType(PlantCard), const Offset(0, 400), 1000);
      await settle(tester);

      expect(find.byType(PlantCard), findsNothing);
    });

    testWidgets('a tap on the garden behind it puts it away', (tester) async {
      await openCard(tester);

      // The scrim over the garden: everything above the sheet.
      await tester.tapAt(const Offset(200, 40));
      await settle(tester);

      expect(find.byType(PlantCard), findsNothing);
    });

    testWidgets('and so does the platform back gesture', (tester) async {
      await openCard(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.byType(PlantCard), findsNothing);
    });

    testWidgets('the garden is where it was left afterwards', (tester) async {
      // Opening a plant is not a navigation: the user comes back to the same
      // corner of the garden they were looking at.
      await openCard(tester);
      final camera = _painter(tester).projection;

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(_painter(tester).projection, camera);
    });
  });

  group('at every zoom', () {
    testWidgets('a plant opens when the garden has been pinched into',
        (tester) async {
      await _openGarden(tester, [
        for (var n = 0; n < 12; n++)
          _plant(
            id: 'plant-$n',
            type: PlantType.values[n % PlantType.values.length],
            plot: GardenPlots.inPlacementOrder[n],
          ),
      ]);

      // Zoom all the way in, so the camera bears no resemblance to the one the
      // garden opened with.
      final view = tester.getCenter(find.byType(GardenView));
      final first = await tester.startGesture(view - const Offset(30, 0));
      final second = await tester.startGesture(view + const Offset(30, 0));
      for (var step = 0; step < 12; step++) {
        await first.moveBy(const Offset(-20, 0));
        await second.moveBy(const Offset(20, 0));
        await tester.pump();
      }
      await first.up();
      await second.up();
      await settle(tester);

      final camera = _painter(tester).projection;
      expect(camera.scale, greaterThan(1));

      // Whichever plant is now under the middle of the screen.
      final layout = _painter(tester).layout;
      final under = layout.plots.reversed.firstWhere(
        (plot) =>
            layout.plantIn(plot) != null &&
            tester
                .getRect(find.byType(GardenView))
                .contains(_screenPosition(tester, plot)),
      );

      await _tapPlot(tester, under);

      expect(find.byType(PlantCard), findsOneWidget);
    });

    testWidgets('and when it has been zoomed all the way out', (tester) async {
      // A full garden fitted to a phone screen is the smallest a plant is ever
      // drawn; a hit-test that worked only at 1:1 would fail here.
      await _openGarden(tester, [
        for (var n = 0; n < GardenPlots.maximum; n++)
          _plant(
            id: 'plant-$n',
            type: PlantType.values[n % PlantType.values.length],
            plot: GardenPlots.inPlacementOrder[n],
          ),
      ]);

      expect(_painter(tester).projection.scale, lessThan(1));
      await _tapPlot(tester, _middle);

      expect(find.byType(PlantCard), findsOneWidget);
    });
  });
}
