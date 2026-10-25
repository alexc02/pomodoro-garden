import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';

/// REQ-013, end to end: what a session survives, and what it does not.
///
/// Three ways an app stops being on screen, and the product treats them as
/// three different things:
///
/// | What happened | What the session does |
/// |---|---|
/// | Backgrounded | carries on, because the wall clock does |
/// | Killed by the system | comes back on the next launch, where the clock says |
/// | Force-quit by the user | is voided, and grows nothing |
///
/// The database is a real file rather than an in-memory one wherever a launch
/// has to survive the one before it. An in-memory database would prove only
/// that the app re-reads its own process.
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

  /// Opens the app on the file, closing the connection when the test ends.
  Future<AppDatabase> launch(
    WidgetTester tester,
    FixedClock clock, {
    AppDatabase? reusing,
  }) async {
    final database = reusing ?? AppDatabase.inFile(file);
    await pumpApp(tester, clock: clock, database: database);
    return database;
  }

  group('backgrounding is not an interruption', () {
    testWidgets('a session backgrounded and brought back reads from the wall '
        'clock, not from where the screen left off', (tester) async {
      final clock = FixedClock(testInstant);
      final database = await launch(tester, clock);
      addTearDown(database.close);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 2));
      expect(find.text('23:00'), findsOneWidget);

      await sendToBackground(tester);
      // Eleven minutes in a pocket. No frames, no ticks, nothing running.
      clock.advance(const Duration(minutes: 11));
      await bringToForeground(tester);
      await settle(tester);

      expect(find.text('Focusing'), findsOneWidget,
          reason: 'the session was never interrupted');
      expect(find.text('12:00'), findsOneWidget,
          reason: 'thirteen minutes gone, not the two the screen last drew');
      expect(growing(tester)!.stage, GrowthStage.young);
    });

    testWidgets('a session that finished in the background is complete on '
        'return', (tester) async {
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

    testWidgets('a paused session stays paused across a backgrounding',
        (tester) async {
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
          reason: 'a held countdown is held in the background too');
      // Five focused minutes plus half of thirty paused: 20 of 25, which is
      // where maturing begins. The plant went on growing in the user's pocket.
      expect(growing(tester)!.stage, GrowthStage.maturing);
    });
  });

  group('a cold start mid-session', () {
    testWidgets('restores the session where the clock says it should be',
        (tester) async {
      final clock = FixedClock(testInstant);
      final firstLaunch = await launch(tester, clock);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));

      // Killed by the system, with no warning: no chance to write anything.
      await killApp(tester);
      await firstLaunch.close();

      clock.advance(const Duration(minutes: 11));

      final secondLaunch = await launch(tester, clock);
      addTearDown(secondLaunch.close);
      await tapTab(tester, AppTab.timer);

      expect(find.text('Focusing'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget,
          reason: 'fifteen minutes gone, counted from the anchor on disk');
      expect(growing(tester)!.stage, GrowthStage.young,
          reason: 'and the plant is as grown as those fifteen minutes made it');
    });

    testWidgets('the restored session runs on, and completes, and is planted',
        (tester) async {
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
          reason: 'the same session, not a new one anchored at the relaunch');
      expect(stored.single.endedAt, testInstant.add(const Duration(minutes: 25)));
      expect(await DriftPlantRepository(secondLaunch).plants(), hasLength(1));
    });

    testWidgets('a session restored while held comes back held', (tester) async {
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

      // And it can be picked up where it was left.
      await resumeSession(tester);
      await advance(tester, clock, const Duration(minutes: 1));
      expect(find.text('19:00'), findsOneWidget);
    });

    testWidgets('nothing is restored when nothing was running', (tester) async {
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

  group('force-quitting voids the session', () {
    testWidgets('on next launch there is no session, no plant and no record',
        (tester) async {
      final clock = FixedClock(testInstant);
      final firstLaunch = await launch(tester, clock);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 12));

      await forceQuitApp(tester);
      await firstLaunch.close();

      // Long enough that a session left open would have run out and, on being
      // restored, claimed a plant.
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

    testWidgets('the voided session is told apart from a cancelled one',
        (tester) async {
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
          reason: 'nobody decided to end it; the app went away');
    });

    testWidgets('force-quitting a paused session voids that too',
        (tester) async {
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

    testWidgets('a session that had already finished keeps its plant',
        (tester) async {
      // The user sat through the whole thing and then quit the app. The
      // session was over before the force-quit, so there was nothing left in
      // flight to void — and taking the plant back would be theft.
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

    testWidgets('quitting with nothing running leaves nothing behind',
        (tester) async {
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

  group('a device clock that changes under a session', () {
    testWidgets('a correction backwards does not put the session ahead of its '
        'anchor', (tester) async {
      // A clock a test can move in either direction; the app's own [FixedClock]
      // refuses to rewind, which is exactly the case this needs.
      final clock = _RewindableClock(testInstant);
      final database = AppDatabase.inFile(file);
      addTearDown(database.close);
      await pumpApp(tester, clock: clock, database: database);

      await startSession(tester);
      clock.set(testInstant.add(const Duration(minutes: 10)));
      await tester.pump(const Duration(minutes: 10));
      expect(find.text('15:00'), findsOneWidget);

      // NTP corrects the phone two hours backwards, mid-session.
      clock.set(testInstant.subtract(const Duration(hours: 2)));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('25:00'), findsOneWidget,
          reason: 'clamped at the start, never past it');
      expect(find.text('Focusing'), findsOneWidget,
          reason: 'and still a session, not a broken one');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a timezone change is not a change to the session',
        (tester) async {
      final clock = _RewindableClock(testInstant);
      final database = AppDatabase.inFile(file);
      addTearDown(database.close);
      await pumpApp(tester, clock: clock, database: database);

      await startSession(tester);
      clock.set(testInstant.add(const Duration(minutes: 10)));
      await tester.pump(const Duration(minutes: 10));

      // The same instant, arrived at from nine timezones east. `testInstant` is
      // 2026-08-11 09:41 UTC, so ten minutes on is 18:51+09:00.
      clock.set(DateTime.parse('2026-08-11T18:51:00+09:00'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('15:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// A [Clock] a test can move in either direction.
///
/// [FixedClock] deliberately refuses to rewind — no rule in the domain is
/// defined against time running backwards — so a test about a device clock
/// being corrected has to bring its own.
final class _RewindableClock implements Clock {
  _RewindableClock(DateTime instant) : _instant = instant.toUtc();

  DateTime _instant;

  @override
  DateTime now() => _instant;

  void set(DateTime instant) => _instant = instant.toUtc();
}
