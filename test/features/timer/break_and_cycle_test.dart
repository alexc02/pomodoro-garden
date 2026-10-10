import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_plant_repository.dart';
import 'package:pomodoro_garden/src/design/garden_colors.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/features/timer/session_ring.dart';
import 'package:pomodoro_garden/src/features/timer/timer_screen.dart';
import 'package:pomodoro_garden/src/garden/growing_plant.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../../support/announcement_fakes.dart';
import '../../support/app_harness.dart';

/// Ticket 09: the break, and the cycle it completes.
///
/// The rules this file is written against, all of which the domain already
/// holds and none of which the user can see there:
///
/// - a finished session **offers** a break; it does not impose one
/// - a break runs on the same timer, and looks unmistakably unlike a session
/// - a break grows nothing and counts for nothing
/// - a break can be walked out of, and walking out is quiet
/// - a break that runs out is announced exactly as a session is
/// - with both switches on, the whole thing runs unattended
///
/// `packages/pomodoro_domain/test/session/break_cycle_test.dart` is where the
/// state machine and the cycle position are pinned down. This is the same rules
/// seen from the outside: through the screen, the chime and the notification.
void main() {
  late FixedClock clock;

  setUp(() => clock = FixedClock(testInstant));

  const session = Duration(minutes: 25);
  const shortBreak = Duration(minutes: 5);

  SessionRing ring(WidgetTester tester) =>
      tester.widget<SessionRing>(find.byType(SessionRing));

  PlantGrowth? growing(WidgetTester tester) =>
      tester.widget<GrowingPlant>(find.byType(GrowingPlant)).growth;

  /// The colours the app is actually rendering with, read off the tree rather
  /// than assumed, so this says nothing about which theme the test is in.
  GardenColors colours(WidgetTester tester) =>
      GardenColors.of(tester.element(find.byType(TimerScreen)));

  /// Runs a whole focus session, from START to the screen saying so.
  Future<void> finishASession(WidgetTester tester) async {
    await startSession(tester);
    await advance(tester, clock, session);
    await settle(tester);
  }

  /// Accepts the break on offer.
  Future<void> takeTheBreak(WidgetTester tester) async {
    await tester.tap(find.textContaining('Take a'));
    await settle(tester);
  }

  group('the break a finished session offers', () {
    testWidgets('names the length the user chose for it', (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('Take a 5 min break'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget,
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

    testWidgets('is not taken until the user takes it', (tester) async {
      // REQ-032's default. The screen sits on the completion, and nothing is
      // counting down behind it.
      await pumpApp(tester, clock: clock);
      await finishASession(tester);

      await advance(tester, clock, const Duration(minutes: 10));
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('Take a 5 min break'), findsOneWidget);
    });
  });

  group('a break in flight', () {
    testWidgets('counts down on the same machinery a session does',
        (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);

      await takeTheBreak(tester);

      expect(find.text('On a break'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(ring(tester).progress, 0);

      // Read from the clock, exactly as a session is.
      await advance(tester, clock, const Duration(minutes: 2));
      expect(find.text('03:00'), findsOneWidget);
      expect(ring(tester).progress, closeTo(0.4, 1e-9));
    });

    testWidgets('is restful rather than green, and grows nothing',
        (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      expect(growing(tester), isNotNull, reason: 'the session grew a plant');

      await takeTheBreak(tester);

      final garden = colours(tester);
      expect(ring(tester).color, garden.skyDay,
          reason: 'the sky, not the growing green a session fills with');
      expect(ring(tester).color, isNot(garden.bloom));
      expect(growing(tester), isNull, reason: 'bare soil: a break grows nothing');
      expect(
        find.text('Nothing is growing while you rest. The break ends on its '
            'own.'),
        findsOneWidget,
      );
    });

    testWidgets('runs out on its own, and says so', (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      await takeTheBreak(tester);

      await advance(tester, clock, shortBreak);
      await settle(tester);

      expect(find.text('Break over'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('comes back from an hour in the background already over',
        (tester) async {
      // Nothing of this app runs while it is away. A break is noticed to have
      // ended the same way a session is — by being asked — so the reading an
      // hour late is the reading a second late.
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

  group('a break earns nothing', () {
    testWidgets('no plant, and nothing added to the count', (tester) async {
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
          reason: 'a break is not a session and never counts as one');
      expect(await DriftPlantRepository(database).plants(), hasLength(1),
          reason: 'REQ: breaks do not grow plants');
    });
  });

  group('leaving a break', () {
    testWidgets('skipping it returns cleanly to idle', (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      await takeTheBreak(tester);

      await tester.tap(find.text('Skip break'));
      await settle(tester);

      expect(find.text('Ready to focus'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget,
          reason: 'the ring shows the session about to be started');
      expect(ring(tester).progress, 0);
    });

    testWidgets('ending it early is the same door', (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      await takeTheBreak(tester);
      await advance(tester, clock, const Duration(minutes: 4));

      await tester.tap(find.text('Skip break'));
      await settle(tester);

      expect(find.text('Ready to focus'), findsOneWidget);
    });

    testWidgets('and the clock cannot bring it back', (tester) async {
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      await takeTheBreak(tester);
      await tester.tap(find.text('Skip break'));
      await settle(tester);

      await advance(tester, clock, const Duration(hours: 1));
      await settle(tester);

      expect(find.text('Ready to focus'), findsOneWidget);
    });

    testWidgets('leaves nothing of itself in the session started after it',
        (tester) async {
      // SKIP is the only control a break has — see `_BreakControls` — so
      // getting back to work early is two taps, and the second one starts a
      // whole session rather than the rest of the break.
      await pumpApp(tester, clock: clock);
      await finishASession(tester);
      await takeTheBreak(tester);
      await advance(tester, clock, const Duration(minutes: 2));

      await tester.tap(find.text('Skip break'));
      await settle(tester);
      await tester.tap(find.text('Start'));
      await settle(tester);

      expect(find.text('Focusing'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget,
          reason: 'a whole session, not the three minutes the break had left');
      expect(ring(tester).progress, 0);
    });
  });

  group('a break that ends', () {
    testWidgets('chimes and taps, exactly as a session does', (tester) async {
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

      expect(sound.plays, 2, reason: 'and now the break');
      expect(haptics.completions, 2);
      expect(notifications.scheduled, isEmpty,
          reason: 'the app was in front the whole time and said so itself');
    });

    testWidgets('leaves a notification behind, aimed at the instant it ends',
        (tester) async {
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await finishASession(tester);
      await takeTheBreak(tester);
      await advance(tester, clock, const Duration(minutes: 1));

      await sendToBackground(tester);

      final notice = notifications.pending!;
      expect(notice.at, testInstant.add(session + shortBreak),
          reason: 'the end of the break, not a minute from now');
      // The same calm as the session's notice, and it claims no reward: a break
      // grows nothing, so there is no plant to name and no garden to mention.
      expect(notice.title, 'Your break is over');
      expect(notice.body, 'Another session is waiting whenever you are ready.');
      expect(notice.title, isNot(contains('!')));
    });

    testWidgets('is not chimed at on return, having already been announced',
        (tester) async {
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
          reason: 'the user was told when it happened');
      expect(find.text('Break over'), findsOneWidget);
    });

    testWidgets('says nothing at all when the user skipped it', (tester) async {
      // The difference `endBreak` exists for: a break that ran out is news, and
      // a break somebody walked out of is not something to chime about.
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
      expect(haptics.completions, 1, reason: 'the session, and nothing since');
    });

    testWidgets('promises nothing for a break nobody is on', (tester) async {
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

  group('the break while the phone is locked (ADR 0022)', () {
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
          reason: 'three of its five minutes passed while the phone was locked');
    });

    testWidgets('is over on return when all of it passed unseen, and quietly',
        (tester) async {
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
          reason: 'both endings were announced by notifications when they '
              'happened');
      expect(find.text('Focusing'), findsNothing,
          reason: 'without the second switch, no session starts itself');
    });

    testWidgets('has its end scheduled as the app leaves', (tester) async {
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

    testWidgets('is withdrawn with the completion when the app comes back',
        (tester) async {
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

    testWidgets('promises the long break when the cycle has earned one',
        (tester) async {
      final notifications = FakeSessionNotifications();
      final settings = breaksStartThemselves.withLongBreakAfter(2);
      await pumpApp(
        tester,
        clock: clock,
        notifications: notifications,
        settings: settings,
      );

      // One session finished in front of the user, its break skipped.
      await finishASession(tester);
      await tester.tap(find.text('Skip break'));
      await settle(tester);

      // The second earns the long one.
      await startSession(tester);
      final second = clock.now();
      await sendToBackground(tester);

      final followUp = notifications.pendingFollowUp!;
      expect(followUp.title, 'Your long break is over');
      expect(followUp.at, second.add(session + settings.longBreakLength));
    });

    testWidgets('is not promised for a held session',
        (tester) async {
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

    testWidgets('nothing is promised when the switch is off', (tester) async {
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await startSession(tester);
      await sendToBackground(tester);

      expect(notifications.pending, isNotNull);
      expect(notifications.followUps, isEmpty);
    });

    testWidgets('a break the user takes by hand still starts when they take it',
        (tester) async {
      await pumpApp(tester, clock: clock);

      await finishASession(tester);
      await advance(tester, clock, const Duration(minutes: 3));
      await takeTheBreak(tester);

      expect(find.text('05:00'), findsOneWidget);
    });
  });

  group('the long break', () {
    /// Two sessions to a long break, which is the shortest cycle REQ-030
    /// allows and so the quickest one to walk end to end.
    final impatient = GardenSettings.defaults.withLongBreakAfter(2);

    testWidgets('arrives after the number of sessions the user set',
        (tester) async {
      await pumpApp(tester, clock: clock, settings: impatient);

      await finishASession(tester);
      expect(find.text('Take a 5 min break'), findsOneWidget,
          reason: 'one session in, the cycle is not up yet');

      await takeTheBreak(tester);
      await tester.tap(find.text('Skip break'));
      await settle(tester);

      await finishASession(tester);
      expect(find.text('Take a 15 min long break'), findsOneWidget,
          reason: 'three ordinary breaks long, which is REQ-007\'s fifteen');
    });

    testWidgets('wraps the cycle back to session one when it is taken',
        (tester) async {
      await pumpApp(tester, clock: clock, settings: impatient);

      for (var count = 0; count < 2; count++) {
        await finishASession(tester);
        await takeTheBreak(tester);
        await tester.tap(find.text('Skip break'));
        await settle(tester);
      }
      // The second break was the long one, and taking it put the user back at
      // session one — so the next break on offer is a short one again.
      await finishASession(tester);

      expect(find.text('Take a 5 min break'), findsOneWidget);
      expect(find.text('Take a 15 min long break'), findsNothing);
    });

    testWidgets('is what a session cancelled in between does not earn',
        (tester) async {
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
          reason: 'the cancelled one counted for nothing, either way');
    });
  });

  group('the cycle running itself', () {
    final unattended = GardenSettings.defaults
        .withAutoStartBreak(enabled: true)
        .withAutoStartNextSession(enabled: true);

    testWidgets('goes focus → break → focus without a tap', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        settings: unattended,
      );

      // The only tap in the whole test.
      await startSession(tester);

      await advance(tester, clock, session);
      await settle(tester);
      expect(find.text('On a break'), findsOneWidget,
          reason: 'the break the session earned, started for the user');
      expect(find.text('05:00'), findsOneWidget);

      await advance(tester, clock, shortBreak);
      await settle(tester);
      expect(find.text('Focusing'), findsOneWidget,
          reason: 'and round again');
      expect(find.text('25:00'), findsOneWidget);

      await advance(tester, clock, session);
      await settle(tester);
      expect(find.text('On a break'), findsOneWidget);
      expect(await DriftPlantRepository(database).plants(), hasLength(2),
          reason: 'two sessions, two plants — and no plant for either break');
    });

    testWidgets('and the cycle survives backgrounding', (tester) async {
      // ADR 0022: the break replays from the instant the session ended, so by
      // the time the app comes back forty minutes later it is long over. The
      // next session is the one leg never replayed: it starts now, from the
      // moment the app noticed the break had ended, and its whole length is
      // still ahead.
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
          reason: 'a whole session, anchored to the moment the app came back');
      expect(await DriftPlantRepository(database).plants(), hasLength(1),
          reason: 'one plant, for the session that completed while away');
    });

    testWidgets('starts a break on its own but waits to be asked for the next '
        'session', (tester) async {
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
          reason: 'the other half of REQ-032 is off, so this one waits');
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('starts the next session on its own but offers the break',
        (tester) async {
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

      // And once the break the user accepted runs out, the next session does
      // begin on its own.
      await takeTheBreak(tester);
      await advance(tester, clock, shortBreak);
      await settle(tester);

      expect(find.text('Focusing'), findsOneWidget);
    });

    testWidgets('does not start a session over a break the user walked out of',
        (tester) async {
      // Skipping lands in idle rather than in `breakOver`, and that is the
      // whole mechanism: walking out of a break is the user taking the cycle
      // back, and the app lets them have it.
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

    testWidgets('does not begin a break the user was only being offered',
        (tester) async {
      // The switch turned on while a completion is already on screen. Auto-start
      // answers to something *ending*, so the break the user is looking at is
      // still theirs to accept — even across a trip to the background, which is
      // the tick that would otherwise pick it up.
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
