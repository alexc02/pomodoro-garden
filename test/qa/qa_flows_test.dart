// Exploratory QA suite: end-to-end flows driven through the real widget tree,
// the real Drift database (in memory) and a controllable clock. Each test is a
// numbered test case from docs/qa/test-plan.md.
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/features/settings/reset_garden.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';

void main() {
  late FixedClock clock;
  late AppDatabase db;

  setUp(() {
    clock = FixedClock(testInstant);
    db = AppDatabase.forTesting();
  });
  tearDown(() => db.close());

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<int>('n');

  Future<void> launch(WidgetTester tester, {GardenSettings? settings}) =>
      pumpApp(tester, clock: clock, database: db, settings: settings);

  Future<void> relaunch(WidgetTester tester) async {
    await killApp(tester);
    await launch(tester);
  }

  Future<void> finishSession(WidgetTester tester,
      {Duration length = const Duration(minutes: 25)}) async {
    await startSession(tester);
    await advance(tester, clock, length);
    await settle(tester);
  }

  /// Takes the break on offer and lets it run out, then skips nothing.
  Future<void> takeAndFinishBreak(WidgetTester tester, Duration length) async {
    await tester.tap(find.textContaining('Take a'));
    await settle(tester);
    await advance(tester, clock, length);
    await settle(tester);
  }

  group('Timer core', () {
    testWidgets('TC-01 idle timer shows the default 25:00 and "Plant it"',
        (tester) async {
      await launch(tester);
      await tapTab(tester, AppTab.timer);
      expect(find.text('Ready to focus'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('Plant it'), findsOneWidget);
    });

    testWidgets('TC-02 a started session counts down from the wall clock',
        (tester) async {
      await launch(tester);
      await startSession(tester);
      expect(find.text('Focusing'), findsOneWidget);
      await advance(tester, clock, const Duration(minutes: 1));
      expect(find.text('24:00'), findsOneWidget);
    });

    testWidgets('TC-03 a completed session plants one plant and offers a break',
        (tester) async {
      await launch(tester);
      await finishSession(tester);
      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('1 session grown'), findsOneWidget);
      expect(find.text('Take a 5 min break'), findsOneWidget);
      expect(await count('SELECT COUNT(*) AS n FROM plants'), 1);
    });

    testWidgets('TC-04 pause holds the countdown; completion moves out by '
        'the paused time', (tester) async {
      await launch(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 3));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      await resumeSession(tester);
      await advance(tester, clock, const Duration(minutes: 19, seconds: 59));
      expect(find.text('Focusing'), findsOneWidget);
      await advance(tester, clock, const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('Session complete'), findsOneWidget);
    });

    testWidgets('TC-05 cancelling a session plants nothing', (tester) async {
      await launch(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));
      await cancelSession(tester, confirm: true);
      expect(find.text('Ready to focus'), findsOneWidget);
      expect(find.text('No sessions grown yet'), findsOneWidget);
      expect(await count('SELECT COUNT(*) AS n FROM plants'), 0);
    });

    testWidgets('TC-06 "Keep focusing" in the cancel dialog keeps the session',
        (tester) async {
      await launch(tester);
      await startSession(tester);
      await cancelSession(tester, confirm: false);
      expect(find.text('Focusing'), findsOneWidget);
    });

    testWidgets('TC-07 double-tapping "Plant it" starts exactly one session '
        'without an error', (tester) async {
      await launch(tester);
      await tapTab(tester, AppTab.timer);
      await tester.tap(find.text('Plant it'));
      await tester.tap(find.text('Plant it'));
      await tester.pump();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Focusing'), findsOneWidget);
      expect(await count('SELECT COUNT(*) AS n FROM sessions'), 1);
    });

    testWidgets('TC-08 the idle countdown follows the session-length setting',
        (tester) async {
      await launch(tester,
          settings: GardenSettings.defaults
              .withSessionLength(const Duration(minutes: 50)));
      await tapTab(tester, AppTab.timer);
      expect(find.text('50:00'), findsOneWidget);
    });
  });

  group('Interruptions', () {
    testWidgets('TC-09 force-quit voids the session; nothing is planted',
        (tester) async {
      await launch(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await forceQuitApp(tester);
      clock.advance(const Duration(minutes: 30));
      await launch(tester);
      await tapTab(tester, AppTab.timer);
      expect(find.text('Ready to focus'), findsOneWidget);
      expect(await count('SELECT COUNT(*) AS n FROM plants'), 0);
    });

    testWidgets('TC-10 a system kill restores the session; it completes',
        (tester) async {
      await launch(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await killApp(tester);
      clock.advance(const Duration(minutes: 30));
      await launch(tester);
      await tapTab(tester, AppTab.timer);
      await settle(tester);
      expect(await count('SELECT COUNT(*) AS n FROM plants'), 1);
    });
  });

  group('Pomodoro cycle', () {
    testWidgets('TC-11 the 4th session in one run offers the long break',
        (tester) async {
      await launch(tester);
      for (var i = 0; i < 3; i++) {
        await finishSession(tester);
        await takeAndFinishBreak(tester, const Duration(minutes: 5));
      }
      await finishSession(tester);
      expect(find.text('Take a 15 min long break'), findsOneWidget);
    });

    testWidgets('TC-12 the cycle position survives the app being relaunched '
        'between sessions', (tester) async {
      await launch(tester);
      for (var i = 0; i < 3; i++) {
        await finishSession(tester);
        await takeAndFinishBreak(tester, const Duration(minutes: 5));
      }
      // The OS reclaims the backgrounded app (or the user reopens it) before
      // the fourth session.
      await relaunch(tester);
      await finishSession(tester);
      expect(find.text('Take a 15 min long break'), findsOneWidget,
          reason: 'three sessions were completed before the relaunch, so the '
              'fourth earns the long break');
    });

    testWidgets('TC-13 auto-start break begins the break on completion',
        (tester) async {
      await launch(tester,
          settings: GardenSettings.defaults.withAutoStartBreak(enabled: true));
      await finishSession(tester);
      expect(find.text('On a break'), findsOneWidget);
    });

    testWidgets('TC-14 skipping a break returns to an idle timer',
        (tester) async {
      await launch(tester);
      await finishSession(tester);
      await tester.tap(find.textContaining('Take a'));
      await settle(tester);
      await tester.tap(find.text('Skip break'));
      await settle(tester);
      expect(find.text('Ready to focus'), findsOneWidget);
    });

    testWidgets('TC-15 after a break runs out, "Break over" and "Plant it" '
        'are shown', (tester) async {
      await launch(tester);
      await finishSession(tester);
      await takeAndFinishBreak(tester, const Duration(minutes: 5));
      expect(find.text('Break over'), findsOneWidget);
      expect(find.text('Plant it'), findsOneWidget);
      // By design (break_and_cycle_test.dart:146): the spent break reads 00:00.
      expect(find.text('00:00'), findsOneWidget);
    });
  });

  group('Garden & milestones', () {
    testWidgets('TC-16 the 10th completed session awards the bonsai',
        (tester) async {
      await launch(tester);
      for (var i = 0; i < 10; i++) {
        await finishSession(tester, length: const Duration(minutes: 25));
        // Move on so the next "Plant another" starts fresh.
      }
      await settle(tester, over: const Duration(seconds: 4));
      expect(
          await count(
              'SELECT COUNT(*) AS n FROM plants WHERE milestone_sessions = 10'),
          1);
      expect(await count('SELECT COUNT(*) AS n FROM plants'), 11);
    });
  });

  group('Garden reset', () {
    Future<void> openReset(WidgetTester tester) async {
      await tapTab(tester, AppTab.settings);
      await scrollWithin(
          tester, find.byType(SettingsScreen), ResetGardenKeys.control);
    }

    testWidgets('TC-17 reset clears plants and sessions', (tester) async {
      await launch(tester);
      await finishSession(tester);
      await tester.tap(find.textContaining('Take a'));
      await settle(tester);
      await tester.tap(find.text('Skip break'));
      await settle(tester);
      await openReset(tester);
      await tester.tap(find.byKey(ResetGardenKeys.control));
      await settle(tester);
      await tester.tap(find.text('Continue'));
      await settle(tester);
      await tester.tap(find.text('Reset my garden'));
      await settle(tester);
      expect(await count('SELECT COUNT(*) AS n FROM plants'), 0);
      expect(await count('SELECT COUNT(*) AS n FROM sessions'), 0);
    });

    testWidgets('TC-18 after a reset, the cycle starts again from session one',
        (tester) async {
      await launch(tester);
      for (var i = 0; i < 3; i++) {
        await finishSession(tester);
        await takeAndFinishBreak(tester, const Duration(minutes: 5));
      }
      await openReset(tester);
      await tester.tap(find.byKey(ResetGardenKeys.control));
      await settle(tester);
      await tester.tap(find.text('Continue'));
      await settle(tester);
      await tester.tap(find.text('Reset my garden'));
      await settle(tester);
      expect(await count('SELECT COUNT(*) AS n FROM sessions'), 0);
      await finishSession(tester);
      expect(find.text('Take a 5 min break'), findsOneWidget,
          reason: 'the garden and every stat were cleared; the first session '
              'after a reset is session one of the cycle');
    });

    testWidgets('TC-19 on "Session complete" the reset note describes the '
        'actual state', (tester) async {
      await launch(tester);
      await finishSession(tester);
      await tapTab(tester, AppTab.settings);
      await scrollWithin(
          tester, find.byType(SettingsScreen), ResetGardenKeys.heldBack);
      final note = tester.widget<Text>(find.descendant(
          of: find.byKey(ResetGardenKeys.heldBack),
          matching: find.byType(Text)));
      expect(note.data, isNot(contains('is running')),
          reason: 'nothing is running: the session has completed');
    });
  });

  group('Journal', () {
    testWidgets('TC-20 lifetime totals count completed sessions only',
        (tester) async {
      await launch(tester);
      await finishSession(tester);
      await startSession(tester);
      await cancelSession(tester, confirm: true);
      final row = await db.customSelect(
        'SELECT COUNT(*) AS n FROM sessions WHERE completed = ?',
        variables: [const Variable<bool>(true)],
      ).getSingle();
      expect(row.read<int>('n'), 1);
    });
  });
}
