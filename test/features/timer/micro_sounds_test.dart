import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/feedback/micro_sounds.dart';
import 'package:pip_garden/src/features/garden/milestone_card.dart';
import 'package:pip_garden/src/features/onboarding/onboarding_steps.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/features/timer/ambience_picker.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/announcement_fakes.dart';
import '../../support/app_harness.dart';

// The four micro-sounds, driven through the app. The files and audio session
// are tested in test/feedback/micro_sounds_test.dart.
void main() {
  group('soil settle', () {
    testWidgets('plays at landing, not at START', (tester) async {
      // The landing is a fifth of the way from the end of the 0.8s fall, where
      // the particle burst is drawn. Not at the START tap.
      final sounds = FakeMicroSounds();
      await pumpApp(tester, microSounds: sounds);
      await tapTab(tester, AppTab.timer);

      await tester.tap(find.text('Plant it'));
      await tester.pump();

      // Halfway down, nothing landed yet.
      await tester.pump(GrowingPlant.dropDuration * 0.5);
      expect(sounds.countOf(MicroSound.soilSettle), 0,
          reason: 'the seed is still falling');

      await tester.pump(GrowingPlant.dropDuration * 0.45);
      expect(sounds.countOf(MicroSound.soilSettle), 1);

      // Only once, however many frames are left.
      await settle(tester);
      expect(sounds.countOf(MicroSound.soilSettle), 1);
    });

    testWidgets('once per seed', (tester) async {
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(tester, clock: clock, microSounds: sounds);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      expect(sounds.countOf(MicroSound.soilSettle), 1);

      await tester.tap(find.text('Plant another'));
      await settle(tester);
      expect(sounds.countOf(MicroSound.soilSettle), 2);
    });

    testWidgets('plays again on relaunch', (tester) async {
      // Opening mid-session re-runs the drop animation, and the sound follows
      // the burst.
      final directory = Directory.systemTemp.createTempSync('pip_garden');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/pip_garden.sqlite');

      final clock = FixedClock(testInstant);
      final firstLaunch = AppDatabase.inFile(file);
      await pumpApp(tester, clock: clock, database: firstLaunch);
      await startSession(tester);
      await settle(tester);

      await killApp(tester);
      await firstLaunch.close();
      clock.advance(const Duration(minutes: 4));

      final secondLaunch = AppDatabase.inFile(file);
      addTearDown(secondLaunch.close);
      final sounds = FakeMicroSounds();
      await pumpApp(
        tester,
        clock: clock,
        database: secondLaunch,
        microSounds: sounds,
      );
      await tapTab(tester, AppTab.timer);
      await settle(tester);

      expect(sounds.countOf(MicroSound.soilSettle), 1);
    });

    testWidgets('silent on cancel', (tester) async {
      // Cancel jumps the drop controller to zero; nothing lands.
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(tester, clock: clock, microSounds: sounds);

      await startSession(tester);
      await settle(tester);
      final afterTheSeed = sounds.countOf(MicroSound.soilSettle);

      await cancelSession(tester, confirm: true);
      await settle(tester);

      expect(sounds.countOf(MicroSound.soilSettle), afterTheSeed);
    });
  });

  group('growth shimmer', () {
    testWidgets('plays with the growth haptic', (tester) async {
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      final haptics = FakeHaptics();
      await pumpApp(
        tester,
        clock: clock,
        microSounds: sounds,
        haptics: haptics,
      );

      await startSession(tester);
      expect(sounds.countOf(MicroSound.growthShimmer), 0,
          reason: 'a seed has not grown into anything');

      // Cross thresholds one at a time; jumping to the end would only hit the
      // completion.
      await advance(tester, clock, const Duration(minutes: 5));
      expect(sounds.countOf(MicroSound.growthShimmer), 1);
      expect(haptics.growths, 1);

      await advance(tester, clock, const Duration(minutes: 8));
      expect(sounds.countOf(MicroSound.growthShimmer), 2);
      expect(haptics.growths, 2);

      await advance(tester, clock, const Duration(minutes: 8));
      expect(sounds.countOf(MicroSound.growthShimmer), 3);
      expect(haptics.growths, 3);

      // The last stage comes with the completion, which wins.
      await advance(tester, clock, const Duration(minutes: 4));
      await settle(tester);
      expect(sounds.countOf(MicroSound.growthShimmer), 3);
      expect(haptics.growths, 3);
    });

    testWidgets('plays with haptics off', (tester) async {
      // The switch is haptics only, not sound.
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      final haptics = FakeHaptics();
      await pumpApp(
        tester,
        clock: clock,
        microSounds: sounds,
        haptics: haptics,
        settings: GardenSettings.defaults.withHaptics(enabled: false),
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));

      expect(haptics.growths, 0);
      expect(sounds.countOf(MicroSound.growthShimmer), 1);
    });

    testWidgets('silent for growth while away', (tester) async {
      // No sound for something nobody can see.
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(tester, clock: clock, microSounds: sounds);

      await startSession(tester);
      await settle(tester);
      await sendToBackground(tester);

      // Crosses the first threshold.
      await advance(tester, clock, const Duration(minutes: 5));
      await settle(tester);
      expect(sounds.countOf(MicroSound.growthShimmer), 0);

      // Not saved up for the return either.
      await bringToForeground(tester);
      await settle(tester);
      expect(sounds.countOf(MicroSound.growthShimmer), 0);
    });
  });

  group('button tap', () {
    testWidgets('on START', (tester) async {
      final sounds = FakeMicroSounds();
      await pumpApp(tester, microSounds: sounds);
      await tapTab(tester, AppTab.timer);

      await tester.tap(find.text('Plant it'));
      await tester.pump();

      // The tap comes first.
      expect(sounds.played, [MicroSound.buttonTap]);

      await settle(tester);
      expect(sounds.played,
          [MicroSound.buttonTap, MicroSound.soilSettle]);
    });

    testWidgets('on onboarding START', (tester) async {
      // Onboarding's START starts a real session. Skip and Next are silent.
      final sounds = FakeMicroSounds();
      await pumpApp(tester, microSounds: sounds, firstLaunch: true);

      await tester.tap(find.byKey(OnboardingKeys.next));
      await settle(tester);
      await tester.tap(find.byKey(OnboardingKeys.next));
      await settle(tester);
      expect(sounds.countOf(MicroSound.buttonTap), 0,
          reason: 'Next turns a page and starts nothing');

      await tester.tap(find.byKey(OnboardingKeys.start));
      await settle(tester);

      expect(sounds.countOf(MicroSound.buttonTap), 1);
    });

    testWidgets('on pause and resume', (tester) async {
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(tester, clock: clock, microSounds: sounds);

      await startSession(tester);
      await settle(tester);
      sounds.played.clear();

      await pauseSession(tester);
      expect(sounds.countOf(MicroSound.buttonTap), 1);

      await resumeSession(tester);
      expect(sounds.countOf(MicroSound.buttonTap), 2);
    });

    testWidgets('on confirmed cancel only', (tester) async {
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(tester, clock: clock, microSounds: sounds);

      await startSession(tester);
      await settle(tester);
      sounds.played.clear();

      // Backing out ends nothing, so no sound.
      await cancelSession(tester, confirm: false);
      await settle(tester);
      expect(sounds.countOf(MicroSound.buttonTap), 0);

      await cancelSession(tester, confirm: true);
      await settle(tester);
      expect(sounds.countOf(MicroSound.buttonTap), 1);
    });

    testWidgets('on accepting a break', (tester) async {
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(tester, clock: clock, microSounds: sounds);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      sounds.played.clear();

      await tester.tap(find.textContaining('break'));
      await settle(tester);

      expect(sounds.countOf(MicroSound.buttonTap), 1);
    });

    testWidgets('not on skipping a break', (tester) async {
      // endBreak puts a skipped break in idle rather than breakOver so it's
      // silent. A tap sound here would undo that.
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(tester, clock: clock, microSounds: sounds);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      await tester.tap(find.textContaining('break'));
      await settle(tester);
      sounds.played.clear();

      await tester.tap(find.text('Skip break'));
      await settle(tester);

      expect(sounds.countOf(MicroSound.buttonTap), 0);
    });

    testWidgets('not on other screens', (tester) async {
      // Settings rows, tabs and ambient chips start or end nothing.
      final sounds = FakeMicroSounds();
      await pumpApp(tester, microSounds: sounds);

      await tapTab(tester, AppTab.garden);
      await tapTab(tester, AppTab.journal);
      await tapTab(tester, AppTab.settings);
      await tester.tap(await scrollToSetting(tester, SettingsKeys.haptics));
      await settle(tester);

      await tapTab(tester, AppTab.timer);
      final chip = find.byKey(AmbienceKeys.chip(AmbientSound.rain));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await settle(tester);

      expect(sounds.played, isEmpty);
    });

    testWidgets('not on auto-started break', (tester) async {
      // Auto-start calls the same controller method as a tap, which is why the
      // sound lives in the control rather than SessionController.
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(
        tester,
        clock: clock,
        microSounds: sounds,
        settings: GardenSettings.defaults.withAutoStartBreak(enabled: true),
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      sounds.played.clear();

      await advance(tester, clock, const Duration(minutes: 5));
      await settle(tester);

      expect(sounds.countOf(MicroSound.buttonTap), 0);
    });
  });

  group('unlock sound', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting();
      addTearDown(database.close);
    });

    testWidgets('plays as the milestone card rises', (tester) async {
      // Tenth session. The plot unlock happens at the same time but is silent.
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        microSounds: sounds,
      );

      await completeSessions(tester, clock, 10);
      sounds.played.clear();
      await settle(tester);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);

      expect(find.byType(MilestoneCard), findsOneWidget);
      expect(sounds.countOf(MicroSound.unlock), 1);
    });

    testWidgets('silent when the card rises in the background', (tester) async {
      // The celebration waits on a real timer that keeps running in the
      // background. The card still shows, but no sound.
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        microSounds: sounds,
      );

      await completeSessions(tester, clock, 10);
      sounds.played.clear();

      // Background before the wait finishes.
      await sendToBackground(tester);
      await tester.pump(const Duration(seconds: 2));

      // A paused binding draws no frames, so this is the first chance to render
      // the card. See sendToBackground.
      await bringToForeground(tester);
      await settle(tester);

      expect(find.byType(MilestoneCard), findsOneWidget,
          reason: 'card still shows');
      expect(sounds.countOf(MicroSound.unlock), 0);
    });

    testWidgets('silent at nine sessions', (tester) async {
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        microSounds: sounds,
      );

      await completeSessions(tester, clock, 9);
      await settle(tester);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);

      expect(sounds.countOf(MicroSound.unlock), 0);
    });
  });
}

Future<void> completeSessions(
  WidgetTester tester,
  FixedClock clock,
  int count,
) async {
  await tapTab(tester, AppTab.timer);
  for (var i = 0; i < count; i++) {
    await tester.tap(find.text(i == 0 ? 'Plant it' : 'Plant another').last);
    await tester.pump();
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);
  }
}
