import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/features/timer/progress_strip.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';

import '../../support/app_harness.dart';

// Pause, resume and cancel through the screen. The arithmetic is covered by
// the state machine tests.
void main() {
  late FixedClock clock;
  late AppDatabase database;

  setUp(() {
    clock = FixedClock(testInstant);
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  ProgressStrip strip(WidgetTester tester) =>
      tester.widget<ProgressStrip>(find.byType(ProgressStrip));

  PlantGrowth? growing(WidgetTester tester) =>
      tester.widget<GrowingPlant>(find.byType(GrowingPlant)).growth;

  Future<List<FocusSession>> completed() =>
      DriftSessionRepository(database).completedSessions();

  Future<FocusSession?> inFlight() =>
      DriftSessionRepository(database).inFlightSession();

  Future<void> openTimer(WidgetTester tester) =>
      pumpApp(tester, clock: clock, database: database);

  group('pausing', () {
    testWidgets('holds the countdown until resumed', (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));
      expect(find.text('15:00'), findsOneWidget);

      await pauseSession(tester);
      expect(find.text('Paused'), findsOneWidget);

      await advance(tester, clock, const Duration(minutes: 7));
      expect(find.text('15:00'), findsOneWidget,
          reason: 'countdown held for 7 minutes');

      await resumeSession(tester);
      expect(find.text('Focusing'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget, reason: 'nothing lost');

      await advance(tester, clock, const Duration(minutes: 1));
      expect(find.text('14:00'), findsOneWidget, reason: 'nothing gained');
    });

    testWidgets('finishes late by the paused time', (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));
      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 7));
      await resumeSession(tester);

      // 15 minutes left to run, 32 minutes after the anchor.
      await advance(tester, clock, const Duration(minutes: 15));
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      final session = (await completed()).single;
      expect(session.endedAt, testInstant.add(const Duration(minutes: 32)));
      expect(session.pausedDuration, const Duration(minutes: 7));
    });

    testWidgets('strip stops while paused', (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await pauseSession(tester);

      expect(strip(tester).progress, closeTo(0.2, 1e-9));
      await advance(tester, clock, const Duration(minutes: 10));
      expect(strip(tester).progress, closeTo(0.2, 1e-9));
    });

    testWidgets('plant grows at half speed', (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await pauseSession(tester);
      expect(growing(tester)!.stage, GrowthStage.sprout);

      // 15 paused minutes = 7.5 of growth: 12.5 of 25, where young starts.
      await advance(tester, clock, const Duration(minutes: 15));
      expect(growing(tester)!.stage, GrowthStage.young,
          reason: 'plant grew while paused');
      expect(strip(tester).progress, closeTo(0.2, 1e-9),
          reason: 'countdown did not move');
    });

    testWidgets('shows paused duration', (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await pauseSession(tester);

      await advance(tester, clock, const Duration(minutes: 2, seconds: 31));
      expect(
        find.textContaining('Paused for 02:31'),
        findsOneWidget,
      );
      expect(find.textContaining('half speed'), findsOneWidget);
    });

    testWidgets('pause is saved immediately', (tester) async {
      // Must be written now; a restore on next launch reads this row.
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));
      await pauseSession(tester);
      await settle(tester);

      final held = (await inFlight())!;
      expect(held.pausedSince, testInstant.add(const Duration(minutes: 4)));
      expect(held.pausedDuration, Duration.zero);

      await advance(tester, clock, const Duration(minutes: 3));
      await resumeSession(tester);
      await settle(tester);

      final running = (await inFlight())!;
      expect(running.pausedSince, isNull);
      expect(running.pausedDuration, const Duration(minutes: 3));
    });

    testWidgets('no pause on a completed session', (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      expect(find.text('Pause'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Plant another'), findsOneWidget);
    });
  });

  group('cancelling', () {
    testWidgets('confirms first, no-op on no', (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));

      await cancelSession(tester, confirm: false);

      expect(find.text('Focusing'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      expect(await inFlight(), isNotNull);
    });

    testWidgets('discards session and plant on yes', (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));

      await cancelSession(tester, confirm: true);

      expect(find.text('Ready to focus'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget,
          reason: 'countdown reset');
      expect(growing(tester), isNull, reason: 'plant removed');
      expect(find.text('No sessions grown yet'), findsOneWidget);

      expect(await DriftPlantRepository(database).plants(), isEmpty);
      expect(await completed(), isEmpty);
      expect(await inFlight(), isNull);
    });

    testWidgets('records cancelled, not voided', (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));
      await cancelSession(tester, confirm: true);

      final rows = await database
          .customSelect('SELECT outcome, ended_at FROM sessions')
          .get();
      expect(rows.single.read<String>('outcome'), 'cancelled');
      expect(rows.single.read<int>('ended_at'),
          testInstant.add(const Duration(minutes: 10)).millisecondsSinceEpoch ~/
              1000);
    });

    testWidgets('can cancel a paused session', (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 6));
      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 2));

      await cancelSession(tester, confirm: true);

      expect(find.text('Ready to focus'), findsOneWidget);
      final rows = await database
          .customSelect('SELECT outcome, paused_seconds FROM sessions')
          .get();
      expect(rows.single.read<String>('outcome'), 'cancelled');
      expect(rows.single.read<int>('paused_seconds'), 120);
    });

    testWidgets('session finishing under the dialog is kept', (tester) async {
      // The timer runs out under the dialog. Confirming then must not throw
      // away a finished session.
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 24));

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await advance(tester, clock, const Duration(minutes: 1));
      await tester.tap(find.text('Cancel session'));
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('1 session grown'), findsOneWidget);
      expect(await DriftPlantRepository(database).plants(), hasLength(1));
      expect((await completed()).single.outcome, SessionOutcome.completed);
    });

    testWidgets('next session after cancel starts clean', (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));
      await cancelSession(tester, confirm: true);

      await tester.tap(find.text('Plant it'));
      await tester.pump();

      expect(find.text('Focusing'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      expect(growing(tester)!.stage, GrowthStage.seed);

      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      expect(find.text('1 session grown'), findsOneWidget,
          reason: 'only the finished session counts');
    });
  });
}
