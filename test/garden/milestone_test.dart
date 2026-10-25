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

/// REQ-021's bonus plants, through the real app.
///
/// The arithmetic of *which* milestones a count has reached is
/// `packages/pomodoro_domain/test/garden/milestone_test.dart`, which can ask
/// the question directly. What is under test here is everything that only a
/// running app can answer: that the awards are actually made on a launch, that
/// they are made once however many times the app is opened, that the plant ends
/// up standing somewhere, that it says what earned it, and that the celebration
/// waits its turn.

/// Writes [sessions] completed sessions and no plants at all.
///
/// Deliberately not [seedGarden]: the awarding rule reads the *sessions* table
/// for the count and the *plants* table for what has already been handed out,
/// and a fixture with no session plants in it leaves the garden empty so a test
/// can say exactly where an award landed. [seedGarden] is used by the tests
/// below that are about a garden with something already in it.
Future<void> seedSessions(AppDatabase database, int sessions) async {
  final recorded = DriftSessionRepository(database);

  for (var n = 0; n < sessions; n++) {
    // Oldest first, and all in the past: these are sessions the user sat
    // through before this launch.
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

/// The painter currently on the garden tab.
GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is GardenPainter,
        skipOffstage: false,
      ),
    )
    .painter! as GardenPainter;

/// Every bonus plant in [database]'s garden, milestone order.
Future<List<Plant>> awardedPlants(AppDatabase database) async {
  final plants = (await DriftPlantRepository(database).plants())
      .where((plant) => plant.isBonus)
      .toList()
    ..sort((a, b) => a.milestone!.sessions.compareTo(b.milestone!.sessions));

  return plants;
}

