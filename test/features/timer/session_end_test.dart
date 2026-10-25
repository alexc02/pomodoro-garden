import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_plant_repository.dart';
import 'package:pomodoro_garden/src/data/drift_session_repository.dart';
import 'package:pomodoro_garden/src/garden/growing_plant.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../../support/announcement_fakes.dart';
import '../../support/app_harness.dart';

/// Ticket 06: how a session ends, and who says so.
///
/// The rule the whole file is written against: **a completion is announced
/// once, by whichever of the two can be heard.** In front of the user that is
/// the wind chime and a haptic; away from them it is a notification the system
/// was handed on the way out. The notification exists only while the app is
/// away, so there is no moment when both could sound and no moment when
/// neither could.
///
/// What is *not* here, because no widget test can reach it: whether the phone
/// actually rings. That the operating system delivers a notification it
/// accepted, plays the sound attached to it, and honours the silent switch
/// while doing so, is verifiable only on a device — see the ticket's
/// verification gaps.
void main() {
  /// What the timer screen says is growing.
  PlantGrowth? growing(WidgetTester tester) =>
      tester.widget<GrowingPlant>(find.byType(GrowingPlant)).growth;

  group('a session that ends with the user watching', () {
    testWidgets('chimes and taps, once, and sends no notification',
        (tester) async {
      final clock = FixedClock(testInstant);
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

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(sound.plays, 1, reason: 'REQ-008: the wind chime, once');
      expect(haptics.completions, 1, reason: 'REQ-037: the success haptic');
      expect(notifications.scheduled, isEmpty,
          reason: 'the app was in front the whole time and said so itself');
    });

    testWidgets('taps at every growth stage on the way', (tester) async {
      final clock = FixedClock(testInstant);
      final haptics = FakeHaptics();
      await pumpApp(tester, clock: clock, haptics: haptics);

      await startSession(tester);
      expect(growing(tester)!.stage, GrowthStage.seed);
      expect(haptics.growths, 0, reason: 'a seed has not grown into anything');

      // REQ-016's thresholds, crossed one at a time.
      await advance(tester, clock, const Duration(minutes: 5));
      expect(growing(tester)!.stage, GrowthStage.sprout);
      expect(haptics.growths, 1);

      await advance(tester, clock, const Duration(minutes: 8));
      expect(growing(tester)!.stage, GrowthStage.young);
      expect(haptics.growths, 2);

      await advance(tester, clock, const Duration(minutes: 8));
      expect(growing(tester)!.stage, GrowthStage.maturing);
      expect(haptics.growths, 3);

      // The last stage arrives with the completion, and the completion is the
      // louder of the two: one tap, not two on top of each other.
      await advance(tester, clock, const Duration(minutes: 4));
      await settle(tester);
      expect(growing(tester)!.stage, GrowthStage.mature);
      expect(haptics.growths, 3);
      expect(haptics.completions, 1);
    });

    testWidgets('starting the next session is not a plant growing',
        (tester) async {
      final clock = FixedClock(testInstant);
      final haptics = FakeHaptics();
      await pumpApp(tester, clock: clock, haptics: haptics);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      final grownByTheFirst = haptics.growths;

      // A mature plant is replaced by a seed. Nothing grew; a session started.
      await tester.tap(find.text('Plant another'));
      await tester.pump();

      expect(haptics.growths, grownByTheFirst);
    });

    testWidgets('the haptics switch silences both taps and leaves the chime',
        (tester) async {
      final clock = FixedClock(testInstant);
      final sound = FakeEndSoundPlayer();
      final haptics = FakeHaptics();
      await pumpApp(
        tester,
        clock: clock,
        endSound: sound,
        haptics: haptics,
        settings: GardenSettings.defaults.withHaptics(enabled: false),
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      expect(haptics.growths, 0);
      expect(haptics.completions, 0);
      expect(sound.plays, 1,
          reason: 'REQ-037 is a switch for haptics, not for sound');
    });
  });

  group('a session the app is away for', () {
    testWidgets('leaves a notification behind, aimed at the instant it ends',
        (tester) async {
      final clock = FixedClock(testInstant);
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));
      final species = growing(tester)!.species;

      await sendToBackground(tester);

      final notice = notifications.pending!;
      expect(notice.at, testInstant.add(const Duration(minutes: 25)),
          reason: 'the end of the session, not four minutes from now');
      // Calm, and about the garden rather than about the timer: it names what
      // grew and asks for nothing.
      expect(notice.title, 'Your ${species.label.toLowerCase()} has bloomed');
      expect(notice.body,
          "Your session's done. It's in your garden whenever you want to look.");
      expect(notice.title, isNot(contains('!')));
    });

    testWidgets('promises nothing for a session that is held', (tester) async {
      // A paused session ends however long after the user resumes it, and they
      // can only resume it from in here. There is no instant to promise.
      final clock = FixedClock(testInstant);
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));
      await pauseSession(tester);
      await sendToBackground(tester);

      expect(notifications.pending, isNull);
    });

    testWidgets('promises the later end a pause bought', (tester) async {
      final clock = FixedClock(testInstant);
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));
      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 6));
      await resumeSession(tester);
      await sendToBackground(tester);

      expect(notifications.pending!.at,
          testInstant.add(const Duration(minutes: 31)),
          reason: 'six minutes held is six minutes later');
    });

    testWidgets('takes it back when the user comes back', (tester) async {
      final clock = FixedClock(testInstant);
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await startSession(tester);
      await sendToBackground(tester);
      expect(notifications.pending, isNotNull);

      await bringToForeground(tester);
      await settle(tester);

      expect(notifications.pending, isNull,
          reason: 'the app can speak for itself again');
    });

    testWidgets('takes it back when the user throws the session away',
        (tester) async {
      final clock = FixedClock(testInstant);
      final notifications = FakeSessionNotifications();
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        notifications: notifications,
      );

      await startSession(tester);
      await forceQuitApp(tester);

      expect(notifications.pending, isNull,
          reason: 'REQ-013 voids the session, so there is nothing to announce');
    });

    testWidgets('does not chime into a pocket when it ends there',
        (tester) async {
      // Android leaves the app's timers running for a while after it goes
      // behind, so this app can be awake at the moment a session ends without
      // being in front of anyone. The chime is the notification's job then —
      // playing both would be one completion announced twice.
      final clock = FixedClock(testInstant);
      final sound = FakeEndSoundPlayer();
      final haptics = FakeHaptics();
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        endSound: sound,
        haptics: haptics,
      );

      await startSession(tester);
      await sendToBackground(tester);
      await advance(tester, clock, const Duration(minutes: 25));

      expect(sound.plays, 0);
      expect(haptics.completions, 0);
      expect(haptics.growths, 0, reason: 'nor a buzz for a plant nobody can see');
      expect(await DriftPlantRepository(database).plants(), hasLength(1),
          reason: 'and the session completed all the same');
    });

    testWidgets('is not chimed at on return, having already been announced',
        (tester) async {
      // The case that looks like a bug and is not. The user was told at
      // twenty-five minutes by the notification; a chime now would be the app
      // sounding at the wrong moment, about news the user already has.
      final clock = FixedClock(testInstant);
      final sound = FakeEndSoundPlayer();
      final haptics = FakeHaptics();
      final notifications = FakeSessionNotifications();
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        endSound: sound,
        haptics: haptics,
        notifications: notifications,
      );

      await startSession(tester);
      await sendToBackground(tester);
      expect(notifications.pending, isNotNull);

      clock.advance(const Duration(minutes: 40));
      await bringToForeground(tester);
      await settle(tester);

      expect(sound.plays, 0);
      expect(haptics.completions, 0);

      // And the session is nonetheless complete, recorded and planted.
      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('1 session grown'), findsOneWidget);
      expect(await DriftPlantRepository(database).plants(), hasLength(1));
    });
  });

  group('asking to be allowed to notify', () {
    testWidgets('is not something a first launch does', (tester) async {
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, notifications: notifications);

      expect(notifications.permissionRequests, 0,
          reason: 'a permission dialog over a screen nobody has used yet is a '
              'question about nothing');
    });

    testWidgets('happens at the first START, and only there', (tester) async {
      final clock = FixedClock(testInstant);
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await startSession(tester);
      expect(notifications.permissionRequests, 1);

      await cancelSession(tester, confirm: true);
      await startSession(tester);

      expect(notifications.permissionRequests, 1,
          reason: 'neither platform asks a user who has already decided');
    });

    testWidgets('being refused costs the session nothing', (tester) async {
      final clock = FixedClock(testInstant);
      final sound = FakeEndSoundPlayer();
      final notifications = FakeSessionNotifications()..granted = false;
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        endSound: sound,
        notifications: notifications,
      );

      await startSession(tester);
      // The user spends the session with the phone face down, and nothing will
      // reach them: the notice is scheduled and silently dropped, which is what
      // a refused permission means on both platforms.
      await sendToBackground(tester);
      expect(notifications.scheduled, hasLength(1));
      expect(notifications.pending, isNull);

      await advance(tester, clock, const Duration(minutes: 25));
      await bringToForeground(tester);
      await settle(tester);

      // The session is anchored to the wall clock, and that is what completes
      // it — a notification is the second guarantee, never the first.
      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('1 session grown'), findsOneWidget);
      expect(await DriftPlantRepository(database).plants(), hasLength(1));
    });

    testWidgets('being refused leaves the chime the app plays itself',
        (tester) async {
      final clock = FixedClock(testInstant);
      final sound = FakeEndSoundPlayer();
      final haptics = FakeHaptics();
      await pumpApp(
        tester,
        clock: clock,
        endSound: sound,
        haptics: haptics,
        notifications: FakeSessionNotifications()..granted = false,
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      expect(sound.plays, 1,
          reason: 'nothing about notifications governs what the app itself '
              'does while the user is looking at it');
      expect(haptics.completions, 1);
    });
  });

  group('killed after the session ended, before it was reopened', () {
    late Directory directory;
    late File file;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('pomodoro_garden_test');
      file = File('${directory.path}/pomodoro_garden.sqlite');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    testWidgets('the session is complete on the next launch, and quiet about '
        'it', (tester) async {
      final clock = FixedClock(testInstant);
      final sound = FakeEndSoundPlayer();
      final haptics = FakeHaptics();

      // A session started, backgrounded, and then evicted from memory before
      // its own timer ever ran out. Nothing was there to notice it finish.
      final firstLaunch = AppDatabase.inFile(file);
      await pumpApp(tester, clock: clock, database: firstLaunch);
      await startSession(tester);
      await sendToBackground(tester);
      await killApp(tester);
      await firstLaunch.close();

      clock.advance(const Duration(minutes: 40));

      final secondLaunch = AppDatabase.inFile(file);
      addTearDown(secondLaunch.close);
      await pumpApp(
        tester,
        clock: clock,
        database: secondLaunch,
        endSound: sound,
        haptics: haptics,
      );
      await tapTab(tester, AppTab.timer);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('1 session grown'), findsOneWidget);
      expect(await DriftPlantRepository(secondLaunch).plants(), hasLength(1));

      final stored =
          await DriftSessionRepository(secondLaunch).completedSessions();
      expect(stored.single.endedAt, testInstant.add(const Duration(minutes: 25)),
          reason: 'it ended when it ran out, not when it was found');

      expect(sound.plays, 0, reason: 'this is a launch, not a completion');
      expect(haptics.completions, 0);
    });
  });
}
