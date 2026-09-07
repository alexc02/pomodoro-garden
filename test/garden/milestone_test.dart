import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/features/garden/garden_view.dart';
import 'package:pip_garden/src/features/garden/milestone_card.dart';
import 'package:pip_garden/src/features/garden/plant_card.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/shell/tab.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/app_harness.dart';
import '../support/celebrations.dart';
import '../support/garden_seed.dart';
import '../support/plant_pose.dart';

// Bonus plants through the real app: awarded at launch, only once, planted
// somewhere, labelled, and the celebration waits its turn. Which milestones
// a count reaches is tested in
// packages/pomodoro_domain/test/garden/milestone_test.dart.

/// Writes [sessions] completed sessions and no plants, so the garden starts
/// empty and the test can say exactly where an award landed. Use [seedGarden]
/// when the garden should already have plants.
Future<void> seedSessions(AppDatabase database, int sessions) async {
  final recorded = DriftSessionRepository(database);

  for (var n = 0; n < sessions; n++) {
    // Oldest first, all before this launch.
    final anchor = testInstant.subtract(Duration(minutes: 30 * (sessions - n)));
    await recorded.save(
      FocusSession(
        id: 'past-session-$n',
        startedAt: anchor,
        plannedDuration: const Duration(minutes: 25),
      ).completedAt(anchor.add(const Duration(minutes: 25))),
    );
  }
}

GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is GardenPainter,
        skipOffstage: false,
      ),
    )
    .painter! as GardenPainter;

/// Bonus plants in [database], in milestone order.
Future<List<Plant>> awardedPlants(AppDatabase database) async {
  final plants = (await DriftPlantRepository(database).plants())
      .where((plant) => plant.isBonus)
      .toList()
    ..sort((a, b) => a.milestone!.sessions.compareTo(b.milestone!.sessions));

  return plants;
}

