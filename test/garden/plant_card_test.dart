import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/design/typography.dart';
import 'package:pip_garden/src/features/garden/garden_view.dart';
import 'package:pip_garden/src/features/garden/plant_card.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';

import '../support/app_harness.dart';

// Plant card through the real app: tap a plant, see what it is, when it
// grew and for how long, and dismiss it three ways. Which plant a tap hits is
// in garden_hit_test_test.dart.

/// A plant in [plot] with every field fixed.
///
/// [plantedAt] is local on purpose: stored as UTC and shown in local time, so
/// the date is the same in any timezone.
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

GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is GardenPainter,
        skipOffstage: false,
      ),
    )
    .painter! as GardenPainter;

/// [plot]'s position in tap coordinates.
Offset _screenPosition(WidgetTester tester, GardenPlot plot) =>
    tester.getTopLeft(find.byType(GardenView)) +
    _painter(tester).projection.centreOf(plot);

/// Opens the app on a garden with exactly [plants].
Future<void> _openGarden(WidgetTester tester, List<Plant> plants) async {
  final database = AppDatabase.forTesting();
  addTearDown(database.close);

  final garden = DriftPlantRepository(database);
  for (final plant in plants) {
    await garden.save(plant);
  }

  await pumpApp(tester, database: database, surface: const Size(400, 800));
}

/// Taps the centre of [plot]'s tile.
Future<void> _tapPlot(WidgetTester tester, GardenPlot plot) async {
  await tester.tapAt(_screenPosition(tester, plot));
  await settle(tester);
}

/// The centre plot, first in placement order.
final GardenPlot _middle = GardenPlots.inPlacementOrder.first;

void main() {
  group('opening', () {
    testWidgets('tap opens the card', (tester) async {
      await _openGarden(tester, [
        _plant(id: 'a', type: PlantType.flower, plot: _middle),
      ]);
      expect(find.byType(PlantCard), findsNothing);

      await _tapPlot(tester, _middle);

      expect(find.byType(PlantCard), findsOneWidget);
    });

    testWidgets('card shows species, date and length', (tester) async {
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

    testWidgets('long session shows hours and minutes', (tester) async {
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

    testWidgets('exactly two hours omits minutes', (tester) async {
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

    testWidgets('species uses the display face, italic', (tester) async {
      // Italic tells a plant name apart from a heading in the same face.
      final plant = _plant(id: 'a', type: PlantType.herb, plot: _middle);
      await _openGarden(tester, [plant]);

      await _tapPlot(tester, _middle);

      final style = tester.widget<Text>(find.text(plant.species.label)).style;
      expect(style?.fontFamily, GardenTypography.displayFontFamily);
      expect(style?.fontStyle, FontStyle.italic);
    });
  });

  group('growth line', () {
    testWidgets('comes from the bundled set', (tester) async {
      await _openGarden(tester, [
        _plant(id: 'a', type: PlantType.bush, plot: _middle),
      ]);

      await _tapPlot(tester, _middle);

      expect(
        PlantQuotes.all.where((quote) => find.text(quote).evaluate().isNotEmpty),
        hasLength(1),
      );
    });

    testWidgets('is stable per plant', (tester) async {
      // A line that changed each time would read as generated.
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

    testWidgets('varies between plants', (tester) async {
      // The set is finite, so this only checks there's more than one line.
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

  group('missed taps', () {
    testWidgets('bare soil does nothing', (tester) async {
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

    testWidgets('locked plot does nothing', (tester) async {
      await _openGarden(tester, [
        _plant(id: 'a', type: PlantType.wildflower, plot: _middle),
      ]);

      final layout = _painter(tester).layout;
      final locked = GardenPlots.inPlacementOrder
          .firstWhere((plot) => !layout.plots.contains(plot));
      final point = _screenPosition(tester, locked);
      // Make sure the tap actually lands on the garden.
      expect(
        tester.getRect(find.byType(GardenView)).contains(point),
        isTrue,
        reason: '$locked is off screen',
      );

      await tester.tapAt(point);
      await settle(tester);

      expect(find.byType(PlantCard), findsNothing);
    });
  });

  group('dismissing', () {
    Future<void> openCard(WidgetTester tester) async {
      await _openGarden(tester, [
        _plant(id: 'a', type: PlantType.flower, plot: _middle),
      ]);
      await _tapPlot(tester, _middle);
      expect(find.byType(PlantCard), findsOneWidget);
    }

    testWidgets('swipe down', (tester) async {
      await openCard(tester);

      await tester.fling(find.byType(PlantCard), const Offset(0, 400), 1000);
      await settle(tester);

      expect(find.byType(PlantCard), findsNothing);
    });

    testWidgets('tap on the scrim', (tester) async {
      await openCard(tester);

      // The scrim above the sheet.
      await tester.tapAt(const Offset(200, 40));
      await settle(tester);

      expect(find.byType(PlantCard), findsNothing);
    });

    testWidgets('back gesture', (tester) async {
      await openCard(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.byType(PlantCard), findsNothing);
    });

    testWidgets('view is unchanged afterwards', (tester) async {
      // Opening a card isn't a navigation; the view stays put.
      await openCard(tester);
      final camera = _painter(tester).projection;

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(_painter(tester).projection, camera);
    });
  });

  group('at every zoom', () {
    testWidgets('opens when zoomed in', (tester) async {
      await _openGarden(tester, [
        for (var n = 0; n < 12; n++)
          _plant(
            id: 'plant-$n',
            type: PlantType.values[n % PlantType.values.length],
            plot: GardenPlots.inPlacementOrder[n],
          ),
      ]);

      // Zoom all the way in so the camera is nothing like the initial one.
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

      // Whichever plant is now under the screen centre.
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

    testWidgets('opens when zoomed out', (tester) async {
      // Fully zoomed out is the smallest a plant is ever drawn.
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
