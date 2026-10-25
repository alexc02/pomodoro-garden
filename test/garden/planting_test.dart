import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_plant_repository.dart';
import 'package:pomodoro_garden/src/garden/plant_providers.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../support/app_harness.dart';

/// The end of the chain this ticket builds: the plant the user watched grow is
/// the plant that is written down.
///
/// The screen tests cover what growing looks like; these cover what is left
/// behind, driven through the real app rather than through the repository, so
/// the wiring between a completion and a planting is what is under test.
void main() {
  late FixedClock clock;

  setUp(() => clock = FixedClock(testInstant));

  /// Runs one session of [length] to completion and hands back the garden.
  Future<List<Plant>> growOne(
    WidgetTester tester,
    AppDatabase database, {
    Duration length = const Duration(minutes: 25),
  }) async {
    await pumpApp(
      tester,
      clock: clock,
      database: database,
      settings: GardenSettings.defaults.withSessionLength(length),
    );
    await startSession(tester);
    await advance(tester, clock, length);
    await settle(tester);

    return DriftPlantRepository(database).plants();
  }

  testWidgets('a completed session leaves a plant of what it grew',
      (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    final garden = await growOne(
      tester,
      database,
      length: const Duration(minutes: 90),
    );

    expect(garden, hasLength(1));
    expect(garden.single.type, PlantType.largeTree, reason: '90 minutes');
    expect(garden.single.stage, GrowthStage.mature);
    expect(garden.single.plantedAt, testInstant);
    expect(garden.single.sessionDuration, const Duration(minutes: 90));
    expect(garden.single.species.type, PlantType.largeTree);
  });

  testWidgets('the plant records the session that grew it', (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    final garden = await growOne(tester, database);

    // The harness numbers ids from one; the session is the first thing the app
    // asks for an id, the plant the second.
    expect(garden.single.sessionId, '1');
    expect(garden.single.id, isNot(garden.single.sessionId));
  });

  testWidgets('a session that never finished grows nothing', (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    await pumpApp(tester, clock: clock, database: database);
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 24));

    expect(await DriftPlantRepository(database).plants(), isEmpty);
  });

  testWidgets('noticing the same completion twice grows one plant',
      (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    await growOne(tester, database);
    // The tap that starts the next session polls for the last one's completion
    // before it starts — a second chance to plant the same session.
    await tester.tap(find.text('Plant another'));
    await settle(tester);

    expect(await DriftPlantRepository(database).plants(), hasLength(1));
  });

  testWidgets('two sessions grow two plants', (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    await growOne(tester, database);
    await tester.tap(find.text('Plant another'));
    await tester.pump();
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);

    final garden = await DriftPlantRepository(database).plants();
    expect(garden, hasLength(2));
    expect(garden.map((plant) => plant.id).toSet(), hasLength(2));
    expect(garden.map((plant) => plant.sessionId).toSet(), hasLength(2));
  });

  testWidgets('the first plant goes into the middle of the garden',
      (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    final garden = await growOne(tester, database);

    expect(garden.single.plot, GardenPlots.inPlacementOrder.first);
  });

  testWidgets('each session takes the nearest plot still free', (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    await growOne(tester, database);
    for (var more = 0; more < 3; more++) {
      await tester.tap(find.text('Plant another'));
      await tester.pump();
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
    }

    final garden = await DriftPlantRepository(database).plants();
    expect(garden, hasLength(4));
    // Oldest last: the repository hands them back most recently planted first.
    expect(
      garden.reversed.map((plant) => plant.plot),
      GardenPlots.inPlacementOrder.take(4),
    );
  });

  testWidgets('the garden provider refreshes when a session completes',
      (tester) async {
    // `plantsProvider` is what ticket 07's garden will watch. It is wired up
    // and invalidated here, so this test is what says the invalidation works —
    // a garden that only refreshed on relaunch would look right in every
    // screenshot and wrong in use.
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    await pumpApp(tester, clock: clock, database: database);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

    expect(await container.read(plantsProvider.future), isEmpty);

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);

    expect(await container.read(plantsProvider.future), hasLength(1));
  });

  group('after a relaunch', () {
    late Directory directory;
    late File file;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('pomodoro_garden_test');
      file = File('${directory.path}/pomodoro_garden.sqlite');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    testWidgets('the plant is still the same plant', (tester) async {
      // The product's entire emotional premise: the garden is there tomorrow.
      final firstLaunch = AppDatabase.inFile(file);
      final grown = (await growOne(tester, firstLaunch)).single;

      await killApp(tester);
      await firstLaunch.close();

      final secondLaunch = AppDatabase.inFile(file);
      addTearDown(secondLaunch.close);
      await pumpApp(tester, clock: clock, database: secondLaunch);
      await tapTab(tester, AppTab.timer);

      expect((await DriftPlantRepository(secondLaunch).plants()).single, grown,
          reason: 'the same species, the same date, the same session');
    });
  });
}
