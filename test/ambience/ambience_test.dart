import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/features/timer/ambience_picker.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/ambience_fake.dart';
import '../support/announcement_fakes.dart';
import '../support/app_harness.dart';

/// Ambient beds. A bed belongs to a focus session, running or held, and
/// nothing else: idle and breaks are silent, and a session ending by any route
/// takes its bed with it.
///
/// Seams, background playback and call handling can't be tested here; see
/// `bundled_audio_test.dart`, `test/platform/background_audio_test.dart` and
/// `audio_interruptions_test.dart`.
void main() {
  Future<void> pick(WidgetTester tester, AmbientSound sound) async {
    final chip = find.byKey(AmbienceKeys.chip(sound));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await settle(tester);
  }

  group('picking a bed', () {
    testWidgets('all six are on the timer screen, silence included',
        (tester) async {
      await pumpApp(tester);
      await tapTab(tester, AppTab.timer);

      for (final sound in AmbientSound.values) {
        expect(find.byKey(AmbienceKeys.chip(sound)), findsOneWidget,
            reason: '${sound.label} is missing');
      }
    });

    testWidgets('nothing plays until a session is running', (tester) async {
      final ambience = FakeAmbience();
      await pumpApp(tester, ambience: ambience);
      await tapTab(tester, AppTab.timer);

      await pick(tester, AmbientSound.rain);

      // Picking on an idle timer chooses the next session's bed; it shouldn't
      // start playing.
      expect(ambience.playing, AmbientSound.silence);
      expect(ambience.starts, 0);
    });

    testWidgets('the bed chosen before START is what the session runs under',
        (tester) async {
      final ambience = FakeAmbience();
      await pumpApp(tester, ambience: ambience);
      await tapTab(tester, AppTab.timer);

      await pick(tester, AmbientSound.forest);
      await startSession(tester);
      await settle(tester);

      expect(ambience.playing, AmbientSound.forest);
    });

    testWidgets('choosing Silence mid-session takes the bed down',
        (tester) async {
      final ambience = FakeAmbience();
      await pumpApp(
        tester,
        ambience: ambience,
        settings: GardenSettings.defaults.withAmbientSound(AmbientSound.rain),
      );

      await startSession(tester);
      await settle(tester);
      expect(ambience.playing, AmbientSound.rain);

      await pick(tester, AmbientSound.silence);

      expect(ambience.playing, AmbientSound.silence);
    });
  });

  group('changing it mid-session', () {
    testWidgets('swaps the bed without stopping first', (tester) async {
      final clock = FixedClock(testInstant);
      final ambience = FakeAmbience();
      await pumpApp(
        tester,
        clock: clock,
        ambience: ambience,
        settings: GardenSettings.defaults.withAmbientSound(AmbientSound.rain),
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 11));
      await pick(tester, AmbientSound.cafe);

      // The café is asked for directly over the rain, with no stop in between.
      expect(ambience.playing, AmbientSound.cafe);
      expect(ambience.everPlayed,
          [AmbientSound.rain, AmbientSound.cafe]);
      expect(ambience.stops, 0);
    });

    testWidgets('the session it interrupted is not one of them',
        (tester) async {
      final clock = FixedClock(testInstant);
      await pumpApp(
        tester,
        clock: clock,
        settings: GardenSettings.defaults.withAmbientSound(AmbientSound.rain),
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 11));
      await pick(tester, AmbientSound.ocean);
      await advance(tester, clock, const Duration(minutes: 14));
      await settle(tester);

      // Changing the bed doesn't restart the session.
      expect(find.text('Session complete'), findsOneWidget);
    });
  });

  group('what the bed follows', () {
    testWidgets('a held session keeps its bed', (tester) async {
      final clock = FixedClock(testInstant);
      final ambience = FakeAmbience();
      await pumpApp(
        tester,
        clock: clock,
        ambience: ambience,
        settings: GardenSettings.defaults.withAmbientSound(AmbientSound.rain),
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 2));

      // Stopping and restarting around a pause would put in a gap.
      expect(ambience.playing, AmbientSound.rain);
      expect(ambience.stops, 0);

      await resumeSession(tester);
      expect(ambience.playing, AmbientSound.rain);
      expect(ambience.starts, 1, reason: 'started once, for the whole session');
    });

    testWidgets('a session that completes takes its bed with it',
        (tester) async {
      final clock = FixedClock(testInstant);
      final ambience = FakeAmbience();
      final sound = FakeEndSoundPlayer();
      await pumpApp(
        tester,
        clock: clock,
        ambience: ambience,
        endSound: sound,
        settings: GardenSettings.defaults.withAmbientSound(AmbientSound.ocean),
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      // On purpose: `Ambience.stop` fades, so the chime plays over a bed on its
      // way out.
      expect(sound.plays, 1);
      expect(ambience.playing, AmbientSound.silence);
      expect(ambience.stops, 1);
    });

    testWidgets('a cancelled session takes its bed with it', (tester) async {
      final clock = FixedClock(testInstant);
      final ambience = FakeAmbience();
      await pumpApp(
        tester,
        clock: clock,
        ambience: ambience,
        settings:
            GardenSettings.defaults.withAmbientSound(AmbientSound.whiteNoise),
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));
      await cancelSession(tester, confirm: true);

      expect(ambience.playing, AmbientSound.silence);
    });

    testWidgets('a session kept after a change of mind keeps its bed',
        (tester) async {
      final clock = FixedClock(testInstant);
      final ambience = FakeAmbience();
      await pumpApp(
        tester,
        clock: clock,
        ambience: ambience,
        settings: GardenSettings.defaults.withAmbientSound(AmbientSound.rain),
      );

      await startSession(tester);
      await cancelSession(tester, confirm: false);

      expect(ambience.playing, AmbientSound.rain);
      expect(ambience.stops, 0);
    });

    testWidgets('a break has no bed, and the session after it gets one back',
        (tester) async {
      final clock = FixedClock(testInstant);
      final ambience = FakeAmbience();
      await pumpApp(
        tester,
        clock: clock,
        ambience: ambience,
        settings: GardenSettings.defaults.withAmbientSound(AmbientSound.forest),
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      await tester.tap(find.textContaining('break'));
      await settle(tester);

      // A break is a rest; the rest of the screen says nothing is growing.
      expect(ambience.playing, AmbientSound.silence);

      await tester.tap(find.text('Skip break'));
      await settle(tester);
      await tester.tap(find.text('Plant it'));
      await settle(tester);

      expect(ambience.playing, AmbientSound.forest);
    });

    testWidgets('a session backgrounded mid-flight keeps playing',
        (tester) async {
      final clock = FixedClock(testInstant);
      final ambience = FakeAmbience();
      await pumpApp(
        tester,
        clock: clock,
        ambience: ambience,
        settings: GardenSettings.defaults.withAmbientSound(AmbientSound.rain),
      );

      await startSession(tester);
      await sendToBackground(tester);
      await advance(tester, clock, const Duration(minutes: 5));

      // Nothing in the app stops the bed on backgrounding. The platform side is
      // in `test/platform/background_audio_test.dart`.
      expect(ambience.playing, AmbientSound.rain);
      expect(ambience.stops, 0);

      await bringToForeground(tester);
      expect(ambience.playing, AmbientSound.rain);
    });

    testWidgets('a force quit takes the bed with the session', (tester) async {
      final ambience = FakeAmbience();
      await pumpApp(
        tester,
        ambience: ambience,
        settings: GardenSettings.defaults.withAmbientSound(AmbientSound.cafe),
      );

      await startSession(tester);
      expect(ambience.playing, AmbientSound.cafe);

      await forceQuitApp(tester);

      // `SessionLifecycle` voids the session; the bed has to go too.
      expect(ambience.playing, AmbientSound.silence);
    });
  });

  group('the choice persists', () {
    testWidgets('a bed picked mid-session is what the next session starts on',
        (tester) async {
      final clock = FixedClock(testInstant);
      final ambience = FakeAmbience();
      await pumpApp(tester, clock: clock, ambience: ambience);

      await tapTab(tester, AppTab.timer);
      await startSession(tester);
      await pick(tester, AmbientSound.ocean);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      await tester.tap(find.text('Plant another'));
      await settle(tester);

      expect(ambience.playing, AmbientSound.ocean);
    });

    testWidgets('and survives a relaunch', (tester) async {
      // Read back through the same load a real launch does.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await pumpApp(tester, database: database);
      await tapTab(tester, AppTab.timer);
      await pick(tester, AmbientSound.whiteNoise);

      await killApp(tester);

      final ambience = FakeAmbience();
      await pumpApp(tester, database: database, ambience: ambience);
      await tapTab(tester, AppTab.timer);
      await startSession(tester);
      await settle(tester);

      expect(ambience.playing, AmbientSound.whiteNoise);
    });
  });

  group('all six', () {
    testWidgets('are offered, unmarked, and every one of them plays',
        (tester) async {
      final ambience = FakeAmbience();
      await pumpApp(tester, ambience: ambience);
      await tapTab(tester, AppTab.timer);

      // The app is free, so no premium marks on any of them
      // (ADR 0005).
      expect(find.textContaining('premium'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      for (final sound in AmbientSound.values) {
        expect(find.byKey(AmbienceKeys.chip(sound)), findsOneWidget,
            reason: '${sound.label} is not offered');
      }

      await pick(tester, AmbientSound.cafe);
      await startSession(tester);
      await settle(tester);

      expect(ambience.playing, AmbientSound.cafe);
    });
  });
}