void main() {
  group('which milestones are awarded', () {
    // One test per milestone rather than a loop inside one, so a build that
    // broke only the thousandth says so by name.
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
          reason: 'every milestone this count has reached, and no other',
        );

        final awarded = (await garden.plants())
            .singleWhere((plant) => plant.milestone == milestone);
        expect(awarded.species, milestone.species);
        expect(awarded.type, PlantType.bonus);
        expect(awarded.isBonus, isTrue);
        // Fully grown on arrival: there is no session under a bonus plant to
        // have watched it grow.
        expect(awarded.stage, GrowthStage.mature);
        expect(awarded.sessionId, isNull);
        expect(awarded.sessionDuration, isNull);
        expect(awarded.plot, isNotNull, reason: 'and it is standing somewhere');
      });
    }

    testWidgets('a count one short of a milestone earns nothing',
        (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedSessions(database, 9);

      await pumpApp(tester, database: database);
      await settle(tester);

      expect(await DriftPlantRepository(database).awardedMilestones(), isEmpty);
      expect(find.byType(MilestoneCard), findsNothing);
    });

    testWidgets('a user who arrives with thirty sessions collects both awards',
        (tester) async {
      // The half of the requirement a threshold check would miss. This user has
      // never run this build before; their thirty sessions crossed ten and
      // twenty-five while no version of the app was watching, and they are owed
      // both rather than nothing.
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

  group('awarding happens exactly once', () {
    testWidgets('a second launch hands out nothing again', (tester) async {
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
        reason: 'the same two plants, not four and not two new ones',
      );
    });

    testWidgets('and a session completing after one does not repeat it',
        (tester) async {
      // The check really does run twice here: once at launch, and again when
      // the eleventh session moves the count. The second run has to find the
      // tenth already in the ground and do nothing.
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

    testWidgets('the database refuses a second plant for the same milestone',
        (tester) async {
      // The backstop under the code above, and the one that survives a bug in
      // it: PRD §4.3's unique index on the milestone count. Asserted against
      // the repository rather than through the app, because the app is what
      // this is insurance against.
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
        reason: 'the index refuses it, rather than the garden doubling',
      );
      expect(await garden.awardedMilestones(), {Milestone.ten});
    });
  });

  group('where the award is planted', () {
    testWidgets('into the nearest free plot, like anything else', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      // Ten sessions and the ten plants they grew, filling the first ten plots.
      await seedGarden(database, sessions: 10);

      await pumpApp(tester, database: database, surface: const Size(400, 800));
      await dismissCelebrations(tester);

      final awarded = (await awardedPlants(database)).single;
      expect(awarded.plot, GardenPlots.inPlacementOrder[10]);
    });

    testWidgets('and the garden grows to hold it when its plots are all full',
        (tester) async {
      // Twenty sessions unlock exactly twenty plots and grow exactly twenty
      // plants, so the schedule has nothing spare. The award is not turned
      // away: ADR 0006's garden is never smaller than what is planted in it.
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

    testWidgets('and an award at the cap is kept rather than lost',
        (tester) async {
      // Two hundred plots is the end of the placement order, so this is the one
      // case that cannot expand. The award is still *made* — recorded, counted
      // and readable — which is the difference between a plant with nowhere to
      // stand and an award that silently never happened.
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
        reason: 'nowhere to stand, and kept all the same',
      );
    });
  });

  group('what a bonus plant says about itself', () {
    testWidgets('its card names the milestone that earned it', (tester) async {
      // Seeded with sessions and no session plants, so the award stands alone
      // in the middle of the garden and a tap cannot land on anything else.
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
          reason: 'REQ-021: identified as a bonus plant, not as a large tree');
      expect(find.text('Awarded at'), findsOneWidget);
      expect(find.text('10 sessions'), findsOneWidget);
      // The row a session's plant carries, and the one this plant has no
      // honest answer for.
      expect(find.text('Session'), findsNothing);
    });

    testWidgets('it is drawn as something no session could grow',
        (tester) async {
      // REQ-021's "visually distinct", as far as a placeholder can carry it: a
      // bonus plant stands as tall as the largest thing a session grows and
      // then reaches wider than it, so it can be picked out of a full garden.
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

  testWidgets('a bonus plant is not a session anybody sat through',
      (tester) async {
    // REQ-021: recorded as bonus and excluded from the statistics. The count on
    // the timer reads the sessions table, so an award cannot inflate it — this
    // is the test that says so out loud.
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
    // The garden counts what is growing in it and names the awards apart, so
    // eleven plants is never read as eleven afternoons of work.
    expect(
      find.bySemanticsLabel(
          'Your garden: 11 plants in 16 plots, 1 bonus plant among them.'),
      findsOneWidget,
    );
  });

  group('the celebration', () {
    testWidgets('follows the session that earned it rather than competing',
        (tester) async {
      final clock = FixedClock(testInstant);
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      // One short, so the milestone is reached by a session the user watches.
      await seedSessions(database, 9);

      await pumpApp(tester, clock: clock, database: database);
      expect(find.byType(MilestoneCard), findsNothing);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      // The session's own ending has the moment to itself: the chime, the
      // haptic and §5.3's growth spring, with nothing sliding up through them.
      expect(find.text('Session complete'), findsOneWidget);
      expect(find.byType(MilestoneCard), findsNothing,
          reason: 'the celebration does not compete with the completion');
      // And the plant is already in the ground while the user waits for it.
      expect(await awardedPlants(database), hasLength(1));

      await waitForCelebration(tester);

      expect(find.byType(MilestoneCard), findsOneWidget);
      expect(find.text('10 sessions of focus'), findsOneWidget);
      expect(find.text('Bonsai tree'), findsOneWidget);
    });

    testWidgets('waits for the bloom to finish before it rises',
        (tester) async {
      // §5.3's bloom and REQ-021's card are the app's two celebrations, and at
      // the tenth session they happen one after the other. Watched frame by
      // frame, because the failure this guards against is a card rising
      // through the middle of the petals — which a check before and after
      // would step straight over.
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
      expect(finished, isTrue, reason: 'and the bloom ran its course');
      expect(find.byType(MilestoneCard), findsNothing,
          reason: 'the card follows the bloom rather than meeting it');

      await waitForCelebration(tester);
      expect(find.byType(MilestoneCard), findsOneWidget,
          reason: 'and then it rises, as its own event');
    });

    testWidgets('never rises over a session that is running', (tester) async {
      final clock = FixedClock(testInstant);
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedSessions(database, 9);

      await pumpApp(tester, clock: clock, database: database);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      // The user goes straight into the next session rather than waiting for
      // the card. The award is owed, and it waits as long as it has to.
      await tester.tap(find.text('Plant another'));
      await tester.pump();
      await advance(tester, clock, const Duration(minutes: 10));
      await settle(tester);

      expect(find.byType(MilestoneCard), findsNothing,
          reason: 'no modal interrupts an active session');
      expect(await awardedPlants(database), hasLength(1),
          reason: 'held back from the screen, not held back from the garden');

      // And it arrives once the screen is the user's again.
      await advance(tester, clock, const Duration(minutes: 15));
      await settle(tester);
      await settle(tester);

      expect(find.byType(MilestoneCard), findsOneWidget);
    });

    testWidgets('shows a backlog one card at a time, oldest first',
        (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedSessions(database, 30);

      await pumpApp(tester, database: database);
      await waitForCelebration(tester);

      expect(find.text('10 sessions of focus'), findsOneWidget);
      expect(find.text('25 sessions of focus'), findsNothing,
          reason: 'one card at a time, not two on top of each other');

      await tester.tap(find.text('Lovely'));
      await waitForCelebration(tester);

      expect(find.text('25 sessions of focus'), findsOneWidget);

      await tester.tap(find.text('Lovely'));
      await waitForCelebration(tester);

      expect(find.byType(MilestoneCard), findsNothing);
    });

    testWidgets('is not shown again on the next launch', (tester) async {
      // A card is owed once. The plant is the award; the sheet is only how the
      // user is told about it, and a garden that re-celebrated everything on
      // every launch would be unusable at seven awards.
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
