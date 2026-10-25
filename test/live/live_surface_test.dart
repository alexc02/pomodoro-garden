import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/announcement_fakes.dart';
import '../support/app_harness.dart';
import '../support/live_surface_fake.dart';

/// The live session surface, driven the way a user drives it.
///
/// Everything below `LiveSessionSurface` is Swift or Kotlin and none of it can
/// run here, so these tests assert the half that is ours: *when* the surface is
/// put up, *when* it is taken down, *how often* it is pushed, and what happens
/// to a running session when the user turns the whole thing off.
void main() {
  late FixedClock clock;
  late FakeLiveSessionSurface surface;

  setUp(() {
    clock = FixedClock(testInstant);
    surface = FakeLiveSessionSurface();
  });

  Future<void> launch(WidgetTester tester, {GardenSettings? settings}) =>
      pumpApp(tester, clock: clock, liveSurface: surface, settings: settings);

  /// Flips REQ-033's switch, from the settings tab.
  ///
  /// It is the last control on the screen, so on the default test surface it
  /// starts below the fold.
  Future<void> flipTheSwitch(WidgetTester tester) async {
    await tester.tap(await scrollToSetting(tester, SettingsKeys.liveSurface));
    await settle(tester);
  }

  group('a session in flight', () {
    testWidgets('puts the session on the lock screen', (tester) async {
      await launch(tester);
      await startSession(tester);

      final showing = surface.showing!;
      expect(showing.paused, isFalse);
      expect(showing.remaining, const Duration(minutes: 25));
      expect(showing.endsAt, testInstant.add(const Duration(minutes: 25)));
      expect(showing.growing.stage, GrowthStage.seed);
    });

    testWidgets('takes it down when the session completes', (tester) async {
      await launch(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));

      expect(find.text('Session complete'), findsOneWidget);
      expect(surface.showing, isNull);
    });

    testWidgets('takes it down when the session is cancelled', (tester) async {
      await launch(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));

      await cancelSession(tester, confirm: true);

      expect(surface.showing, isNull);
    });

    testWidgets('leaves it up when the user changes their mind about '
        'cancelling', (tester) async {
      await launch(tester);
      await startSession(tester);

      await cancelSession(tester, confirm: false);

      expect(surface.showing, isNotNull);
    });

    testWidgets('shows a held session as held, with a countdown that has '
        'stopped', (tester) async {
      await launch(tester);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));
      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));

      final showing = surface.showing!;
      expect(showing.paused, isTrue);
      // Neither platform can hold a running countdown, so a held surface shows
      // the remaining time as a number standing still rather than as an
      // interval to count over. Four minutes into the hold it still reads
      // fifteen minutes, which is the point.
      expect(showing.remaining, const Duration(minutes: 15));
    });

    testWidgets('shows a resumed session as running again', (tester) async {
      await launch(tester);
      await startSession(tester);
      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 2));
      await resumeSession(tester);

      expect(surface.showing!.paused, isFalse);
    });
  });

  group('how often it is pushed', () {
    testWidgets('not once a second', (tester) async {
      // The platform counts down from `endsAt` on its own. A push per tick
      // would be sixty channel crossings a minute to redraw a countdown that
      // is already right — and on Android, sixty notification updates.
      await launch(tester);
      await startSession(tester);
      final atStart = surface.pushes.length;

      await advance(tester, clock, const Duration(seconds: 10));

      expect(surface.pushes.length, atStart);
    });

    testWidgets('not once a second while the session is held either',
        (tester) async {
      // The case the running one does not cover, and the one that gets it
      // wrong: while a session is held its *end instant* moves every second —
      // the session will finish however much later — but nothing a held
      // surface draws moves with it. What it shows is a static remaining time.
      await launch(tester);
      await startSession(tester);
      await pauseSession(tester);
      final atPause = surface.pushes.length;

      await advance(tester, clock, const Duration(seconds: 10));

      expect(surface.pushes.length, atPause);
    });

    testWidgets('once when the user resumes, with the new end instant',
        (tester) async {
      await launch(tester);
      await startSession(tester);
      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 3));
      await resumeSession(tester);

      // Three minutes held is three minutes later, and it reaches the surface
      // at the moment the surface starts counting down from it again.
      expect(surface.showing!.paused, isFalse);
      expect(
        surface.showing!.endsAt,
        testInstant.add(const Duration(minutes: 28)),
      );
    });

    testWidgets('once for each stage the plant reaches', (tester) async {
      await launch(tester);
      await startSession(tester);
      final stages = <GrowthStage>[surface.showing!.growing.stage];

      // Past each of the three thresholds a running session crosses: sprout at
      // 20% of 25 minutes, young at 50%, maturing at 80%. Mature is the
      // completion, and the surface is down by then.
      for (final minutes in [6, 7, 8]) {
        await advance(tester, clock, Duration(minutes: minutes));
        stages.add(surface.showing!.growing.stage);
      }

      expect(stages, [
        GrowthStage.seed,
        GrowthStage.sprout,
        GrowthStage.young,
        GrowthStage.maturing,
      ]);
      // One push to start it, and one for each stage after the first.
      expect(surface.pushes, hasLength(4));
    });
  });

  group('the setting', () {
    testWidgets('is on by default, so a first session is shown',
        (tester) async {
      await launch(tester);
      await startSession(tester);

      expect(surface.showing, isNotNull);
    });

    testWidgets('turned off, nothing is ever shown', (tester) async {
      await launch(
        tester,
        settings: GardenSettings.defaults.withLiveSurface(enabled: false),
      );
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 10));

      expect(surface.pushes, isEmpty);
      expect(surface.showing, isNull);
    });

    testWidgets('turned off mid-session takes the surface down there and then',
        (tester) async {
      await launch(tester);
      await startSession(tester);
      expect(surface.showing, isNotNull);

      await tapTab(tester, AppTab.settings);
      await flipTheSwitch(tester);

      expect(surface.showing, isNull);
    });

    testWidgets('turned back on mid-session puts it back', (tester) async {
      await launch(
        tester,
        settings: GardenSettings.defaults.withLiveSurface(enabled: false),
      );
      await startSession(tester);

      await tapTab(tester, AppTab.settings);
      await flipTheSwitch(tester);

      expect(surface.showing, isNotNull);
    });
  });

  group('what turning it off does not break', () {
    testWidgets('a backgrounded session is still announced', (tester) async {
      // REQ-033's second half, and the reason the switch is safe to offer. The
      // completion notification is ticket 06's and has nothing to do with the
      // surface; a user who turns the lock screen off is not asking to stop
      // being told their session finished.
      final notifications = FakeSessionNotifications();
      await pumpApp(
        tester,
        clock: clock,
        liveSurface: surface,
        notifications: notifications,
        settings: GardenSettings.defaults.withLiveSurface(enabled: false),
      );
      await startSession(tester);

      await sendToBackground(tester);

      expect(notifications.pending, isNotNull);
      expect(
        notifications.pending!.at,
        testInstant.add(const Duration(minutes: 25)),
      );
    });

    testWidgets('a backgrounded session still completes and plants',
        (tester) async {
      await launch(
        tester,
        settings: GardenSettings.defaults.withLiveSurface(enabled: false),
      );
      await startSession(tester);

      await sendToBackground(tester);
      clock.advance(const Duration(minutes: 25));
      await bringToForeground(tester);
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('1 session grown'), findsOneWidget);
    });
  });

  group('tapping it', () {
    testWidgets('opens the app on the timer', (tester) async {
      await launch(tester);
      await startSession(tester);
      // Somewhere else entirely, which is where a user who put their phone
      // down on the garden comes back from.
      await tapTab(tester, AppTab.garden);
      expect(find.text('Ready to focus'), findsNothing);

      surface.tap();
      await settle(tester);

      expect(find.text('Focusing'), findsOneWidget);
    });
  });

  group('a session found at launch', () {
    testWidgets('is put straight back on the lock screen', (tester) async {
      // The app was killed mid-session — by the system, or for memory — and
      // the session carried on being however far along it is. The surface has
      // to come back with it.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await pumpApp(tester, clock: clock, database: database);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await killApp(tester);

      await pumpApp(
        tester,
        clock: clock,
        database: database,
        liveSurface: surface,
      );

      expect(surface.showing, isNotNull);
      expect(surface.showing!.remaining, const Duration(minutes: 20));
    });

    testWidgets('comes back held if that is how it was left', (tester) async {
      // The case an initial sync is the only thing that covers: a held
      // session's snapshot does not move on its own, so nothing would ever
      // change to wake a listener up.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await pumpApp(tester, clock: clock, database: database);
      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await pauseSession(tester);
      await killApp(tester);

      await pumpApp(
        tester,
        clock: clock,
        database: database,
        liveSurface: surface,
      );

      expect(surface.showing, isNotNull);
      expect(surface.showing!.paused, isTrue);
    });
  });

  group('the app going away', () {
    testWidgets('a force-quit takes the surface with it', (tester) async {
      // The session is voided by `SessionLifecycle` on the same signal. A
      // surface left standing would be counting down to a session that no
      // longer exists.
      await launch(tester);
      await startSession(tester);

      await forceQuitApp(tester);

      expect(surface.showing, isNull);
    });

    testWidgets('backgrounding does not', (tester) async {
      // REQ-013: backgrounding is not an interruption, and the surface is the
      // whole point of backgrounding.
      await launch(tester);
      await startSession(tester);

      await sendToBackground(tester);

      expect(surface.showing, isNotNull);
    });
  });
}
