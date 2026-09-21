import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/database_providers.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';

import '../support/analytics_fakes.dart';
import '../support/app_harness.dart';
import '../support/event_log.dart';

/// Session events through the real app, so the controller, port, clock and
/// table are all covered.
void main() {
  late FixedClock clock;
  late AppDatabase database;

  setUp(() {
    clock = FixedClock(testInstant);
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  Future<void> launch(WidgetTester tester, {Duration? sessionLength}) => pumpApp(
        tester,
        clock: clock,
        database: database,
        settings: sessionLength == null
            ? null
            : GardenSettings.defaults.withSessionLength(sessionLength),
      );

  testWidgets('starting a session records what it is and whether it is custom',
      (tester) async {
    await launch(tester);
    await startSession(tester);
    await settle(tester);

    final event = await theEventNamed(
      database,
      AnalyticsEventName.sessionStarted,
    );

    expect(event.parameters, {
      'duration_seconds': 1500,
      // 25 minutes is the Classic preset, so not custom.
      'is_custom': false,
    });
    expect(event.at, testInstant);
  });

  testWidgets('a length no preset names is recorded as custom', (tester) async {
    await launch(tester, sessionLength: const Duration(minutes: 37));
    await startSession(tester);
    await settle(tester);

    final event = await theEventNamed(
      database,
      AnalyticsEventName.sessionStarted,
    );

    expect(event.parameters['duration_seconds'], 2220);
    expect(event.parameters['is_custom'], isTrue);
  });

  testWidgets('completing a session records it, and the plant it grew',
      (tester) async {
    await launch(tester);
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);

    final completed = await theEventNamed(
      database,
      AnalyticsEventName.sessionCompleted,
    );
    expect(completed.parameters, {
      'duration_seconds': 1500,
      'paused_count': 0,
    });

    final grown = await theEventNamed(database, AnalyticsEventName.plantGrown);
    expect(grown.parameters['stage_reached'], 'mature');
    // Whatever species it is, it should match the plant in the garden.
    expect(
      PlantSpecies.values.map((species) => species.name),
      contains(grown.parameters['species']),
    );
  });

  testWidgets('a completion noticed twice records one plant', (tester) async {
    // The ticker sees the finish and the next start polls again; still one
    // plant.
    await launch(tester);
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);
    await startSession(tester);
    await settle(tester);

    expect(
      await eventsNamed(database, AnalyticsEventName.plantGrown),
      hasLength(1),
    );
  });

  testWidgets('holding a session records which pause it is', (tester) async {
    await launch(tester);
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 5));
    await pauseSession(tester);
    await advance(tester, clock, const Duration(minutes: 1));
    await resumeSession(tester);
    await advance(tester, clock, const Duration(minutes: 1));
    await pauseSession(tester);
    await settle(tester);

    final pauses = await eventsNamed(database, AnalyticsEventName.sessionPaused);

    expect(pauses.map((event) => event.parameters['pause_count']), [1, 2]);
    expect(pauses.first.parameters['duration_seconds'], 1500);
  });

  testWidgets('a session that was held says so when it completes',
      (tester) async {
    await launch(tester);
    await startSession(tester);
    await pauseSession(tester);
    await advance(tester, clock, const Duration(minutes: 2));
    await resumeSession(tester);
    // The pause pushed the end out by its two minutes.
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);

    final completed = await theEventNamed(
      database,
      AnalyticsEventName.sessionCompleted,
    );

    expect(completed.parameters['paused_count'], 1);
  });

  testWidgets('the pause count starts again with the next session',
      (tester) async {
    await launch(tester);
    await startSession(tester);
    await pauseSession(tester);
    await resumeSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);

    expect(
      (await eventsNamed(database, AnalyticsEventName.sessionCompleted))
          .map((event) => event.parameters['paused_count']),
      [1, 0],
    );
  });

  testWidgets('cancelling records how far the user got', (tester) async {
    await launch(tester);
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 4));
    await cancelSession(tester, confirm: true);

    final abandoned = await theEventNamed(
      database,
      AnalyticsEventName.sessionAbandoned,
    );

    expect(abandoned.parameters, {
      'duration_seconds': 1500,
      'elapsed_before_abandon_seconds': 240,
    });
  });

  testWidgets('changing your mind about cancelling records nothing',
      (tester) async {
    await launch(tester);
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 4));
    await cancelSession(tester, confirm: false);

    expect(
      await eventsNamed(database, AnalyticsEventName.sessionAbandoned),
      isEmpty,
    );
  });

  testWidgets('a force-quit is not an abandoned session', (tester) async {
    // Voided, not cancelled: the user didn't give up, the phone went away.
    await launch(tester);
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 4));
    await forceQuitApp(tester);

    expect(
      await eventsNamed(database, AnalyticsEventName.sessionAbandoned),
      isEmpty,
    );
  });

  testWidgets('a session whose events cannot be written runs anyway',
      (tester) async {
    // Log failures are reported and then ignored; the session carries on.
    final errors = captureErrors();

    await pumpApp(
      tester,
      clock: clock,
      database: database,
      overrides: [
        analyticsEventLogProvider.overrideWithValue(UnwritableEventLog()),
      ],
    );
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);

    expect(find.text('Session complete'), findsOneWidget);
    expect(await DriftPlantRepository(database).plants(), hasLength(1));
    expect(
      errors.map((error) => error.context.toString()),
      contains(startsWith('recording session_started')),
    );
  });
}
