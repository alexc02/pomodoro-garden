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

// End-to-end check that decor never costs a session its plot.
// The rule is tested in the domain (garden_plot_test.dart).

GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GardenPainter,
      skipOffstage: false,
    ))
    .painter! as GardenPainter;

/// Writes [count] plants directly into their placement plots. No sessions,
/// since running 200 through the timer would be slow.
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

  testWidgets('plants skip decor plots', (tester) async {
    // Normal case: the plant takes the next plot and decor stays put.
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
      reason: 'plant took the next plot',
    );
    expect(layout.decorIn(GardenPlots.inPlacementOrder[3])!.kind,
        DecorKind.lantern);
    expect(layout.unplaced, isEmpty);
  });

  testWidgets('full garden displaces decor', (tester) async {
    // 199 plants and decor in plot 200: the plant takes the decor's plot and
    // the decor is removed.
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
    expect(layout.unplaced, isEmpty, reason: 'nothing unplaced');
    expect(await DriftDecorRepository(database).decor(), isEmpty,
        reason: 'displaced decor deleted');
  });

  testWidgets('bonus plant also displaces decor', (tester) async {
    // Bonus plants follow the same rule.
    await _fillWithPlants(database, 199);
    final last = GardenPlots.inPlacementOrder[199];
    await DriftDecorRepository(database).save(testDecor(DecorKind.pond, last));

    // Ten sessions so a milestone is due at launch.
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

    // Read from the tables; the celebration sheet covers the garden tab.
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
