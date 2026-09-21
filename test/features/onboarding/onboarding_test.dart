import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_settings_repository.dart';
import 'package:pip_garden/src/features/onboarding/coach_marks.dart';
import 'package:pip_garden/src/features/onboarding/garden_preview.dart';
import 'package:pip_garden/src/features/onboarding/onboarding_steps.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';
import 'package:pip_garden/src/garden/plant_painter.dart';
import 'package:pip_garden/src/onboarding/onboarding.dart';
import 'package:pip_garden/src/session/session_providers.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/announcement_fakes.dart';
import '../../support/app_harness.dart';
import '../../support/quiet_mode_fake.dart';

// Onboarding through the real app: three steps over the app, then coach
// marks on it. Not tested in isolation on purpose.
void main() {
  late FixedClock clock;

  setUp(() => clock = FixedClock(testInstant));

  SessionSnapshot session(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(sessionControllerProvider);

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(OnboardingKeys.next));
    await settle(tester);
  }

  Future<void> skip(WidgetTester tester) async {
    await tester.tap(find.byKey(OnboardingKeys.skip));
    await settle(tester);
  }

  /// Taps the last step, which starts the session.
  Future<void> startFirstSession(WidgetTester tester) async {
    await tester.tap(find.byKey(OnboardingKeys.start));
    await settle(tester);
  }

  /// Runs the whole flow, picking [length] if a preset matches.
  Future<void> runOnboarding(
    WidgetTester tester, {
    SessionPreset? choosing,
  }) async {
    await next(tester);
    if (choosing != null) {
      await tester.tap(find.byKey(OnboardingKeys.preset(choosing)));
      await settle(tester);
    }
    await next(tester);
    await startFirstSession(tester);
  }

  Future<void> dismissCoachMark(WidgetTester tester) async {
    await tester.tap(find.text('Got it'));
    await settle(tester);
  }

  /// The timer plant's painter, used to check the seed drop.
  PlantPainter pose(WidgetTester tester) => tester
      .widget<CustomPaint>(
        find.descendant(
          of: find.byType(GrowingPlant),
          matching: find.byType(CustomPaint),
        ),
      )
      .painter! as PlantPainter;

  group('the three steps', () {
    testWidgets('first launch shows the welcome over the app', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);

      expect(find.byType(OnboardingSteps), findsOneWidget);
      expect(find.text('Focus, and something grows'), findsOneWidget);
      // The app stays underneath; the last step hands off rather than
      // navigating.
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('app underneath is inert while a step is up', (tester) async {
      final semantics = tester.ensureSemantics();

      await pumpApp(tester, clock: clock, firstLaunch: true);

      // Taps behind the welcome must not reach the app...
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Timer'),
        ),
        warnIfMissed: false,
      );
      await settle(tester);

      expect(find.byType(OnboardingSteps), findsOneWidget);
      expect(find.text('Ready to focus'), findsNothing,
          reason: 'the timer tab was never opened');

      // ...and screen readers must not see the app behind it either.
      expect(find.bySemanticsLabel(RegExp('Timer')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Garden')), findsNothing);
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget,
          reason: 'only the current step is read out');

      // Dispose here: the framework checks for live handles before teardown.
      semantics.dispose();
    });

    testWidgets('three steps, the last starts the session', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);

      expect(find.byType(GardenPreview), findsOneWidget);
      expect(find.byKey(OnboardingKeys.lengths), findsNothing);

      await next(tester);

      expect(find.byKey(OnboardingKeys.lengths), findsOneWidget);
      expect(find.byType(GardenPreview), findsNothing);

      await next(tester);

      // No fourth step: the last button starts a session.
      expect(find.byKey(OnboardingKeys.next), findsNothing);
      expect(find.byKey(OnboardingKeys.start), findsOneWidget);
      expect(OnboardingStep.values, hasLength(3));

      await startFirstSession(tester);

      expect(find.byType(OnboardingSteps), findsNothing);
      expect(session(tester).phase, SessionPhase.running);
    });

    testWidgets('chosen length is saved and used', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await pumpApp(
        tester,
        clock: clock,
        database: database,
        firstLaunch: true,
      );
      await runOnboarding(tester, choosing: SessionPreset.deep);

      expect(session(tester).remaining, const Duration(minutes: 50));
      // Saved as the real setting, so later sessions use it too.
      expect(
        (await DriftSettingsRepository(database).load()).sessionLength,
        const Duration(minutes: 50),
      );
    });

    testWidgets('untouched length step keeps 25 minutes', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester);

      expect(session(tester).remaining, const Duration(minutes: 25));
    });
  });

  group('nothing in the way', () {
    testWidgets('no account or sign-in', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);

      for (var step = 0; step < OnboardingStep.values.length; step++) {
        // Everything is on device, so nothing to ask for. Checks the words
        // since the likely regression is a "sign in to back up" prompt.
        for (final asking in const [
          'Sign in',
          'Sign up',
          'Log in',
          'Create an account',
          'Email',
          'Continue with',
        ]) {
          expect(find.textContaining(asking, findRichText: true), findsNothing,
              reason: 'nothing in onboarding asks for an account');
        }
        expect(find.byType(TextField), findsNothing);

        if (step < OnboardingStep.values.length - 1) await next(tester);
      }
    });

    testWidgets('no permission prompt before the session runs', (tester) async {
      final notifications = FakeSessionNotifications();
      final quietMode = FakeQuietMode();

      await pumpApp(
        tester,
        clock: clock,
        firstLaunch: true,
        notifications: notifications,
        quietMode: quietMode,
      );
      await next(tester);
      await next(tester);

      expect(notifications.permissionRequests, 0);
      expect(quietMode.accessRequests, 0);

      await startFirstSession(tester);

      // The only prompt is notifications at first START, after the session is
      // already anchored. Quiet mode asks nothing until turned on.
      expect(session(tester).phase, SessionPhase.running);
      expect(quietMode.accessRequests, 0);
    });

    testWidgets('session runs whatever the permission answer', (tester) async {
      final notifications = FakeSessionNotifications()..granted = false;

      await pumpApp(
        tester,
        clock: clock,
        firstLaunch: true,
        notifications: notifications,
      );
      await runOnboarding(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      expect(session(tester).phase, SessionPhase.completed);
    });
  });

  group('skipping', () {
    testWidgets('every step can be skipped', (tester) async {
      for (final from in OnboardingStep.values) {
        await pumpApp(tester, clock: clock, firstLaunch: true);
        for (var step = 0; step < from.index; step++) {
          await next(tester);
        }

        await skip(tester);

        expect(find.byType(OnboardingSteps), findsNothing,
            reason: 'skipped from ${from.name}');
        expect(session(tester).phase, SessionPhase.idle,
            reason: 'skipping starts nothing');
        await killApp(tester);
      }
    });

    testWidgets('skipping also skips coach marks', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await skip(tester);

      // Skipping means no coach marks either, even on a self-started session.
      await startSession(tester);
      await settle(tester);

      expect(find.byType(CoachMarkLayer), findsNothing);
      expect(session(tester).phase, SessionPhase.running);
    });
  });

  group('shows once', () {
    late Directory directory;
    late File file;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('pip_garden_test');
      file = File('${directory.path}/pip_garden.sqlite');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    /// Launches, runs onboarding via [act], then relaunches from the same file.
    Future<void> launchTwice(
      WidgetTester tester,
      Future<void> Function() firstTime,
    ) async {
      final first = AppDatabase.inFile(file);
      await pumpApp(tester, clock: clock, database: first, firstLaunch: true);
      await firstTime();
      await killApp(tester);
      await first.close();

      final second = AppDatabase.inFile(file);
      addTearDown(second.close);
      // firstLaunch again so the harness writes nothing; we're checking what
      // the app wrote.
      await pumpApp(tester, clock: clock, database: second, firstLaunch: true);
    }

    testWidgets('not shown again after starting a session', (tester) async {
      await launchTwice(tester, () => runOnboarding(tester));

      expect(find.byType(OnboardingSteps), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('not shown again after skipping', (tester) async {
      await launchTwice(tester, () => skip(tester));

      expect(find.byType(OnboardingSteps), findsNothing);
    });

    testWidgets('debug reset brings it back across relaunch', (tester) async {
      // The documented way to see onboarding again (README, Onboarding). It
      // writes the flag, so it's a real first launch.
      await launchTwice(tester, () => runOnboarding(tester));

      await tapTab(tester, AppTab.settings);
      await tester.tap(await scrollToSetting(
        tester,
        SettingsKeys.onboardingReset,
      ));
      await settle(tester);

      expect(find.byType(OnboardingSteps), findsOneWidget);
      expect(find.text('Focus, and something grows'), findsOneWidget);

      await killApp(tester);
      final third = AppDatabase.inFile(file);
      addTearDown(third.close);
      await pumpApp(tester, clock: clock, database: third, firstLaunch: true);

      expect(find.byType(OnboardingSteps), findsOneWidget);
    });
  });

  group('the coach marks', () {
    testWidgets('three marks, one at a time, over the session', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester);

      expect(CoachMark.values, hasLength(3));

      for (final mark in CoachMark.values) {
        expect(find.byType(CoachMarkLayer), findsOneWidget,
            reason: '${mark.name} is showing');
        expect(find.text('Got it'), findsOneWidget,
            reason: 'one at a time');
        // The outline only draws when the real widget is found, so this catches
        // a missing key on the ring or a tab destination.
        expect(find.byKey(CoachMarkLayer.highlightKey), findsOneWidget,
            reason: '${mark.name} found its target');
        expect(session(tester).phase, SessionPhase.running);
        await dismissCoachMark(tester);
      }

      expect(find.byType(CoachMarkLayer), findsNothing);
    });

    testWidgets('each is dismissed separately', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester);

      expect(find.text('Your first session is growing'), findsOneWidget);
      await dismissCoachMark(tester);

      // Dismissing one shows the next, not all of them.
      expect(find.text('Your first session is growing'), findsNothing);
      expect(find.text('Finished sessions live here'), findsOneWidget);
    });

    testWidgets('never block the session', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester);

      // No barrier or modal route, so session controls still work.
      expect(find.byType(CoachMarkLayer), findsOneWidget);
      await pauseSession(tester);
      expect(session(tester).phase, SessionPhase.paused);

      await resumeSession(tester);
      expect(session(tester).phase, SessionPhase.running);
      expect(find.byType(CoachMarkLayer), findsOneWidget,
          reason: 'using the app does not dismiss the mark');
    });

    testWidgets('session completes with marks ignored', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester);

      // Never dismissed, still completes and plants.
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      expect(session(tester).phase, SessionPhase.completed);
    });
  });

  group('the first session', () {
    testWidgets('opens the timer, counting down', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester, choosing: SessionPreset.short);

      // The app opens on the garden; after START the user should see the timer.
      expect(find.text('Focusing'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
    });

    testWidgets('drops the seed on screen', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await next(tester);
      await next(tester);

      // Pump frame by frame; settling would skip the 800ms drop.
      await tester.tap(find.byKey(OnboardingKeys.start));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Handing off to the timer means the first-time user sees the seed drop.
      expect(find.byType(GrowingPlant), findsOneWidget);
      expect(pose(tester).sprite, isNotNull);
      expect(pose(tester).drop, greaterThan(0),
          reason: 'the seed is still on its way down');

      await tester.pump(GrowingPlant.dropDuration);
      expect(pose(tester).drop, 0, reason: 'landed');
      expect(pose(tester).burst, greaterThan(0),
          reason: 'soil burst on landing');
    });

    testWidgets('dismissing the last mark restarts nothing', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester);
      await tester.pump(GrowingPlant.dropDuration);

      for (final _ in CoachMark.values) {
        await dismissCoachMark(tester);
      }

      // If the last dismissal rebuilt the shell the seed would drop again.
      expect(pose(tester).drop, 0);
      expect(session(tester).phase, SessionPhase.running);
    });
  });

  group('the welcome garden', () {
    testWidgets("is full and not the user's garden", (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await pumpApp(
        tester,
        clock: clock,
        database: database,
        firstLaunch: true,
      );

      expect(find.byType(GardenPreview), findsOneWidget);
      // The welcome garden is full; the user's own one is still empty.
      expect(GardenPreview.layout.plants.length, greaterThanOrEqualTo(12));

      // One quad per plot plus one per thing on it, so bare soil would have as
      // many quads as plots.
      final painter = tester
          .widgetList<CustomPaint>(find.descendant(
            of: find.byType(GardenPreview),
            matching: find.byType(CustomPaint),
          ))
          .map((paint) => paint.painter)
          .whereType<GardenPainter>()
          .single;
      final drawn = painter.batchFor(tester.getSize(find.byType(GardenPreview)));
      expect(
        drawn.transforms.length,
        greaterThan(GardenPreview.layout.plots.length),
        reason: 'the preview draws plants, not just soil',
      );

      expect(
        GardenPreview.layout.plants.map((plant) => plant.type).toSet(),
        containsAll(PlantType.grownBySessions),
        reason: 'every plant type, so the preview shows what is on offer',
      );

      await skip(tester);
      await tapTab(tester, AppTab.garden);

      expect(await DriftPlantRepository(database).plants(), isEmpty,
          reason: 'nothing in the preview was ever planted');
      expect(
        find.text('Finish a session and your first plant goes in here.'),
        findsOneWidget,
      );
    });
  });

  group('timing', () {
    /// Time to read a two-sentence step at a normal pace.
    const Duration reading = Duration(seconds: 8);

    testWidgets('first launch to running session under a minute',
        (tester) async {
      final started = tester.binding.clock.now();

      await pumpApp(tester, clock: clock, firstLaunch: true);

      // Four decisions at [reading] each. The pumps advance the same clock
      // being measured.
      await tester.pump(reading);
      await next(tester);

      await tester.pump(reading);
      await tester.tap(find.byKey(OnboardingKeys.preset(SessionPreset.short)));
      await settle(tester);

      await tester.pump(reading);
      await next(tester);

      await tester.pump(reading);
      await startFirstSession(tester);

      final took = tester.binding.clock.now().difference(started);

      expect(session(tester).phase, SessionPhase.running,
          reason: 'the clock stops when a session is actually running');
      expect(took, greaterThan(reading * OnboardingStep.values.length),
          reason: 'reading time included: $took');
      expect(took, lessThan(const Duration(seconds: 60)),
          reason: '$took from launch to a running session');
    });
  });
}
