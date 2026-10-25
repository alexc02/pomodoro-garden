import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_plant_repository.dart';
import 'package:pomodoro_garden/src/data/drift_session_repository.dart';
import 'package:pomodoro_garden/src/features/timer/progress_strip.dart';
import 'package:pomodoro_garden/src/garden/growing_plant.dart';

import '../../support/app_harness.dart';

/// Pausing, resuming and cancelling, driven through the screen the user
/// actually taps.
///
/// The state machine's own tests own the arithmetic; what these own is that the
/// buttons are wired to it, that the confirmation is real, and that what ends up
/// in the database is what the user did.
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
    testWidgets('holds the countdown, and resuming picks it up again',
        (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));
      expect(find.text('15:00'), findsOneWidget);

      await pauseSession(tester);
      expect(find.text('Paused'), findsOneWidget);

      await advance(tester, clock, const Duration(minutes: 7));
      expect(find.text('15:00'), findsOneWidget,
          reason: 'seven minutes passed and the countdown did not move');

      await resumeSession(tester);
      expect(find.text('Focusing'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget, reason: 'nothing lost');

      await advance(tester, clock, const Duration(minutes: 1));
      expect(find.text('14:00'), findsOneWidget, reason: 'and nothing gained');
    });

    testWidgets('a paused session finishes late by what it spent paused',
        (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));
      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 7));
      await resumeSession(tester);

      // 15 minutes of focus still to run, 32 minutes after the anchor.
      await advance(tester, clock, const Duration(minutes: 15));
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      final session = (await completed()).single;
      expect(session.endedAt, testInstant.add(const Duration(minutes: 32)));
      expect(session.pausedDuration, const Duration(minutes: 7));
    });

    testWidgets('the strip stops filling while the countdown is held',
        (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await pauseSession(tester);

      expect(strip(tester).progress, closeTo(0.2, 1e-9));
      await advance(tester, clock, const Duration(minutes: 10));
      expect(strip(tester).progress, closeTo(0.2, 1e-9));
    });

    testWidgets('the plant carries on growing, at half speed — REQ-009',
        (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await pauseSession(tester);
      expect(growing(tester)!.stage, GrowthStage.sprout);

      // 15 paused minutes buy 7½ of growth: 12½ of 25, where young begins.
      await advance(tester, clock, const Duration(minutes: 15));
      expect(growing(tester)!.stage, GrowthStage.young,
          reason: 'the plant advanced while the countdown stood still');
      expect(strip(tester).progress, closeTo(0.2, 1e-9),
          reason: 'and the countdown really did stand still');
    });

    testWidgets('the screen says how long the session has been held',
        (tester) async {
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

    testWidgets('the pause is recorded as it happens, not only at the end',
        (tester) async {
      // The record has to be right *now*, because the app may not get another
      // chance to write it: a session restored on the next launch is restored
      // from exactly this row.
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

    testWidgets('a completed session offers nothing to pause', (tester) async {
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
    testWidgets('asks first, and does nothing if the answer is no',
        (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));

      await cancelSession(tester, confirm: false);

      expect(find.text('Focusing'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      expect(await inFlight(), isNotNull);
    });

    testWidgets('discards the session and its plant when the answer is yes',
        (tester) async {
      await openTimer(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));

      await cancelSession(tester, confirm: true);

      expect(find.text('Ready to focus'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget,
          reason: 'the countdown is back to the length of the next session');
      expect(growing(tester), isNull, reason: 'the soil is bare again');
      expect(find.text('No sessions grown yet'), findsOneWidget);

      expect(await DriftPlantRepository(database).plants(), isEmpty);
      expect(await completed(), isEmpty);
      expect(await inFlight(), isNull);
    });

    testWidgets('a cancelled session is recorded as cancelled, not voided',
        (tester) async {
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

    testWidgets('a paused session can be cancelled, pause and all',
        (tester) async {
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

    testWidgets('a session that finishes while the dialog is open is kept, not '
        'thrown away', (tester) async {
      // The race the confirmation opens: the user taps CANCEL with a minute to
      // go, hesitates, and the timer runs out under the dialog. Confirming then
      // does not un-earn the session — they sat through the whole thing, and
      // the plant is theirs. Cancelling something already finished is not a
      // thing that can be done.
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

    testWidgets('the next session after a cancellation starts clean',
        (tester) async {
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
          reason: 'the cancelled one is not counted, the finished one is');
    });
  });
}
