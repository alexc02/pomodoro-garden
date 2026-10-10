import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/features/timer/ambience_picker.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../support/ambience_fake.dart';
import '../support/announcement_fakes.dart';
import '../support/app_harness.dart';

/// Ticket 10: what is playing under a focus session, and when it is not.
///
/// The rule the whole file is written against: **the bed belongs to a focus
/// session, running or held, and to nothing else.** Idle has no bed, a break has
/// no bed, and a session that ends by any route takes its bed with it.
///
/// What is *not* here, because no widget test can reach it: whether the loop
/// has an audible seam, whether the phone goes on playing behind a locked
/// screen, and whether a call really does hand the audio back afterwards. The
/// first is asserted against the files themselves in `audio_budget_test.dart`;
/// the second is a platform configuration recorded in
/// `test/platform/background_audio_test.dart`; the third has its decisions in
/// `audio_interruptions_test.dart` and its delivery on a device. See the
/// ticket's verification gaps.
void main() {
  /// Picks [sound] from the timer screen, as a user would.
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
            reason: 'REQ-012 offers ${sound.label}');
      }
    });

    testWidgets('nothing plays until a session is running', (tester) async {
      final ambience = FakeAmbience();
      await pumpApp(tester, ambience: ambience);
      await tapTab(tester, AppTab.timer);

      await pick(tester, AmbientSound.rain);

      // The bed belongs to a session. Picking one on an idle timer is choosing
      // what the *next* session sounds like, and a picker that started playing
      // there and then would be an app making rain at somebody reading their
      // settings.
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

      // The whole of "changeable mid-session without a gap": the café is asked
      // for directly, over the rain. A keeper that stopped and then started
      // would show up here as a silence between the two.
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

      // Changing the bed is not restarting the session, and the countdown that
      // was eleven minutes in is twenty-five minutes in.
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

      // A pause is the user stepping away from the desk, not out of the hour.
      // A bed that stopped and started around it would put in the gap the
      // ticket exists to forbid.
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
      // The chime and the bed leaving are the same moment on purpose:
      // `Ambience.stop` fades, so REQ-008's wind chime is heard over a bed on
      // its way out rather than over one at full level.
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

      // A break is a rest, and the rest of this screen says so — a sky ring,
      // bare soil, and a line about nothing growing. A bed carrying on through
      // it would say the opposite.
      expect(ambience.playing, AmbientSound.silence);

      await tester.tap(find.text('Skip break'));
      await settle(tester);
      await tester.tap(find.text('Start'));
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

      // The half of "keeps playing behind a locked screen" that is about this
      // app: nothing here takes the bed down when the app goes away. The other
      // half is the iOS background mode and the audio category, which are
      // asserted in `test/platform/background_audio_test.dart`.
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

      // The session is voided by `SessionLifecycle`; a bed still playing would
      // be a café for a session that no longer exists.
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

      await tester.tap(find.text('Start'));
      await settle(tester);

      expect(ambience.playing, AmbientSound.ocean);
    });

    testWidgets('and survives a relaunch', (tester) async {
      // Written to the database rather than held in memory: the setting is
      // read back through the same load a real launch does.
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

      // An earlier draft marked three of them premium and said so in a line
      // under the chips. The app is free: there is no mark and no line, and
      // this is the test that would fail if either came back. See
      // `docs/adr/0021-…`.
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
