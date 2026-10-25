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

/// Ticket 26: PRD §9.2's four micro-sounds, at the four moments that already
/// existed.
///
/// Every one of them is a line added where something already happens, so every
/// test here drives the app the way a user does and asks what it sounded like.
/// The files themselves, and the audio session they go out on, are in
/// `test/feedback/micro_sounds_test.dart`.
void main() {
  group('the soil settles as the seed lands', () {
    testWidgets('at the end of the drop, not the start of it', (tester) async {
      // §5.4 puts the sound at "seed planted" and §5.3 puts the landing a fifth
      // of the way from the end of the 0.8-second fall — where the particle
      // burst is drawn. A sound at the moment START was tapped would be a sound
      // for a seed still in the air.
      final sounds = FakeMicroSounds();
      await pumpApp(tester, microSounds: sounds);
      await tapTab(tester, AppTab.timer);

      await tester.tap(find.text('Plant it'));
      await tester.pump();

      // Most of the way down, and nothing has landed yet.
      await tester.pump(GrowingPlant.dropDuration * 0.5);
      expect(sounds.countOf(MicroSound.soilSettle), 0,
          reason: 'the seed is still falling');

      await tester.pump(GrowingPlant.dropDuration * 0.45);
      expect(sounds.countOf(MicroSound.soilSettle), 1);

      // And once, however many frames the rest of the fall takes.
      await settle(tester);
      expect(sounds.countOf(MicroSound.soilSettle), 1);
    });

    testWidgets('once per seed, and again for the next session',
        (tester) async {
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(tester, clock: clock, microSounds: sounds);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      expect(sounds.countOf(MicroSound.soilSettle), 1);

      // A second session drops a second seed: a different plant, not a
      // further-grown one.
      await tester.tap(find.text('Plant another'));
      await settle(tester);
      expect(sounds.countOf(MicroSound.soilSettle), 2);
    });

    testWidgets('and again on a relaunch, because the seed drops again',
        (tester) async {
      // Worth pinning rather than leaving to be discovered. Opening the app
      // mid-session *re-runs* the drop — that is ticket 04's animation and not
      // this ticket's business — and the sound follows the picture, because the
      // picture is the rule: the soil settle is the particle burst's sound, and
      // a burst drawn in silence would be the odder of the two outcomes.
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

    testWidgets('and clearing the soil makes no sound at all', (tester) async {
      // Cancelling takes the plant away. The drop controller is jumped back to
      // zero rather than animated, and nothing has landed.
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

  group('the shimmer follows a growth stage', () {
    testWidgets('at the same moment REQ-037\'s subtler haptic fires',
        (tester) async {
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

      // REQ-016's thresholds, crossed one at a time — a single jump to the end
      // would arrive at the last stage with the completion, which is a
      // different event and the louder of the two.
      await advance(tester, clock, const Duration(minutes: 5));
      expect(sounds.countOf(MicroSound.growthShimmer), 1);
      expect(haptics.growths, 1);

      await advance(tester, clock, const Duration(minutes: 8));
      expect(sounds.countOf(MicroSound.growthShimmer), 2);
      expect(haptics.growths, 2);

      await advance(tester, clock, const Duration(minutes: 8));
      expect(sounds.countOf(MicroSound.growthShimmer), 3);
      expect(haptics.growths, 3);

      // The last stage arrives with the completion, and the completion is the
      // louder of the two — for the shimmer exactly as for the haptic.
      await advance(tester, clock, const Duration(minutes: 4));
      await settle(tester);
      expect(sounds.countOf(MicroSound.growthShimmer), 3);
      expect(haptics.growths, 3);
    });

    testWidgets('and keeps going when the haptics switch is off',
        (tester) async {
      // REQ-037's switch is about whether the app talks to the user's *hand*. A
      // user who turned off the buzzing did not ask for silence, and reading it
      // as a request for silence would make one control cover two things.
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

    testWidgets('and says nothing about a plant that grew while the app was '
        'away', (tester) async {
      // A sound for something the user cannot see is noise. The stage will be
      // right on screen whenever they look.
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(tester, clock: clock, microSounds: sounds);

      await startSession(tester);
      await settle(tester);
      await sendToBackground(tester);

      // Far enough to cross REQ-016's first threshold, which would have been a
      // shimmer with anybody watching.
      await advance(tester, clock, const Duration(minutes: 5));
      await settle(tester);
      expect(sounds.countOf(MicroSound.growthShimmer), 0);

      // And it is not saved up for their return, either. They were not told
      // because there was nothing to tell them; the stage is on screen now.
      await bringToForeground(tester);
      await settle(tester);
      expect(sounds.countOf(MicroSound.growthShimmer), 0);
    });
  });

  group('the tap is on the five actions that start or end something', () {
    testWidgets('START, and the seed that follows it', (tester) async {
      final sounds = FakeMicroSounds();
      await pumpApp(tester, microSounds: sounds);
      await tapTab(tester, AppTab.timer);

      await tester.tap(find.text('Plant it'));
      await tester.pump();

      // The tap first, before anything has moved.
      expect(sounds.played, [MicroSound.buttonTap]);

      await settle(tester);
      expect(sounds.played,
          [MicroSound.buttonTap, MicroSound.soilSettle]);
    });

    testWidgets('and onboarding\'s START, which is a START like any other',
        (tester) async {
      // The list is about what a tap *does*, not which screen it is on: this
      // one begins a real session. Skip and Next are silent — one abandons the
      // flow and the other turns a page.
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

    testWidgets('Pause and Resume', (tester) async {
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

    testWidgets('a Cancel that is confirmed, and not the one that opens the '
        'question', (tester) async {
      final clock = FixedClock(testInstant);
      final sounds = FakeMicroSounds();
      await pumpApp(tester, clock: clock, microSounds: sounds);

      await startSession(tester);
      await settle(tester);
      sounds.played.clear();

      // Backing out ends nothing, so it sounds like nothing.
      await cancelSession(tester, confirm: false);
      await settle(tester);
      expect(sounds.countOf(MicroSound.buttonTap), 0);

      await cancelSession(tester, confirm: true);
      await settle(tester);
      expect(sounds.countOf(MicroSound.buttonTap), 1);
    });

    testWidgets('and accepting a break', (tester) async {
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

    testWidgets('but not skipping one — a break walked out of is silent '
        'everywhere else too', (tester) async {
      // `SessionMachine.endBreak` puts a skipped break in `idle` rather than
      // `breakOver` precisely so that it makes no sound. A tap on the one
      // control a break has would take that back.
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

    testWidgets('and nothing on the screens that are not the timer',
        (tester) async {
      // The other half of "the list is the requirement": a settings row, a tab
      // and a bed chip are all taps, and none of them starts or ends anything.
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

    testWidgets('and nothing when a break starts itself', (tester) async {
      // REQ-032's auto-start calls the same controller method a tap does, with
      // nobody touching anything. That is why the sound is at the control
      // rather than in `SessionController`.
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

  group('the unlock is a milestone award, not a plot', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting();
      addTearDown(database.close);
    });

    testWidgets('and it plays as the card rises', (tester) async {
      // REQ-021's tenth session. REQ-018 unlocks four plots at the same moment
      // and makes no sound: a plot unlock is a floor derived from a count, with
      // nothing on screen to explain a sound with.
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

    testWidgets('and nothing when the card rises with the app away',
        (tester) async {
      // The celebration waits on a real timer, and a timer goes on running when
      // the app is put away mid-wait. The *card* still rises — a celebration
      // the user never saw costs them the animation and not the plant — but a
      // sound in an empty room is only a sound in an empty room.
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

      // Away before the wait is out, so the celebration lands with nobody
      // looking at it.
      await sendToBackground(tester);
      await tester.pump(const Duration(seconds: 2));

      // Back again. The card is on screen, which is what says the celebration
      // really did happen while the app was away rather than waiting for the
      // return — a paused binding draws no frames, so this is the first moment
      // it could be rendered. See `sendToBackground`.
      await bringToForeground(tester);
      await settle(tester);

      expect(find.byType(MilestoneCard), findsOneWidget,
          reason: 'the card is still owed, and still arrives');
      // And it arrived in silence: the sound would have been for a room with
      // nobody in it, and it is not saved up for their return either.
      expect(sounds.countOf(MicroSound.unlock), 0);
    });

    testWidgets('and nothing at nine sessions', (tester) async {
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

/// Runs [count] sessions to completion, one after another.
Future<void> completeSessions(
  WidgetTester tester,
  FixedClock clock,
  int count,
) async {
  await tapTab(tester, AppTab.timer);
  for (var i = 0; i < count; i++) {
    // The first from rest; each after it from the end of the one before.
    await tester.tap(find.text(i == 0 ? 'Plant it' : 'Plant another').last);
    await tester.pump();
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);
  }
}
