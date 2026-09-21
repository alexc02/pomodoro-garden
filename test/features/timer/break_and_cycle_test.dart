import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/design/garden_colors.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/features/timer/progress_strip.dart';
import 'package:pip_garden/src/features/timer/timer_screen.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/announcement_fakes.dart';
import '../../support/app_harness.dart';

// Breaks and the cycle, seen through the screen, chime and notification.
// The state machine itself is tested in
// packages/pomodoro_domain/test/session/break_cycle_test.dart.
void main() {
  late FixedClock clock;

  setUp(() => clock = FixedClock(testInstant));

  const session = Duration(minutes: 25);
  const shortBreak = Duration(minutes: 5);

  ProgressStrip strip(WidgetTester tester) =>
      tester.widget<ProgressStrip>(find.byType(ProgressStrip));

  PlantGrowth? growing(WidgetTester tester) =>
      tester.widget<GrowingPlant>(find.byType(GrowingPlant)).growth;

  /// The colours actually rendered, read from the tree.
  GardenColors colours(WidgetTester tester) =>
      GardenColors.of(tester.element(find.byType(TimerScreen)));

  /// Runs a whole focus session from START to completion.
  Future<void> finishASession(WidgetTester tester) async {
    await startSession(tester);
    await advance(tester, clock, session);
    await settle(tester);
  }

  Future<void> takeTheBreak(WidgetTester tester) async {
    await tester.tap(find.textContaining('Take a'));
    await settle(tester);
  }

  group('break offer', () {
    testWidgets('shows the chosen break length', (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('Take a 5 min break'), findsOneWidget);
      expect(find.text('Plant another'), findsOneWidget,
          reason: 'the break is offered, not imposed');
    });

    testWidgets('follows the break length in settings', (tester) async {
      await pumpApp(
        tester,
        clock: clock,
        settings:
            GardenSettings.defaults.withBreakLength(const Duration(minutes: 12)),
      );
      await finishASession(tester);

      expect(find.text('Take a 12 min break'), findsOneWidget);
    });

    testWidgets('does not start until accepted', (tester) async {
      // Default: the completion screen stays put, nothing counts down behind
      // it.
      await pumpApp(tester, clock: clock);
      await finishASession(tester);

      await advance(tester, clock, const Duration(minutes: 10));
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('Take a 5 min break'), findsOneWidget);
    });
  });

  group('running break', () {
    testWidgets('counts down like a session', (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);

      await takeTheBreak(tester);

      expect(find.text('On a break'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(strip(tester).progress, 0);

      await advance(tester, clock, const Duration(minutes: 2));
      expect(find.text('03:00'), findsOneWidget);
      expect(strip(tester).progress, closeTo(0.4, 1e-9));
    });

    testWidgets('uses break colours and grows nothing', (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      expect(growing(tester), isNotNull, reason: 'the session grew a plant');

      await takeTheBreak(tester);

      final garden = colours(tester);
      expect(strip(tester).color, garden.skyDay,
          reason: 'sky colour, not session green');
      expect(strip(tester).color, isNot(garden.bloom));
      expect(growing(tester), isNull, reason: 'breaks grow nothing');
      expect(
        find.text('Nothing is growing while you rest. The break ends on its '
            'own.'),
        findsOneWidget,
      );
    });

    testWidgets('ends on its own', (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      await takeTheBreak(tester);

      await advance(tester, clock, shortBreak);
      await settle(tester);

      expect(find.text('Break over'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('Plant it'), findsOneWidget);
    });

    testWidgets('is over after an hour in the background', (tester) async {
      // Nothing runs in the background; the break end is computed on return.
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      await takeTheBreak(tester);

      await sendToBackground(tester);
      clock.advance(const Duration(hours: 1));
      await bringToForeground(tester);
      await settle(tester);

      expect(find.text('Break over'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
    });
  });

  group('break rewards', () {
    testWidgets('no plant and no session count', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(tester, clock: clock, database: database);

      await finishASession(tester);
      expect(find.text('1 session grown'), findsOneWidget);
      expect(await DriftPlantRepository(database).plants(), hasLength(1));

      await takeTheBreak(tester);
      await advance(tester, clock, shortBreak);
      await settle(tester);

      expect(find.text('1 session grown'), findsOneWidget,
          reason: 'breaks are not counted as sessions');
      expect(await DriftPlantRepository(database).plants(), hasLength(1),
          reason: 'breaks do not grow plants');
    });
  });

  group('leaving', () {
    testWidgets('skipping it returns cleanly to idle', (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      await takeTheBreak(tester);

      await tester.tap(find.text('Skip break'));
      await settle(tester);

      expect(find.text('Ready to focus'), findsOneWidget);
      expect(find.text('Plant it'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget,
          reason: 'the countdown shows the session about to be started');
      expect(strip(tester).progress, 0);
    });

    testWidgets('ending early also returns to idle', (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      await takeTheBreak(tester);
      await advance(tester, clock, const Duration(minutes: 4));

      await tester.tap(find.text('Skip break'));
      await settle(tester);

      expect(find.text('Ready to focus'), findsOneWidget);
    });

    testWidgets('stays ended as time passes', (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      await takeTheBreak(tester);
      await tester.tap(find.text('Skip break'));
      await settle(tester);

      await advance(tester, clock, const Duration(hours: 1));
      await settle(tester);

      expect(find.text('Ready to focus'), findsOneWidget);
    });

    testWidgets('next session is a full session', (tester) async {
      // SKIP is the only break control, so the next START gets a whole session.
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      await takeTheBreak(tester);
      await advance(tester, clock, const Duration(minutes: 2));

      await tester.tap(find.text('Skip break'));
      await settle(tester);
      await tester.tap(find.text('Plant it'));
      await settle(tester);

      expect(find.text('Focusing'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget,
          reason: 'a full session, not the rest of the break');
      expect(strip(tester).progress, 0);
    });
  });

  group('break end', () {
    testWidgets('chimes and taps like a session', (tester) async {
      final sound = FakeEndSoundPlayer();
      final haptics = FakeHaptics();
      final notifications = FakeSessionNotifications();
      await pumpApp(
        tester,
        clock: clock,
        endSound: sound,
        haptics: haptics,
        notifications: notifications,
      );

      await finishASession(tester);
      expect(sound.plays, 1, reason: 'the session, announced');

      await takeTheBreak(tester);
      await advance(tester, clock, shortBreak);
      await settle(tester);

      expect(sound.plays, 2, reason: 'the break');
      expect(haptics.completions, 2);
      expect(notifications.scheduled, isEmpty,
          reason: 'app was in the foreground');
    });

    testWidgets('schedules a notification for the end', (tester) async {
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await finishASession(tester);
      await takeTheBreak(tester);
      await advance(tester, clock, const Duration(minutes: 1));

      await sendToBackground(tester);

      final notice = notifications.pending!;
      expect(notice.at, testInstant.add(session + shortBreak),
          reason: 'scheduled for the break end');
      // No plant to name: breaks grow nothing.
      expect(notice.title, 'Your break is over');
      expect(notice.body, 'Ready for another session when you are.');
      expect(notice.title, isNot(contains('!')));
    });

    testWidgets('no chime on return after notifying', (tester) async {
      final sound = FakeEndSoundPlayer();
      final notifications = FakeSessionNotifications();
      await pumpApp(
        tester,
        clock: clock,
        endSound: sound,
        notifications: notifications,
      );

      await finishASession(tester);
      await takeTheBreak(tester);
      final chimedForTheSession = sound.plays;

      await sendToBackground(tester);
      expect(notifications.pending, isNotNull);

      clock.advance(const Duration(minutes: 20));
      await bringToForeground(tester);
      await settle(tester);

      expect(sound.plays, chimedForTheSession,
          reason: 'already notified');
      expect(find.text('Break over'), findsOneWidget);
    });

    testWidgets('silent when skipped', (tester) async {
      // endBreak exists for this: a skipped break isn't chimed.
      final sound = FakeEndSoundPlayer();
      final haptics = FakeHaptics();
      await pumpApp(tester, clock: clock, endSound: sound, haptics: haptics);

      await finishASession(tester);
      await takeTheBreak(tester);
      final chimedForTheSession = sound.plays;

      await tester.tap(find.text('Skip break'));
      await settle(tester);
      await advance(tester, clock, shortBreak);
      await settle(tester);

      expect(sound.plays, chimedForTheSession);
      expect(haptics.completions, 1, reason: 'only the session');
    });

    testWidgets('no notification without a break', (tester) async {
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await finishASession(tester);
      await takeTheBreak(tester);
      await tester.tap(find.text('Skip break'));
      await settle(tester);

      await sendToBackground(tester);

      expect(notifications.pending, isNull);
    });
  });

  group('break while locked', () {
    final breaksStartThemselves =
        GardenSettings.defaults.withAutoStartBreak(enabled: true);

    testWidgets('runs from the instant the session ended', (tester) async {
      await pumpApp(tester, clock: clock, settings: breaksStartThemselves);

      await startSession(tester);
      await sendToBackground(tester);
      clock.advance(session + const Duration(minutes: 3));
      await bringToForeground(tester);
      await settle(tester);

      expect(find.text('On a break'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget,
          reason: '3 of 5 minutes passed while locked');
    });

    testWidgets('is quietly over on return', (tester) async {
      final sound = FakeEndSoundPlayer();
      await pumpApp(
        tester,
        clock: clock,
        endSound: sound,
        settings: breaksStartThemselves,
      );

      await startSession(tester);
      await sendToBackground(tester);
      clock.advance(const Duration(minutes: 40));
      await bringToForeground(tester);
      await settle(tester);

      expect(find.text('Break over'), findsOneWidget);
      expect(sound.plays, 0,
          reason: 'both endings were already notified');
      expect(find.text('Focusing'), findsNothing,
          reason: 'without the second switch, no session starts itself');
    });

    testWidgets('schedules its end on background', (tester) async {
      final notifications = FakeSessionNotifications();
      await pumpApp(
        tester,
        clock: clock,
        notifications: notifications,
        settings: breaksStartThemselves,
      );

      await startSession(tester);
      await sendToBackground(tester);

      expect(notifications.pending!.at, testInstant.add(session));
      final followUp = notifications.pendingFollowUp!;
      expect(followUp.at, testInstant.add(session + shortBreak));
      expect(followUp.title, 'Your break is over');
    });

    testWidgets('notification withdrawn on return', (tester) async {
      final notifications = FakeSessionNotifications();
      await pumpApp(
        tester,
        clock: clock,
        notifications: notifications,
        settings: breaksStartThemselves,
      );

      await startSession(tester);
      await sendToBackground(tester);
      await bringToForeground(tester);
      await settle(tester);

      expect(notifications.pending, isNull);
      expect(notifications.pendingFollowUp, isNull);
    });

    testWidgets('schedules the long break when due', (tester) async {
      final notifications = FakeSessionNotifications();
      final settings = breaksStartThemselves.withLongBreakAfter(2);
      await pumpApp(
        tester,
        clock: clock,
        notifications: notifications,
        settings: settings,
      );

      // One session finished, break skipped.
      await finishASession(tester);
      await tester.tap(find.text('Skip break'));
      await settle(tester);

      // The second earns the long break.
      await startSession(tester);
      final second = clock.now();
      await sendToBackground(tester);

      final followUp = notifications.pendingFollowUp!;
      expect(followUp.title, 'Your long break is over');
      expect(followUp.at, second.add(session + settings.longBreakLength));
    });

    testWidgets('not scheduled for a paused session', (tester) async {
      final notifications = FakeSessionNotifications();
      await pumpApp(
        tester,
        clock: clock,
        notifications: notifications,
        settings: breaksStartThemselves,
      );

      await startSession(tester);
      await tester.tap(find.text('Pause'));
      await settle(tester);
      await sendToBackground(tester);

      expect(notifications.followUps, isEmpty);
    });

    testWidgets('not scheduled when the switch is off', (tester) async {
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await startSession(tester);
      await sendToBackground(tester);

      expect(notifications.pending, isNotNull);
      expect(notifications.followUps, isEmpty);
    });

    testWidgets('manual break starts when accepted', (tester) async {
      await pumpApp(tester, clock: clock);

      await finishASession(tester);
      await advance(tester, clock, const Duration(minutes: 3));
      await takeTheBreak(tester);

      expect(find.text('05:00'), findsOneWidget);
    });
  });

  group('the long break', () {
    /// Long break after 2 sessions, the shortest cycle allowed.
    final impatient = GardenSettings.defaults.withLongBreakAfter(2);

    testWidgets('comes after the configured session count', (tester) async {
      await pumpApp(tester, clock: clock, settings: impatient);

      await finishASession(tester);
      expect(find.text('Take a 5 min break'), findsOneWidget,
          reason: 'cycle not up after one session');

      await takeTheBreak(tester);
      await tester.tap(find.text('Skip break'));
      await settle(tester);

      await finishASession(tester);
      expect(find.text('Take a 15 min long break'), findsOneWidget,
          reason: 'long break is 15 minutes');
    });

    testWidgets('resets the cycle when taken', (tester) async {
      await pumpApp(tester, clock: clock, settings: impatient);

      for (var count = 0; count < 2; count++) {
        await finishASession(tester);
        await takeTheBreak(tester);
        await tester.tap(find.text('Skip break'));
        await settle(tester);
      }
      // Taking the long break resets to session one, so the next is short.
      await finishASession(tester);

      expect(find.text('Take a 5 min break'), findsOneWidget);
      expect(find.text('Take a 15 min long break'), findsNothing);
    });

    testWidgets("cancelled sessions don't count toward it", (tester) async {
      // Only completed sessions move the cycle.
      await pumpApp(tester, clock: clock, settings: impatient);

      await finishASession(tester);
      await takeTheBreak(tester);
      await tester.tap(find.text('Skip break'));
      await settle(tester);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));
      await cancelSession(tester, confirm: true);

      await finishASession(tester);
      expect(find.text('Take a 15 min long break'), findsOneWidget,
          reason: 'cancelled session does not count');
    });
  });

  group('auto-start', () {
    final unattended = GardenSettings.defaults
        .withAutoStartBreak(enabled: true)
        .withAutoStartNextSession(enabled: true);

    testWidgets('focus, break, focus with no taps', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        settings: unattended,
      );

      // The only tap in the test.
      await startSession(tester);

      await advance(tester, clock, session);
      await settle(tester);
      expect(find.text('On a break'), findsOneWidget,
          reason: 'break auto-started');
      expect(find.text('05:00'), findsOneWidget);

      await advance(tester, clock, shortBreak);
      await settle(tester);
      expect(find.text('Focusing'), findsOneWidget,
          reason: 'next session auto-started');
      expect(find.text('25:00'), findsOneWidget);

      await advance(tester, clock, session);
      await settle(tester);
      expect(find.text('On a break'), findsOneWidget);
      expect(await DriftPlantRepository(database).plants(), hasLength(2),
          reason: 'two sessions, two plants, none for breaks');
    });

    testWidgets('survives backgrounding', (tester) async {
      // The break replays from when the session ended, so it's long
      // over 40 minutes later. The next session starts now, not replayed.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        settings: unattended,
      );

      await startSession(tester);
      await sendToBackground(tester);
      clock.advance(const Duration(minutes: 40));
      await bringToForeground(tester);
      await settle(tester);

      expect(find.text('Focusing'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget,
          reason: 'full session anchored at return');
      expect(await DriftPlantRepository(database).plants(), hasLength(1),
          reason: 'one plant for the session completed while away');
    });

    testWidgets('auto-starts the break only', (tester) async {
      await pumpApp(
        tester,
        clock: clock,
        settings: GardenSettings.defaults.withAutoStartBreak(enabled: true),
      );

      await startSession(tester);
      await advance(tester, clock, session);
      await settle(tester);
      expect(find.text('On a break'), findsOneWidget);

      await advance(tester, clock, shortBreak);
      await settle(tester);

      expect(find.text('Break over'), findsOneWidget,
          reason: 'next-session auto-start is off');
      expect(find.text('Plant it'), findsOneWidget);
    });

    testWidgets('auto-starts the next session only', (tester) async {
      await pumpApp(
        tester,
        clock: clock,
        settings:
            GardenSettings.defaults.withAutoStartNextSession(enabled: true),
      );

      await startSession(tester);
      await advance(tester, clock, session);
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('Take a 5 min break'), findsOneWidget);

      // Once the accepted break runs out, the next session auto-starts.
      await takeTheBreak(tester);
      await advance(tester, clock, shortBreak);
      await settle(tester);

      expect(find.text('Focusing'), findsOneWidget);
    });

    testWidgets('no auto-start after a skipped break', (tester) async {
      // Skipping goes to idle, not breakOver, so auto-start doesn't fire.
      await pumpApp(tester, clock: clock, settings: unattended);

      await startSession(tester);
      await advance(tester, clock, session);
      await settle(tester);

      await tester.tap(find.text('Skip break'));
      await settle(tester);
      await advance(tester, clock, const Duration(minutes: 10));
      await settle(tester);

      expect(find.text('Ready to focus'), findsOneWidget);
    });

    testWidgets('no auto-start for an already-offered break', (tester) async {
      // Switch turned on while the completion is already showing. Auto-start
      // only reacts to something ending, so the offered break still waits, even
      // across a background trip.
      await pumpApp(tester, clock: clock);

      await finishASession(tester);
      expect(find.text('Take a 5 min break'), findsOneWidget);

      await tapTab(tester, AppTab.settings);
      await tester.tap(
        await scrollToSetting(tester, SettingsKeys.autoStartBreak),
      );
      await settle(tester);
      await tapTab(tester, AppTab.timer);

      await sendToBackground(tester);
      await bringToForeground(tester);
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('Take a 5 min break'), findsOneWidget);
    });
  });
}
