import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/announcement_fakes.dart';
import '../../support/app_harness.dart';

// A completion is announced once: chime and haptic in the foreground, or a
// notification scheduled on the way out. The notification only exists while
// the app is away, so both can't fire.
//
// Whether the OS actually delivers the notification (sound, silent switch)
// can only be checked on a device.
void main() {
  PlantGrowth? growing(WidgetTester tester) =>
      tester.widget<GrowingPlant>(find.byType(GrowingPlant)).growth;

  group('foreground completion', () {
    testWidgets('chimes and taps once, no notification', (tester) async {
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
      expect(sound.plays, 1, reason: 'chime once');
      expect(haptics.completions, 1, reason: 'success haptic');
      expect(notifications.scheduled, isEmpty,
          reason: 'app was in the foreground');
    });

    testWidgets('taps at each growth stage', (tester) async {
      final clock = FixedClock(testInstant);
      final haptics = FakeHaptics();
      await pumpApp(tester, clock: clock, haptics: haptics);

      await startSession(tester);
      expect(growing(tester)!.stage, GrowthStage.seed);
      expect(haptics.growths, 0, reason: 'no growth yet');

      // Cross thresholds one at a time.
      await advance(tester, clock, const Duration(minutes: 5));
      expect(growing(tester)!.stage, GrowthStage.sprout);
      expect(haptics.growths, 1);

      await advance(tester, clock, const Duration(minutes: 8));
      expect(growing(tester)!.stage, GrowthStage.young);
      expect(haptics.growths, 2);

      await advance(tester, clock, const Duration(minutes: 8));
      expect(growing(tester)!.stage, GrowthStage.maturing);
      expect(haptics.growths, 3);

      // The last stage comes with the completion: one tap, not two.
      await advance(tester, clock, const Duration(minutes: 4));
      await settle(tester);
      expect(growing(tester)!.stage, GrowthStage.mature);
      expect(haptics.growths, 3);
      expect(haptics.completions, 1);
    });

    testWidgets('next session start is not a growth tap', (tester) async {
      final clock = FixedClock(testInstant);
      final haptics = FakeHaptics();
      await pumpApp(tester, clock: clock, haptics: haptics);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      final grownByTheFirst = haptics.growths;

      // A mature plant is replaced by a seed; that's not growth.
      await tester.tap(find.text('Plant another'));
      await tester.pump();

      expect(haptics.growths, grownByTheFirst);
    });

    testWidgets('haptics off keeps the chime', (tester) async {
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
          reason: 'haptics switch does not affect sound');
    });
  });

  group('background completion', () {
    testWidgets('schedules a notification for the end', (tester) async {
      final clock = FixedClock(testInstant);
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));
      final species = growing(tester)!.species;

      await sendToBackground(tester);

      final notice = notifications.pending!;
      expect(notice.at, testInstant.add(const Duration(minutes: 25)),
          reason: 'scheduled for the session end');
      // Names what grew and asks for nothing.
      expect(notice.title, 'Your ${species.label.toLowerCase()} has bloomed');
      expect(notice.body,
          "Your session's done. It's in your garden whenever you want to look.");
      expect(notice.title, isNot(contains('!')));
    });

    testWidgets('nothing scheduled while paused', (tester) async {
      // A paused session has no known end time.
      final clock = FixedClock(testInstant);
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));
      await pauseSession(tester);
      await sendToBackground(tester);

      expect(notifications.pending, isNull);
    });

    testWidgets('schedules the later end after a pause', (tester) async {
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
          reason: '6 minutes paused, 6 minutes later');
    });

    testWidgets('cancelled on return', (tester) async {
      final clock = FixedClock(testInstant);
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await startSession(tester);
      await sendToBackground(tester);
      expect(notifications.pending, isNotNull);

      await bringToForeground(tester);
      await settle(tester);

      expect(notifications.pending, isNull,
          reason: 'cancelled on return');
    });

    testWidgets('cancelled on force-quit', (tester) async {
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
          reason: 'session voided');
    });

    testWidgets('no chime when it ends in the background', (tester) async {
      // Android keeps timers running for a while in the background, so the app
      // can be awake when the session ends. The notification handles it then.
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
      expect(haptics.growths, 0, reason: 'no growth haptic');
      expect(await DriftPlantRepository(database).plants(), hasLength(1),
          reason: 'session still completed');
    });

    testWidgets('no chime on return', (tester) async {
      // The notification already announced it at 25 minutes.
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

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('1 session grown'), findsOneWidget);
      expect(await DriftPlantRepository(database).plants(), hasLength(1));
    });
  });

  group('notification permission', () {
    testWidgets('not asked on first launch', (tester) async {
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, notifications: notifications);

      expect(notifications.permissionRequests, 0,
          reason: 'no permission prompt on first launch');
    });

    testWidgets('asked at the first START only', (tester) async {
      final clock = FixedClock(testInstant);
      final notifications = FakeSessionNotifications();
      await pumpApp(tester, clock: clock, notifications: notifications);

      await startSession(tester);
      expect(notifications.permissionRequests, 1);

      await cancelSession(tester, confirm: true);
      await startSession(tester);

      expect(notifications.permissionRequests, 1,
          reason: 'only asked once');
    });

    testWidgets('refusal does not affect the session', (tester) async {
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
      // The notice is scheduled and dropped, which is what refused permission
      // means on both platforms.
      await sendToBackground(tester);
      expect(notifications.scheduled, hasLength(1));
      expect(notifications.pending, isNull);

      await advance(tester, clock, const Duration(minutes: 25));
      await bringToForeground(tester);
      await settle(tester);

      // The wall clock completes the session; the notification is just a
      // backup.
      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('1 session grown'), findsOneWidget);
      expect(await DriftPlantRepository(database).plants(), hasLength(1));
    });

    testWidgets('refusal keeps the foreground chime', (tester) async {
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
          reason: 'foreground chime is independent of notifications');
      expect(haptics.completions, 1);
    });
  });

  group('killed before completion was seen', () {
    late Directory directory;
    late File file;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('pip_garden_test');
      file = File('${directory.path}/pip_garden.sqlite');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    testWidgets('complete and silent on next launch', (tester) async {
      final clock = FixedClock(testInstant);
      final sound = FakeEndSoundPlayer();
      final haptics = FakeHaptics();

      // Started, backgrounded, then evicted before its timer ran out.
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
          reason: 'ended at its scheduled time');

      expect(sound.plays, 0, reason: 'no chime on launch');
      expect(haptics.completions, 0);
    });
  });
}
