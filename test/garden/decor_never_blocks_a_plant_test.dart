import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/decor_fixtures.dart';
import '../support/garden_seed.dart';

/// ADR 0017 through the real app: an arrangement never costs a completed
/// session its plot.
///
/// The rule itself is exercised exhaustively in the domain core — see
/// `garden_plot_test.dart`. What is under test here is the *wiring*: that the
/// two things in this app which plant something ask the rule with the
/// arrangement in hand, and that the one case where an object gives way really
/// does take it out of the garden rather than leaving two things in one plot.

/// The painter currently on the garden tab.
GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GardenPainter,
      skipOffstage: false,
    ))
    .painter! as GardenPainter;

/// Writes [count] plants straight into the ground, in the plots the placement
/// rule would have given them.
///
/// Plants without sessions, deliberately: what these tests need is a *full
/// garden*, and two hundred sessions through the timer would be minutes of
/// pumped frames to arrange the same rows. The sessions each test does want —
/// the ones that decide what is due and what is planted — it writes itself.
Future<void> _fillWithPlants(AppDatabase database, int count) async {
  final garden = DriftPlantRepository(database);
  final anchor = testInstant.subtract(const Duration(days: 400));

  for (var n = 0; n < count; n++) {
    final session = FocusSession(
      id: 'filler-$n',
      startedAt: anchor.add(Duration(hours: n)),
      plannedDuration: const Duration(minutes: 25),
    ).completedAt(anchor.add(Duration(hours: n, minutes: 25)));

    await garden.save(Plant.fromSession(
      session,
      id: 'filler-plant-$n',
      plot: GardenPlots.inPlacementOrder[n],
    ));
  }
}

void main() {
  late AppDatabase database;
  late FixedClock clock;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
    clock = FixedClock(testInstant);
  });

  testWidgets('an object is stepped over rather than pushed aside',
      (tester) async {
    // The ordinary case, and the one every real garden lives in: the plant
    // takes the next plot along and the arrangement is exactly as the user left
    // it. Nothing about a garden with room in it is a negotiation.
    await seedGarden(database, sessions: 3);
    await DriftDecorRepository(database)
        .save(testDecor(DecorKind.lantern, GardenPlots.inPlacementOrder[3]));

    await pumpApp(
      tester,
      database: database,
      clock: clock,
      settings: GardenSettings.defaults
          .withSessionLength(const Duration(minutes: 25)),
    );
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);
    await tapTab(tester, AppTab.garden);

    final layout = _painter(tester).layout;
    expect(
      layout.plantIn(GardenPlots.inPlacementOrder[4]),
      isNotNull,
      reason: 'the plant went into the next plot along',
    );
    expect(layout.decorIn(GardenPlots.inPlacementOrder[3])!.kind,
        DecorKind.lantern);
    expect(layout.unplaced, isEmpty);
  });

  testWidgets('a completed session displaces an object rather than going '
      'unplaced', (tester) async {
    // A hundred and ninety-nine plants and an object in the two-hundredth plot:
    // the garden has nowhere left at all. The plant takes the plot the object
    // was in — the outermost one, furthest from anything the user composed —
    // and the object goes.
    await _fillWithPlants(database, 199);
    final last = GardenPlots.inPlacementOrder[199];
    await DriftDecorRepository(database).save(testDecor(DecorKind.bench, last));

    await pumpApp(
      tester,
      database: database,
      clock: clock,
      settings: GardenSettings.defaults
          .withSessionLength(const Duration(minutes: 25)),
    );
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);
    await tapTab(tester, AppTab.garden);

    final layout = _painter(tester).layout;
    expect(layout.plantIn(last), isNotNull);
    expect(layout.decor, isEmpty);
    expect(layout.unplaced, isEmpty, reason: 'nothing was turned away');
    expect(await DriftDecorRepository(database).decor(), isEmpty,
        reason: 'the displaced object is out of the table, not just off screen');
  });

  testWidgets('and so does a bonus plant', (tester) async {
    // REQ-021's awards go into the ground by the same rule and with the same
    // claim on a plot: an award is a plant, and a plant is never turned away
    // for furniture.
    await _fillWithPlants(database, 199);
    final last = GardenPlots.inPlacementOrder[199];
    await DriftDecorRepository(database).save(testDecor(DecorKind.pond, last));

    // Ten completed sessions and no plants of their own — the filler above is
    // the garden. What these buy is a milestone that is due at launch.
    final sessions = DriftSessionRepository(database);
    for (var n = 0; n < 10; n++) {
      final anchor = testInstant.subtract(Duration(days: 10 - n));
      await sessions.save(
        FocusSession(
          id: 'counted-$n',
          startedAt: anchor,
          plannedDuration: const Duration(minutes: 25),
        ).completedAt(anchor.add(const Duration(minutes: 25))),
      );
    }

    await pumpApp(tester, database: database, clock: clock);
    await settle(tester);

    // Read out of the tables rather than off the garden tab, because an award
    // puts REQ-021's celebration up over everything and this test is not about
    // that sheet. What reaches the screen is the other two tests' claim.
    final layout = GardenLayout.of(
      plants: await DriftPlantRepository(database).plants(),
      decor: await DriftDecorRepository(database).decor(),
      completedSessions: 10,
    );

    expect(layout.bonusPlants, hasLength(1));
    expect(layout.plantIn(last)!.milestone, Milestone.ten);
    expect(layout.decor, isEmpty);
    expect(layout.unplaced, isEmpty);
  });
}
