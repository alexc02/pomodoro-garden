import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/features/garden/decor_picker.dart';
import 'package:pip_garden/src/features/garden/plant_card.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/celebrations.dart';
import '../support/garden_seed.dart';

// Arranging through the real app. The garden is one painted surface, so
// everything is driven by taps on it.

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

/// An empty plot, by placement index.
GardenPlot _emptyPlot(int index) => GardenPlots.inPlacementOrder[index];

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  Future<void> openGarden(
    WidgetTester tester, {
    int sessions = 3,
    List<Override> overrides = const [],
  }) async {
    await seedGarden(database, sessions: sessions);

    await pumpApp(
      tester,
      database: database,
      surface: const Size(500, 900),
      overrides: overrides,
    );
    await tapTab(tester, AppTab.garden);
  }

  Future<void> startArranging(WidgetTester tester) async {
    await tester.tap(find.byKey(DecorKeys.arrange));
    await settle(tester);
  }

  /// Places a [kind] in [plot] via the picker.
  Future<void> place(
    WidgetTester tester,
    DecorKind kind,
    GardenPlot plot,
  ) async {
    await _tapPlot(tester, plot);
    await tester.tap(find.byKey(DecorKeys.kind(kind)));
    await settle(tester);
  }

  group('placing', () {
    testWidgets('places decor in an empty plot', (tester) async {
      await openGarden(tester);
      await startArranging(tester);

      await place(tester, DecorKind.lantern, _emptyPlot(5));

      final layout = _painter(tester).layout;
      expect(layout.decor, hasLength(1));
      expect(layout.decorIn(_emptyPlot(5))!.kind, DecorKind.lantern);
    });

    testWidgets('picker lists all four kinds', (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await _tapPlot(tester, _emptyPlot(5));

      for (final kind in DecorKind.values) {
        expect(find.byKey(DecorKeys.kind(kind)), findsOneWidget);
        expect(find.text(kind.label), findsOneWidget);
      }
    });

    testWidgets('dismissing the picker places nothing', (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await _tapPlot(tester, _emptyPlot(5));

      // Tap the backdrop to dismiss the sheet.
      await tester.tapAt(const Offset(250, 40));
      await settle(tester);

      expect(_painter(tester).layout.decor, isEmpty);
      expect(await DriftDecorRepository(database).decor(), isEmpty);
    });

    testWidgets("no picker for a plant's plot", (tester) async {
      // Plants can't be moved, removed or covered.
      await openGarden(tester);
      await startArranging(tester);

      await _tapPlot(tester, GardenPlots.inPlacementOrder[0]);

      expect(find.byKey(DecorKeys.kind(DecorKind.bench)), findsNothing);
      expect(_painter(tester).layout.decor, isEmpty);
    });

    testWidgets('no placing outside arranging mode', (tester) async {
      await openGarden(tester);

      await _tapPlot(tester, _emptyPlot(5));

      expect(find.byKey(DecorKeys.kind(DecorKind.bench)), findsNothing);
      expect(_painter(tester).layout.decor, isEmpty);
    });
  });

  group('move and remove', () {
    testWidgets('moving keeps the same item', (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await place(tester, DecorKind.bench, _emptyPlot(5));

      final placed = _painter(tester).layout.decor.single;

      await _tapPlot(tester, _emptyPlot(5));
      expect(
        find.byKey(DecorKeys.remove),
        findsOneWidget,
        reason: 'bar shows the picked-up item',
      );

      await _tapPlot(tester, _emptyPlot(7));

      final moved = _painter(tester).layout.decor.single;
      expect(moved.id, placed.id);
      expect(moved.plot, _emptyPlot(7));
      expect(_painter(tester).layout.decorIn(_emptyPlot(5)), isNull);
    });

    testWidgets('removes decor', (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await place(tester, DecorKind.pond, _emptyPlot(5));

      await _tapPlot(tester, _emptyPlot(5));
      await tester.tap(find.byKey(DecorKeys.remove));
      await settle(tester);

      expect(_painter(tester).layout.decor, isEmpty);
      expect(await DriftDecorRepository(database).decor(), isEmpty);
    });

    testWidgets('dropping in place is a no-op', (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await place(tester, DecorKind.birdbath, _emptyPlot(5));

      await _tapPlot(tester, _emptyPlot(5));
      // Tapping it again drops it in place.
      await _tapPlot(tester, _emptyPlot(5));

      expect(_painter(tester).layout.decorIn(_emptyPlot(5)), isNotNull);
      expect(find.byKey(DecorKeys.remove), findsNothing);
    });

    testWidgets('leaving arranging returns to viewing', (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await place(tester, DecorKind.lantern, _emptyPlot(5));

      await tester.tap(find.byKey(DecorKeys.done));
      await settle(tester);

      expect(find.byKey(DecorKeys.guidance), findsNothing);
      await _tapPlot(tester, _emptyPlot(6));
      expect(find.byKey(DecorKeys.kind(DecorKind.bench)), findsNothing);
    });
  });

  // Decor behind a plant couldn't be picked up, so it couldn't be removed.
  group('behind plants', () {
    /// [sessions] plants, with a [kind] in every unlocked plot left over.
    /// Returns the decor nearest first, so tapping one never hits another.
    Future<List<Decor>> openCrowdedGarden(
      WidgetTester tester, {
      required int sessions,
      required DecorKind kind,
    }) async {
      final repository = DriftDecorRepository(database);
      for (var n = sessions; n < GardenPlots.unlockedAfter(sessions); n++) {
        await repository.save(Decor(
          id: 'item-$n',
          kind: kind,
          plot: _emptyPlot(n),
          placedAt: testInstant,
        ));
      }

      await seedGarden(database, sessions: sessions);
      await pumpApp(tester, database: database, surface: const Size(500, 900));
      // 10+ sessions shows the milestone sheet over the garden.
      await dismissCelebrations(tester);
      await tapTab(tester, AppTab.garden);
      await startArranging(tester);

      return _painter(tester).layout.decor.toList()
        ..sort((a, b) => b.plot.depth.compareTo(a.plot.depth));
    }

    for (final (sessions, kind) in const [
      (9, DecorKind.bench),
      (9, DecorKind.birdbath),
      (9, DecorKind.pond),
      (14, DecorKind.lantern),
      (14, DecorKind.pond),
    ]) {
      testWidgets('removes every ${kind.name} from a garden of $sessions',
          (tester) async {
        final items =
            await openCrowdedGarden(tester, sessions: sessions, kind: kind);

        for (final item in items) {
          await _tapPlot(tester, item.plot);
          expect(find.byKey(DecorKeys.remove), findsOneWidget,
              reason: 'could not pick up ${item.plot}');
          await tester.tap(find.byKey(DecorKeys.remove));
          await settle(tester);
        }

        expect(_painter(tester).layout.decor, isEmpty);
        expect(await DriftDecorRepository(database).decor(), isEmpty);
      });
    }

    testWidgets('removing one keeps the rest', (tester) async {
      final items =
          await openCrowdedGarden(tester, sessions: 9, kind: DecorKind.pond);

      await _tapPlot(tester, items.first.plot);
      await tester.tap(find.byKey(DecorKeys.remove));
      await settle(tester);

      expect(
        await DriftDecorRepository(database).decor(),
        unorderedEquals(items.skip(1)),
      );
      expect(await DriftPlantRepository(database).plants(), hasLength(9));
    });

    testWidgets('places decor in a plot behind a plant', (tester) async {
      final items =
          await openCrowdedGarden(tester, sessions: 9, kind: DecorKind.pond);
      // The one furthest back.
      final plot = items.last.plot;
      await _tapPlot(tester, plot);
      await tester.tap(find.byKey(DecorKeys.remove));
      await settle(tester);

      await place(tester, DecorKind.bench, plot);

      expect(_painter(tester).layout.decorIn(plot)?.kind, DecorKind.bench);
    });

    testWidgets('tapping a plant still does nothing', (tester) async {
      await openCrowdedGarden(tester, sessions: 9, kind: DecorKind.pond);

      await _tapPlot(tester, _emptyPlot(0));

      expect(find.byType(PlantCard), findsNothing);
      expect(find.byKey(DecorKeys.remove), findsNothing);
    });
  });

  group('semantics', () {
    testWidgets('label includes decor', (tester) async {
      // The garden is one painted surface, so this label is all a screen reader
      // gets.
      await openGarden(tester);
      await startArranging(tester);
      await place(tester, DecorKind.lantern, _emptyPlot(5));

      expect(
        find.bySemanticsLabel('Your garden: 3 plants in 12 plots. One thing '
            'you placed stands among them.'),
        findsOneWidget,
      );

      await place(tester, DecorKind.bench, _emptyPlot(6));

      expect(
        find.bySemanticsLabel('Your garden: 3 plants in 12 plots. 2 things '
            'you placed stand among them.'),
        findsOneWidget,
      );
    });

    testWidgets('label omits decor when there is none', (tester) async {
      await openGarden(tester);

      expect(
        find.bySemanticsLabel('Your garden: 3 plants in 12 plots.'),
        findsOneWidget,
      );
    });
  });

  group('interruptions', () {
    testWidgets('starting a session exits arranging', (tester) async {
      // Auto-start can begin a session with no tap, hence a listener rather
      // than a check at the tap.
      await openGarden(tester);
      await startArranging(tester);
      expect(find.byKey(DecorKeys.guidance), findsOneWidget);

      await startSession(tester);
      await tapTab(tester, AppTab.garden);

      expect(find.byKey(DecorKeys.guidance), findsNothing);
      expect(await DriftDecorRepository(database).decor(), isEmpty);
    });
  });

  group('persistence', () {
    testWidgets('survives relaunch', (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await place(tester, DecorKind.lantern, _emptyPlot(5));
      await place(tester, DecorKind.pond, _emptyPlot(6));

      await killApp(tester);
      await pumpApp(
        tester,
        database: database,
        surface: const Size(500, 900),
      );
      await tapTab(tester, AppTab.garden);

      final layout = _painter(tester).layout;
      expect(layout.decor, hasLength(2));
      expect(layout.decorIn(_emptyPlot(5))!.kind, DecorKind.lantern);
      expect(layout.decorIn(_emptyPlot(6))!.kind, DecorKind.pond);
    });

    testWidgets('arrange button shown to everyone', (tester) async {
      // Arranging is free for everyone. See ADR 0005
      await openGarden(tester);

      expect(find.byKey(DecorKeys.arrange), findsOneWidget);
    });
  });
}
