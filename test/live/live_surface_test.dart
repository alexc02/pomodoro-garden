import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/announcement_fakes.dart';
import '../support/app_harness.dart';
import '../support/live_surface_fake.dart';

/// The live session surface, driven through the app. The native side can't
/// run here, so this covers when it goes up and down, how often it's pushed,
/// and what turning it off does mid-session.
void main() {
  late FixedClock clock;
  late FakeLiveSessionSurface surface;

  setUp(() {
    clock = FixedClock(testInstant);
    surface = FakeLiveSessionSurface();
  });

  Future<void> launch(WidgetTester tester, {GardenSettings? settings}) =>
      pumpApp(tester, clock: clock, liveSurface: surface, settings: settings);

  /// Flips the live surface switch in settings.
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
      // Neither platform can pause a countdown, so a held surface shows a fixed
      // remaining time: still 15 minutes four minutes into the hold.
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
      // The platform counts down from `endsAt` itself; per-tick pushes would be
      // pointless (and 60 notification updates a minute on Android).
      await launch(tester);
      await startSession(tester);
      final atStart = surface.pushes.length;

      await advance(tester, clock, const Duration(seconds: 10));

      expect(surface.pushes.length, atStart);
    });

    testWidgets('not once a second while the session is held either',
        (tester) async {
      // While held, the end instant moves every second but nothing the held
      // surface draws does.
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

      // Three minutes held is three minutes later.
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

      // Past each threshold: sprout at 20%, young at 50%, maturing at 80%.
      // Mature is completion, and the surface is gone by then.
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
      // One push to start, one per later stage.
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
      // The completion notification is separate from the surface; turning the
      // surface off shouldn't silence it.
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
      // Away from the timer first, so the tap has somewhere to bring them back
      // from.
      await tapTab(tester, AppTab.garden);
      expect(find.text('Ready to focus'), findsNothing);

      surface.tap();
      await settle(tester);

      expect(find.text('Focusing'), findsOneWidget);
    });
  });

  group('a session found at launch', () {
    testWidgets('is put straight back on the lock screen', (tester) async {
      // The app was killed mid-session; the surface has to come back with it.
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
      // Only the initial sync covers this: a held snapshot never changes on its
      // own, so nothing else would trigger a push.
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
      // `SessionLifecycle` voids the session on the same signal.
      await launch(tester);
      await startSession(tester);

      await forceQuitApp(tester);

      expect(surface.showing, isNull);
    });

    testWidgets('backgrounding does not', (tester) async {
      // Backgrounding isn't an interruption, and it's when the surface matters
      // most.
      await launch(tester);
      await startSession(tester);

      await sendToBackground(tester);

      expect(surface.showing, isNotNull);
    });
  });
}
