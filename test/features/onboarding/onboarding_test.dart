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

/// REQ-003: a new user, from a first launch to a running session, with nothing
/// in the way.
///
/// Driven through the real app throughout — there is no onboarding screen to
/// pump on its own here, and that is deliberate: what the ticket asks for is
/// three steps *over* the app and coach marks *on* it, so a test that built the
/// flow in isolation would be testing the half that cannot go wrong.
void main() {
  late FixedClock clock;

  setUp(() => clock = FixedClock(testInstant));

  /// The session as the app has it right now.
  SessionSnapshot session(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(sessionControllerProvider);

  /// Moves on from the step on screen.
  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(OnboardingKeys.next));
    await settle(tester);
  }

  /// Leaves onboarding from wherever the user is.
  Future<void> skip(WidgetTester tester) async {
    await tester.tap(find.byKey(OnboardingKeys.skip));
    await settle(tester);
  }

  /// Takes the last step: the tap that starts everything.
  Future<void> startFirstSession(WidgetTester tester) async {
    await tester.tap(find.byKey(OnboardingKeys.start));
    await settle(tester);
  }

  /// Walks the whole flow, choosing [length] if a preset names it.
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

  /// Puts away whichever coach mark is showing.
  Future<void> dismissCoachMark(WidgetTester tester) async {
    await tester.tap(find.text('Got it'));
    await settle(tester);
  }

  /// The pose the plant on the timer is being drawn in — how §5.3's seed drop
  /// is asserted on everywhere in this suite.
  PlantPainter pose(WidgetTester tester) => tester
      .widget<CustomPaint>(
        find.descendant(
          of: find.byType(GrowingPlant),
          matching: find.byType(CustomPaint),
        ),
      )
      .painter! as PlantPainter;

  group('the three steps', () {
    testWidgets('a first launch opens on the welcome, over the app',
        (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);

      expect(find.byType(OnboardingSteps), findsOneWidget);
      expect(find.text('Focus, and something grows'), findsOneWidget);
      // The app is underneath the whole time rather than being pushed aside,
      // which is what makes the last step a hand-off rather than a navigation.
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('the app underneath is scenery while a step is up',
        (tester) async {
      final semantics = tester.ensureSemantics();

      await pumpApp(tester, clock: clock, firstLaunch: true);

      // A tap on the bar behind the welcome would take the user somewhere they
      // cannot see...
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

      // ...and a screen reader walking the app would find four tabs and a
      // timer in front of somebody who has not been past the welcome yet. The
      // app is scenery until the flow hands over to it.
      expect(find.bySemanticsLabel(RegExp('Timer')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Garden')), findsNothing);
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget,
          reason: 'what is read out is the step the user is on');

      // Disposed here rather than in a teardown: the framework checks for a
      // live handle before teardowns run.
      semantics.dispose();
    });

    testWidgets('are three, and the third one is the session', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);

      // Step one: a welcome and something to look at.
      expect(find.byType(GardenPreview), findsOneWidget);
      expect(find.byKey(OnboardingKeys.lengths), findsNothing);

      await next(tester);

      // Step two: the one choice, and nothing else to fill in.
      expect(find.byKey(OnboardingKeys.lengths), findsOneWidget);
      expect(find.byType(GardenPreview), findsNothing);

      await next(tester);

      // Step three: the tap. There is no fourth — the button on the last step
      // starts a session rather than turning another page.
      expect(find.byKey(OnboardingKeys.next), findsNothing);
      expect(find.byKey(OnboardingKeys.start), findsOneWidget);
      expect(OnboardingStep.values, hasLength(3));

      await startFirstSession(tester);

      expect(find.byType(OnboardingSteps), findsNothing);
      expect(session(tester).phase, SessionPhase.running);
    });

    testWidgets('the length chosen is written down and is what the first '
        'session runs for', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await pumpApp(
        tester,
        clock: clock,
        database: database,
        firstLaunch: true,
      );
      await runOnboarding(tester, choosing: SessionPreset.deep);

      // Nothing has elapsed yet, so what is left is what was planned.
      expect(session(tester).remaining, const Duration(minutes: 50));
      // The setting, not an onboarding-only value: the session after this one
      // runs for fifty minutes too, and the settings screen shows Deep.
      expect(
        (await DriftSettingsRepository(database).load()).sessionLength,
        const Duration(minutes: 50),
      );
    });

    testWidgets('a step nobody touched leaves REQ-002 twenty-five minutes',
        (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester);

      expect(session(tester).remaining, const Duration(minutes: 25));
    });
  });

  group('nothing in the way', () {
    testWidgets('no account, no sign-in, nothing to fill in', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);

      for (var step = 0; step < OnboardingStep.values.length; step++) {
        // REQ-001 keeps everything on the device, so there is nothing to ask
        // for. Asserted on the words rather than on the absence of a screen,
        // because the way this requirement gets broken is a well-meaning
        // "sign in to back up your garden" appearing on the welcome.
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

    testWidgets('no permission is asked for before the session is running',
        (tester) async {
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

      // The one prompt this app raises is the notification permission, and
      // ticket 06 raises it at the first START — after the session is already
      // anchored, so nothing about the answer can stop it. REQ-014's quiet mode
      // asks for nothing at all until the user turns it on themselves.
      expect(session(tester).phase, SessionPhase.running);
      expect(quietMode.accessRequests, 0);
    });

    testWidgets('a first session runs whatever the user says to the one '
        'prompt there is', (tester) async {
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
    testWidgets('every step has a way past it', (tester) async {
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

    testWidgets('skipping teaches nothing afterwards either', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await skip(tester);

      // A user who said no to a welcome has not asked to be taught three things
      // about the app instead — including on the session they start themselves.
      await startSession(tester);
      await settle(tester);

      expect(find.byType(CoachMarkLayer), findsNothing);
      expect(session(tester).phase, SessionPhase.running);
    });
  });

  group('once, and only once', () {
    late Directory directory;
    late File file;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('pip_garden_test');
      file = File('${directory.path}/pip_garden.sqlite');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    /// Launches, runs onboarding one way or another, then relaunches from the
    /// same file the way a user reopening the app does.
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
      // `firstLaunch` again, so the harness writes nothing of its own: what is
      // being tested is what the *app* wrote the first time round.
      await pumpApp(tester, clock: clock, database: second, firstLaunch: true);
    }

    testWidgets('a session started is a welcome not seen again',
        (tester) async {
      await launchTwice(tester, () => runOnboarding(tester));

      expect(find.byType(OnboardingSteps), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('a welcome skipped is a welcome not seen again',
        (tester) async {
      await launchTwice(tester, () => skip(tester));

      expect(find.byType(OnboardingSteps), findsNothing);
    });

    testWidgets('the debug reset puts it back, and it is still back after a '
        'relaunch', (tester) async {
      // The documented way to see onboarding twice — see the Onboarding section
      // in README.md. It writes the flag rather than only moving the screen,
      // which is what makes it a first launch rather than a screen borrowed for
      // a moment.
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
    testWidgets('are three, one at a time, over the running session',
        (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester);

      expect(CoachMark.values, hasLength(3));

      for (final mark in CoachMark.values) {
        expect(find.byType(CoachMarkLayer), findsOneWidget,
            reason: '${mark.name} is showing');
        expect(find.text('Got it'), findsOneWidget,
            reason: 'one at a time, never three cards at once');
        // Over the live UI rather than beside it: the outline is only drawn
        // when the real widget was found, so this is what would fail if the
        // ring or a tab destination stopped carrying its key.
        expect(find.byKey(CoachMarkLayer.highlightKey), findsOneWidget,
            reason: '${mark.name} found the thing it is about');
        // The session is running underneath the whole way through.
        expect(session(tester).phase, SessionPhase.running);
        await dismissCoachMark(tester);
      }

      expect(find.byType(CoachMarkLayer), findsNothing);
    });

    testWidgets('each is dismissed on its own, and the first one is enough',
        (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester);

      expect(find.text('Your first session is growing'), findsOneWidget);
      await dismissCoachMark(tester);

      // Putting one away shows the next rather than all of them, and putting
      // that one away is a separate decision.
      expect(find.text('Your first session is growing'), findsNothing);
      expect(find.text('Finished sessions live here'), findsOneWidget);
    });

    testWidgets('never block the session', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester);

      // The coach mark is up, and the session's own controls still work. This
      // is the requirement: there is no barrier and no modal route, so a user
      // who wants to hold their session while a card is on screen can.
      expect(find.byType(CoachMarkLayer), findsOneWidget);
      await pauseSession(tester);
      expect(session(tester).phase, SessionPhase.paused);

      await resumeSession(tester);
      expect(session(tester).phase, SessionPhase.running);
      expect(find.byType(CoachMarkLayer), findsOneWidget,
          reason: 'using the app does not dismiss the mark either');
    });

    testWidgets('a session ignored through all three still completes',
        (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester);

      // Nothing is dismissed. A user who never touches a coach mark has a
      // session that finishes and a plant in the ground all the same.
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      expect(session(tester).phase, SessionPhase.completed);
    });
  });

  group('the first session', () {
    testWidgets('lands on the timer, counting down', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester, choosing: SessionPreset.short);

      // The garden is the tab the app opens on; a user who has just tapped
      // START is owed the screen their session is on.
      expect(find.text('Focusing'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
    });

    testWidgets('drops its seed where the user can see it', (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await next(tester);
      await next(tester);

      // Frame by frame rather than through the helper, because the helper
      // settles and the whole of what this test is about is the eight hundred
      // milliseconds that settling would skip over.
      await tester.tap(find.byKey(OnboardingKeys.start));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // US-005, and the reason the flow hands off to the timer rather than
      // starting a session behind whatever tab the user happened to be on: the
      // seed dropping is the reward loop's first frame, and a first-time user
      // has to be looking at it.
      expect(find.byType(GrowingPlant), findsOneWidget);
      expect(pose(tester).sprite, isNotNull);
      expect(pose(tester).drop, greaterThan(0),
          reason: 'the seed is still on its way down');

      await tester.pump(GrowingPlant.dropDuration);
      expect(pose(tester).drop, 0, reason: 'and it lands');
      expect(pose(tester).burst, greaterThan(0),
          reason: 'REQ-004: soil is thrown up as it lands');
    });

    testWidgets('the last coach mark going away does not restart anything',
        (tester) async {
      await pumpApp(tester, clock: clock, firstLaunch: true);
      await runOnboarding(tester);
      await tester.pump(GrowingPlant.dropDuration);

      for (final _ in CoachMark.values) {
        await dismissCoachMark(tester);
      }

      // The app underneath onboarding is the app the user keeps. If the last
      // dismissal rebuilt the shell, the seed would drop a second time — five
      // minutes into a session, for a user who is watching.
      expect(pose(tester).drop, 0);
      expect(session(tester).phase, SessionPhase.running);
    });
  });

  group('the welcome garden', () {
    testWidgets('is lush, and is not the user own garden', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await pumpApp(
        tester,
        clock: clock,
        database: database,
        firstLaunch: true,
      );

      expect(find.byType(GardenPreview), findsOneWidget);
      // US-002 the honest way round: the garden on the welcome is full, and the
      // one the user owns is still empty when they get to it.
      expect(GardenPreview.layout.plants.length, greaterThanOrEqualTo(12));

      // And it is really being drawn, plants and all. The painter batches one
      // quad per plot and a second for whatever is standing on it, so a preview
      // of bare soil would have exactly as many quads as it has plots.
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

  group('how long it takes', () {
    /// What one step costs a user who is reading it rather than racing: long
    /// enough to take in a screen of two sentences and decide, at the pace
    /// somebody sitting down with a new app actually moves.
    const Duration reading = Duration(seconds: 8);

    testWidgets('a first launch reaches a running session in under a minute',
        (tester) async {
      final started = tester.binding.clock.now();

      await pumpApp(tester, clock: clock, firstLaunch: true);

      // Four decisions, at [reading] apiece, with every frame the app spends
      // opening, laying out and animating counted in between — the pumps below
      // advance the same clock this is measured against.
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
          reason: 'the reading time is really in the measurement: $took');
      expect(took, lessThan(const Duration(seconds: 60)),
          reason: 'US-001: $took from launch to a session running');
    });
  });
}
