import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';

// Interruptions end to end:
// - backgrounded: carries on with the wall clock
// - killed by the system: restored on next launch
// - force-quit: voided, grows nothing
//
// Uses a real database file where a launch has to survive the previous one.
void main() {
  late Directory directory;
  late File file;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('pip_garden_test');
    file = File('${directory.path}/pip_garden.sqlite');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  PlantGrowth? growing(WidgetTester tester) =>
      tester.widget<GrowingPlant>(find.byType(GrowingPlant)).growth;

  /// Opens the app on [file], closing the connection at teardown.
  Future<AppDatabase> launch(
    WidgetTester tester,
    FixedClock clock, {
    AppDatabase? reusing,
  }) async {
    final database = reusing ?? AppDatabase.inFile(file);
    await pumpApp(tester, clock: clock, database: database);
    return database;
  }

  group('backgrounding', () {
    testWidgets('resumes from the wall clock', (tester) async {
      final clock = FixedClock(testInstant);
      final database = await launch(tester, clock);
      addTearDown(database.close);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 2));
      expect(find.text('23:00'), findsOneWidget);

      await sendToBackground(tester);
      // 11 minutes backgrounded, no frames.
      clock.advance(const Duration(minutes: 11));
      await bringToForeground(tester);
      await settle(tester);

      expect(find.text('Focusing'), findsOneWidget,
          reason: 'the session was never interrupted');
      expect(find.text('12:00'), findsOneWidget,
          reason: '13 minutes elapsed, not 2');
      expect(growing(tester)!.stage, GrowthStage.young);
    });

    testWidgets('finished in the background is complete on return',
        (tester) async {
      final clock = FixedClock(testInstant);
      final database = await launch(tester, clock);
      addTearDown(database.close);

      await startSession(tester);
      await sendToBackground(tester);
      clock.advance(const Duration(minutes: 40));
      await bringToForeground(tester);
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('1 session grown'), findsOneWidget);
      expect(await DriftPlantRepository(database).plants(), hasLength(1));
    });

    testWidgets('paused session stays paused', (tester) async {
      final clock = FixedClock(testInstant);
      final database = await launch(tester, clock);
      addTearDown(database.close);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await pauseSession(tester);

      await sendToBackground(tester);
      clock.advance(const Duration(minutes: 30));
      await bringToForeground(tester);
      await settle(tester);

      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget,
          reason: 'stays paused in the background');
      // 5 focused + half of 30 paused = 20 of 25, where maturing starts.
      expect(growing(tester)!.stage, GrowthStage.maturing);
    });
  });

  group('cold start mid-session', () {
    testWidgets('restores the session at the right time', (tester) async {
      final clock = FixedClock(testInstant);
      final firstLaunch = await launch(tester, clock);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));

      // Killed with no chance to write anything.
      await killApp(tester);
      await firstLaunch.close();

      clock.advance(const Duration(minutes: 11));

      final secondLaunch = await launch(tester, clock);
      addTearDown(secondLaunch.close);
      await tapTab(tester, AppTab.timer);

      expect(find.text('Focusing'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget,
          reason: '15 minutes from the stored anchor');
      expect(growing(tester)!.stage, GrowthStage.young,
          reason: 'plant growth matches 15 minutes');
    });

    testWidgets('restored session completes and plants', (tester) async {
      final clock = FixedClock(testInstant);
      final firstLaunch = await launch(tester, clock);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));
      await killApp(tester);
      await firstLaunch.close();

      final secondLaunch = await launch(tester, clock);
      addTearDown(secondLaunch.close);
      await tapTab(tester, AppTab.timer);

      await advance(tester, clock, const Duration(minutes: 21));
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('1 session grown'), findsOneWidget);

      final stored =
          await DriftSessionRepository(secondLaunch).completedSessions();
      expect(stored.single.startedAt, testInstant,
          reason: 'same session, not a new one');
      expect(stored.single.endedAt, testInstant.add(const Duration(minutes: 25)));
      expect(await DriftPlantRepository(secondLaunch).plants(), hasLength(1));
    });

    testWidgets('paused session is restored paused', (tester) async {
      final clock = FixedClock(testInstant);
      final firstLaunch = await launch(tester, clock);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await pauseSession(tester);
      await settle(tester);
      await killApp(tester);
      await firstLaunch.close();

      clock.advance(const Duration(minutes: 6));

      final secondLaunch = await launch(tester, clock);
      addTearDown(secondLaunch.close);
      await tapTab(tester, AppTab.timer);

      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      await resumeSession(tester);
      await advance(tester, clock, const Duration(minutes: 1));
      expect(find.text('19:00'), findsOneWidget);
    });

    testWidgets('nothing restored when idle', (tester) async {
      final clock = FixedClock(testInstant);
      final firstLaunch = await launch(tester, clock);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      await killApp(tester);
      await firstLaunch.close();

      final secondLaunch = await launch(tester, clock);
      addTearDown(secondLaunch.close);
      await tapTab(tester, AppTab.timer);

      expect(find.text('Ready to focus'), findsOneWidget);
      expect(find.text('1 session grown'), findsOneWidget);
    });
  });

  group('force-quit', () {
    testWidgets('voids the session on next launch', (tester) async {
      final clock = FixedClock(testInstant);
      final firstLaunch = await launch(tester, clock);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 12));

      await forceQuitApp(tester);
      await firstLaunch.close();

      // Long enough that a restored session would have finished and planted.
      clock.advance(const Duration(minutes: 30));

      final secondLaunch = await launch(tester, clock);
      addTearDown(secondLaunch.close);
      await tapTab(tester, AppTab.timer);

      expect(find.text('Ready to focus'), findsOneWidget,
          reason: 'no active session');
      expect(find.text('25:00'), findsOneWidget);
      expect(growing(tester), isNull, reason: 'no plant on the timer');
      expect(find.text('No sessions grown yet'), findsOneWidget);

      expect(await DriftPlantRepository(secondLaunch).plants(), isEmpty,
          reason: 'no plant in the garden');
      expect(await DriftSessionRepository(secondLaunch).completedSessions(),
          isEmpty, reason: 'no completed-session record');
      expect(await DriftSessionRepository(secondLaunch).inFlightSession(),
          isNull);
    });

    testWidgets('records voided, not cancelled', (tester) async {
      final clock = FixedClock(testInstant);
      final firstLaunch = await launch(tester, clock);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 12));
      await forceQuitApp(tester);
      await firstLaunch.close();

      final secondLaunch = AppDatabase.inFile(file);
      addTearDown(secondLaunch.close);

      final rows = await secondLaunch
          .customSelect('SELECT outcome FROM sessions')
          .get();
      expect(rows.single.read<String>('outcome'), 'voided',
          reason: 'voided, not cancelled');
    });

    testWidgets('voids a paused session', (tester) async {
      final clock = FixedClock(testInstant);
      final firstLaunch = await launch(tester, clock);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 6));
      await pauseSession(tester);
      await forceQuitApp(tester);
      await firstLaunch.close();

      final secondLaunch = await launch(tester, clock);
      addTearDown(secondLaunch.close);
      await tapTab(tester, AppTab.timer);

      expect(find.text('Ready to focus'), findsOneWidget);
      expect(await DriftSessionRepository(secondLaunch).inFlightSession(),
          isNull);
    });

    testWidgets('keeps the plant of a finished session', (tester) async {
      // The session ended before the quit, so nothing to void.
      final clock = FixedClock(testInstant);
      final firstLaunch = await launch(tester, clock);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      await forceQuitApp(tester);
      await firstLaunch.close();

      final secondLaunch = await launch(tester, clock);
      addTearDown(secondLaunch.close);
      await tapTab(tester, AppTab.timer);

      expect(find.text('1 session grown'), findsOneWidget);
      expect(await DriftPlantRepository(secondLaunch).plants(), hasLength(1));
    });

    testWidgets('no-op when idle', (tester) async {
      final clock = FixedClock(testInstant);
      final firstLaunch = await launch(tester, clock);
      await tapTab(tester, AppTab.timer);
      await forceQuitApp(tester);
      await firstLaunch.close();

      final secondLaunch = AppDatabase.inFile(file);
      addTearDown(secondLaunch.close);

      expect(await secondLaunch.customSelect('SELECT id FROM sessions').get(),
          isEmpty);
    });
  });

  group('device clock changes', () {
    testWidgets('backwards correction clamps at the anchor', (tester) async {
      // FixedClock refuses to rewind, so use our own.
      final clock = _RewindableClock(testInstant);
      final database = AppDatabase.inFile(file);
      addTearDown(database.close);
      await pumpApp(tester, clock: clock, database: database);

      await startSession(tester);
      clock.set(testInstant.add(const Duration(minutes: 10)));
      await tester.pump(const Duration(minutes: 10));
      expect(find.text('15:00'), findsOneWidget);

      // Clock corrected two hours back mid-session.
      clock.set(testInstant.subtract(const Duration(hours: 2)));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('25:00'), findsOneWidget,
          reason: 'clamped at the start, never past it');
      expect(find.text('Focusing'), findsOneWidget,
          reason: 'session still valid');
      expect(tester.takeException(), isNull);
    });

    testWidgets('timezone change has no effect', (tester) async {
      final clock = _RewindableClock(testInstant);
      final database = AppDatabase.inFile(file);
      addTearDown(database.close);
      await pumpApp(tester, clock: clock, database: database);

      await startSession(tester);
      clock.set(testInstant.add(const Duration(minutes: 10)));
      await tester.pump(const Duration(minutes: 10));

      // Same instant from UTC+9. testInstant is 09:41 UTC, so +10 min is
      // 18:51+09:00.
      clock.set(DateTime.parse('2026-08-11T18:51:00+09:00'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('15:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// A [Clock] that can move backwards, which [FixedClock] refuses to do.
final class _RewindableClock implements Clock {
  _RewindableClock(DateTime instant) : _instant = instant.toUtc();

  DateTime _instant;

  @override
  DateTime now() => _instant;

  void set(DateTime instant) => _instant = instant.toUtc();
}
