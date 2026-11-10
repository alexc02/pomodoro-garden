import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/celebrations.dart';

// What a long-time user sees once the garden has all 200 plots: late
// milestone plants still get planted, and the journal agrees with the garden
// about how big it is.

GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GardenPainter,
      skipOffstage: false,
    ))
    .painter! as GardenPainter;

/// Writes [sessions] completed sessions the way a real history looks: each
/// session plant and each milestone award takes the next free plot in the
/// order it was earned. Awards past the cap go unplaced, as they did before
/// they could take a session plant's plot.
Future<void> _seedHistory(AppDatabase database, int sessions) async {
  final recorded = DriftSessionRepository(database);
  final garden = DriftPlantRepository(database);
  final occupied = <GardenPlot>{};

  GardenPlot? nextPlot() {
    final plot = GardenPlots.nextFree(occupied);
    if (plot != null) occupied.add(plot);
    return plot;
  }

  for (var n = 0; n < sessions; n++) {
    final anchor = testInstant.subtract(Duration(hours: sessions - n));
    final session = FocusSession(
      id: 'history-session-$n',
      startedAt: anchor,
      plannedDuration: const Duration(minutes: 25),
    ).completedAt(anchor.add(const Duration(minutes: 25)));

    await recorded.save(session);
    await garden.save(
      Plant.fromSession(session, id: 'history-plant-$n', plot: nextPlot()),
    );

    final milestone = Milestone.withSessions(n + 1);
    if (milestone != null) {
      await garden.save(Plant.forMilestone(
        milestone,
        id: 'history-bonus-${milestone.sessions}',
        plantedAt: anchor,
        plot: nextPlot(),
      ));
    }
  }
}

void main() {
  group('a milestone reached after the garden is full', () {
    for (final milestone in [
      Milestone.twoHundredAndFifty,
      Milestone.fiveHundred,
      Milestone.oneThousand,
    ]) {
      testWidgets('${milestone.label}: the award is planted', (tester) async {
        final database = AppDatabase.forTesting();
        addTearDown(database.close);
        final clock = FixedClock(testInstant);
        await _seedHistory(database, milestone.sessions - 1);

        await pumpApp(
          tester,
          database: database,
          clock: clock,
          surface: const Size(400, 800),
          settings: GardenSettings.defaults
              .withSessionLength(const Duration(minutes: 25)),
        );
        await dismissCelebrations(tester);
        final before = (await DriftPlantRepository(database).plants()).length;

        // The session that earns it, through the real timer.
        await startSession(tester);
        await advance(tester, clock, const Duration(minutes: 25));
        await settle(tester);

        final plants = await DriftPlantRepository(database).plants();
        final award = plants.singleWhere((p) => p.milestone == milestone);
        expect(award.plot, isNotNull, reason: 'the award has a plot');
        expect(plants, hasLength(before + 2),
            reason: 'the session plant and the award, nothing dropped');
        expect(
          plants.where((p) => p.plot != null),
          hasLength(GardenPlots.maximum),
          reason: 'the plant that made way is unplaced, not doubled up',
        );

        await tapTab(tester, AppTab.garden);
        final layout = _painter(tester).layout;
        expect(layout.plotCount, GardenPlots.maximum);
        expect(layout.plants, hasLength(GardenPlots.maximum));
        expect(layout.bonusPlants, contains(award));
      });
    }
  });

  group('the journal counts the plots the garden draws', () {
    for (final sessions in [30, 100, 196, 300]) {
      testWidgets('after $sessions sessions', (tester) async {
        final database = AppDatabase.forTesting();
        addTearDown(database.close);
        await _seedHistory(database, sessions);

        await pumpApp(
          tester,
          database: database,
          surface: const Size(400, 800),
        );
        await dismissCelebrations(tester);
        final drawn = _painter(tester).layout.plotCount;

        await tapTab(tester, AppTab.journal);
        final level = find.textContaining('Garden level');
        await tester.scrollUntilVisible(
          level,
          300,
          scrollable: find.byType(Scrollable).last,
        );

        expect(tester.widget<Text>(level).data, endsWith('· $drawn plots'));
      });
    }
  });
}