void main() {
  group('awarding', () {
    // One test per milestone so a failure names it.
    for (final milestone in Milestone.values) {
      testWidgets('${milestone.label} awards ${milestone.species.label}',
          (tester) async {
        final database = AppDatabase.forTesting();
        addTearDown(database.close);
        await seedSessions(database, milestone.sessions);

        await pumpApp(tester, database: database);
        await settle(tester);

        final garden = DriftPlantRepository(database);
        expect(
          await garden.awardedMilestones(),
          Milestone.reachedBy(milestone.sessions).toSet(),
          reason: 'exactly the milestones reached',
        );

        final awarded = (await garden.plants())
            .singleWhere((plant) => plant.milestone == milestone);
        expect(awarded.species, milestone.species);
        expect(awarded.type, PlantType.bonus);
        expect(awarded.isBonus, isTrue);
        // Fully grown: no session behind it to watch it grow.
        expect(awarded.stage, GrowthStage.mature);
        expect(awarded.sessionId, isNull);
        expect(awarded.sessionDuration, isNull);
        expect(awarded.plot, isNotNull, reason: 'has a plot');
      });
    }

    testWidgets('one short earns nothing', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedSessions(database, 9);

      await pumpApp(tester, database: database);
      await settle(tester);

      expect(await DriftPlantRepository(database).awardedMilestones(), isEmpty);
      expect(find.byType(MilestoneCard), findsNothing);
    });

    testWidgets('30 existing sessions get both awards', (tester) async {
      // First launch on this build with 30 sessions: both 10 and 25 are owed.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedSessions(database, 30);

      await pumpApp(tester, database: database);
      await settle(tester);

      expect(
        await DriftPlantRepository(database).awardedMilestones(),
        {Milestone.ten, Milestone.twentyFive},
      );
      expect(
        (await awardedPlants(database)).map((plant) => plant.species),
        [PlantSpecies.bonsai, PlantSpecies.wisteriaArch],
      );
    });
  });

  group('only once', () {
    testWidgets('second launch awards nothing', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedSessions(database, 30);

      await pumpApp(tester, database: database);
      await settle(tester);
      final afterFirstLaunch = await awardedPlants(database);
      expect(afterFirstLaunch, hasLength(2));

      await killApp(tester);
      await pumpApp(tester, database: database);
      await settle(tester);

      expect(
        await awardedPlants(database),
        afterFirstLaunch,
        reason: 'same two plants',
      );
    });

    testWidgets('later session does not repeat it', (tester) async {
      // The check runs at launch and again when session 11 completes. The
      // second run must find the tenth already planted.
      final clock = FixedClock(testInstant);
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedSessions(database, 10);

      await pumpApp(tester, clock: clock, database: database);
      await dismissCelebrations(tester);
      expect(await awardedPlants(database), hasLength(1));

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      await settle(tester);

      expect(await awardedPlants(database), hasLength(1));
      expect(
        (await DriftSessionRepository(database).completedSessions()),
        hasLength(11),
      );
    });

    testWidgets('database rejects a duplicate milestone', (tester) async {
      // Backstop: the unique index on milestone count. Tested via the
      // repository since the app logic is what it guards against.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final garden = DriftPlantRepository(database);

      await garden.save(Plant.forMilestone(
        Milestone.ten,
        id: 'first',
        plantedAt: testInstant,
        plot: GardenPlots.inPlacementOrder.first,
      ));

      expect(
        () => garden.save(Plant.forMilestone(
          Milestone.ten,
          id: 'second',
          plantedAt: testInstant,
          plot: GardenPlots.inPlacementOrder[1],
        )),
        throwsA(
          isA<SqliteException>().having(
            (error) => error.message,
            'message',
            contains('UNIQUE constraint failed: plants.milestone_sessions'),
          ),
        ),
        reason: 'unique index rejects it',
      );
      expect(await garden.awardedMilestones(), {Milestone.ten});
    });
  });

  group('placement', () {
    testWidgets('nearest free plot', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      // Ten sessions and their plants fill the first ten plots.
      await seedGarden(database, sessions: 10);

      await pumpApp(tester, database: database, surface: const Size(400, 800));
      await dismissCelebrations(tester);

      final awarded = (await awardedPlants(database)).single;
      expect(awarded.plot, GardenPlots.inPlacementOrder[10]);
    });

    testWidgets('garden grows when full', (tester) async {
      // 20 sessions unlock exactly 20 plots and grow 20 plants. The award still
      // goes in; the garden grows to fit.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 20);
      expect(GardenPlots.unlockedAfter(20), 20);

      await pumpApp(tester, database: database, surface: const Size(400, 800));
      await dismissCelebrations(tester);
      await tapTab(tester, AppTab.garden);

      final awarded = (await awardedPlants(database)).single;
      expect(awarded.plot, GardenPlots.inPlacementOrder[20]);

      final layout = _painter(tester).layout;
      expect(layout.plotCount, 21, reason: 'the garden expanded by one');
      expect(layout.plantIn(awarded.plot!), awarded);
    });

    testWidgets('kept unplaced at the cap', (tester) async {
      // Plot 200 is the end of the placement order, so the garden can't grow.
      // The award is still recorded and counted.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 210);

      await pumpApp(tester, database: database, surface: const Size(400, 800));
      await settle(tester);

      expect(
        await DriftPlantRepository(database).awardedMilestones(),
        {
          Milestone.ten,
          Milestone.twentyFive,
          Milestone.fifty,
          Milestone.oneHundred,
        },
      );
      final awarded = await awardedPlants(database);
      expect(awarded, hasLength(4));
      expect(
        awarded.every((plant) => plant.plot == null),
        isTrue,
        reason: 'unplaced but kept',
      );
    });
  });

  group('labelling', () {
    testWidgets('card names the milestone', (tester) async {
      // No session plants, so the award is alone in the middle.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedSessions(database, 10);

      await pumpApp(tester, database: database, surface: const Size(400, 800));
      await dismissCelebrations(tester);
      await tapTab(tester, AppTab.garden);

      final awarded = (await awardedPlants(database)).single;
      await tester.tapAt(
        tester.getTopLeft(find.byType(GardenView)) +
            _painter(tester).projection.centreOf(awarded.plot!),
      );
      await settle(tester);

      expect(find.byType(PlantCard), findsOneWidget);
      expect(find.text('Bonsai tree'), findsOneWidget);
      expect(find.text('Bonus plant'), findsOneWidget,
          reason: 'labelled as a bonus plant');
      expect(find.text('Awarded at'), findsOneWidget);
      expect(find.text('10 sessions'), findsOneWidget);
      // Bonus plants have no session row.
      expect(find.text('Session'), findsNothing);
    });

    testWidgets('drawn differently from session plants', (tester) async {
      // As tall as the largest session plant but wider, so it stands out.
      const registry = PlaceholderPlantSpriteRegistry();
      Rect footprint(PlantType type) => registry
          .spriteFor(type: type, stage: GrowthStage.mature)
          .footprintIn(const Rect.fromLTWH(0, 0, 100, 100));

      final bonus = footprint(PlantType.bonus);
      final largest = footprint(PlantType.largeTree);

      expect(bonus.height, greaterThanOrEqualTo(largest.height));
      expect(bonus.width, greaterThan(largest.width));
    });
  });

  testWidgets('not counted as a session', (tester) async {
    // The timer count reads the sessions table, so awards can't inflate it.
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await seedGarden(database, sessions: 10);

    await pumpApp(tester, database: database, surface: const Size(400, 800));
    await dismissCelebrations(tester);

    await tapTab(tester, AppTab.timer);
    expect(find.text('10 sessions grown'), findsOneWidget);
    expect(find.text('11 sessions grown'), findsNothing);
    expect(
      (await DriftSessionRepository(database).completedSessions()),
      hasLength(10),
    );

    await tapTab(tester, AppTab.garden);
    final layout = _painter(tester).layout;
    expect(layout.plants, hasLength(11));
    expect(layout.bonusPlants, hasLength(1));
    // The garden names awards separately from session plants.
    expect(
      find.bySemanticsLabel(
          'Your garden: 11 plants in 16 plots, 1 bonus plant among them.'),
      findsOneWidget,
    );
  });

  group('the celebration', () {
    testWidgets('comes after the session completion', (tester) async {
      final clock = FixedClock(testInstant);
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      // One short, so the user watches the session that reaches it.
      await seedSessions(database, 9);

      await pumpApp(tester, clock: clock, database: database);
      expect(find.byType(MilestoneCard), findsNothing);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      // The session's own ending (chime, haptic, growth spring) goes first.
      expect(find.text('Session complete'), findsOneWidget);
      expect(find.byType(MilestoneCard), findsNothing,
          reason: 'the celebration does not compete with the completion');
      // The plant is already planted while the card waits.
      expect(await awardedPlants(database), hasLength(1));

      await waitForCelebration(tester);

      expect(find.byType(MilestoneCard), findsOneWidget);
      expect(find.text('10 sessions of focus'), findsOneWidget);
      expect(find.text('Bonsai tree'), findsOneWidget);
    });

    testWidgets('waits for the bloom', (tester) async {
      // Bloom and card happen one after the other at the tenth session. Checked
      // frame by frame since the bug would be the card rising mid-bloom.
      final clock = FixedClock(testInstant);
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedSessions(database, 9);

      await pumpApp(tester, clock: clock, database: database);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));

      var bloomed = false;
      var finished = false;
      for (var frame = 0; frame < 300 && !finished; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final bloom = bloomOnScreen(tester);
        bloomed = bloomed || bloom > 0;
        finished = bloom == 1;
        if (!finished) {
          expect(find.byType(MilestoneCard), findsNothing,
              reason: 'nothing rises while the petals are in the air');
        }
      }

      expect(bloomed, isTrue, reason: 'the tenth session bloomed');
      expect(finished, isTrue, reason: 'bloom finished');
      expect(find.byType(MilestoneCard), findsNothing,
          reason: 'card waits for the bloom');

      await waitForCelebration(tester);
      expect(find.byType(MilestoneCard), findsOneWidget,
          reason: 'card rises after');
    });

    testWidgets('never over a running session', (tester) async {
      final clock = FixedClock(testInstant);
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedSessions(database, 9);

      await pumpApp(tester, clock: clock, database: database);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      // User starts the next session straight away; the card waits.
      await tester.tap(find.text('Plant another'));
      await tester.pump();
      await advance(tester, clock, const Duration(minutes: 10));
      await settle(tester);

      expect(find.byType(MilestoneCard), findsNothing,
          reason: 'no modal interrupts an active session');
      expect(await awardedPlants(database), hasLength(1),
          reason: 'award is planted, card is deferred');

      // Shows once the session is over.
      await advance(tester, clock, const Duration(minutes: 15));
      await settle(tester);
      await settle(tester);

      expect(find.byType(MilestoneCard), findsOneWidget);
    });

    testWidgets('backlog one at a time, oldest first', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedSessions(database, 30);

      await pumpApp(tester, database: database);
      await waitForCelebration(tester);

      expect(find.text('10 sessions of focus'), findsOneWidget);
      expect(find.text('25 sessions of focus'), findsNothing,
          reason: 'one card at a time');

      await tester.tap(find.text('Lovely'));
      await waitForCelebration(tester);

      expect(find.text('25 sessions of focus'), findsOneWidget);

      await tester.tap(find.text('Lovely'));
      await waitForCelebration(tester);

      expect(find.byType(MilestoneCard), findsNothing);
    });

    testWidgets('not shown again on next launch', (tester) async {
      // The card shows once. Re-celebrating on every launch would get old fast.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedSessions(database, 10);

      await pumpApp(tester, database: database);
      await dismissCelebrations(tester);

      await killApp(tester);
      await pumpApp(tester, database: database);
      await waitForCelebration(tester);

      expect(find.byType(MilestoneCard), findsNothing);
    });
  });
}
