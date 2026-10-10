import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_settings_repository.dart';
import 'package:pomodoro_garden/src/features/settings/end_sound_picker.dart';
import 'package:pomodoro_garden/src/features/settings/reset_garden.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/features/timer/ambience_picker.dart';
import 'package:pomodoro_garden/src/features/timer/timer_screen.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../../support/announcement_fakes.dart';
import '../../support/app_harness.dart';
import '../../support/event_log.dart';

/// Ticket 25: choosing the end-of-session sound.
///
/// US-028's story is one sentence — *I want to choose my end-of-session sound,
/// so it matches my preference* — and everything here is a reading of it. The
/// choice has to exist, it has to be hearable while you are choosing, it has to
/// be what actually plays afterwards, and it has to still be there tomorrow.
///
/// What is on the notification is checked in
/// `test/notifications/completion_details_test.dart`, and the files themselves
/// in `test/feedback/end_sounds_test.dart`.
void main() {
  Future<void> openSettings(WidgetTester tester) =>
      tapTab(tester, AppTab.settings);

  /// Picks [sound] in settings, as a user would.
  Future<void> pick(WidgetTester tester, EndSound sound) async {
    final chip = await scrollToSetting(tester, EndSoundKeys.chip(sound));
    await tester.tap(chip);
    await settle(tester);
  }

  group('the control', () {
    testWidgets('offers all six of REQ-031\'s choices', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await scrollToSetting(tester, EndSoundKeys.chip(EndSound.windChime));

      for (final sound in EndSound.values) {
        expect(find.byKey(EndSoundKeys.chip(sound)), findsOneWidget,
            reason: '${sound.label} is not on the screen');
      }
    });

    testWidgets('opens on the wind chime, which is what the app has always '
        'made', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      final chip = await scrollToSetting(
        tester,
        EndSoundKeys.chip(EndSound.windChime),
      );

      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
    });

    testWidgets('and shows the sound already stored', (tester) async {
      await pumpApp(
        tester,
        settings: GardenSettings.defaults.withEndSound(EndSound.birdsong),
      );
      await openSettings(tester);

      final chosen = await scrollToSetting(
        tester,
        EndSoundKeys.chip(EndSound.birdsong),
      );
      expect(tester.widget<ChoiceChip>(chosen).selected, isTrue);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(EndSoundKeys.chip(EndSound.windChime)),
            )
            .selected,
        isFalse,
      );
    });

    testWidgets('it is in settings and nowhere near the timer', (tester) async {
      // Unlike the bed. The moment an end sound matters is the moment a session
      // finishes, which is too late to choose — so a chip on the timer screen
      // would be taking up room beside the countdown for nothing.
      await pumpApp(tester);
      await openSettings(tester);
      await scrollToSetting(tester, EndSoundKeys.chip(EndSound.windChime));

      expect(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(EndSoundPicker),
        ),
        findsOneWidget,
      );

      // Both tabs are alive at once — the shell keeps them in an `IndexedStack`
      // — so the timer is *built* while settings is on screen, merely offstage.
      // Asked without skipping it, this is a question about where the control
      // lives rather than about which tab happens to be selected. The bed's
      // picker is asked for in the same breath, so a finder that could never
      // find anything would fail here.
      final timer = find.byType(TimerScreen, skipOffstage: false);
      expect(
        find.descendant(
          of: timer,
          matching: find.byType(EndSoundPicker, skipOffstage: false),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: timer,
          matching: find.byType(AmbiencePicker, skipOffstage: false),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });
  });

  group('picking one plays it', () {
    testWidgets('because a list of names nobody can hear is a list of names',
        (tester) async {
      final sound = FakeEndSoundPlayer();
      await pumpApp(tester, endSound: sound);
      await openSettings(tester);

      await pick(tester, EndSound.singingBowl);

      expect(sound.played, [EndSound.singingBowl]);
    });

    testWidgets('and tapping the one already chosen plays it again',
        (tester) async {
      // Which is what somebody comparing two of them will do. A tap that did
      // nothing would be the one dead control on the screen.
      final sound = FakeEndSoundPlayer();
      await pumpApp(tester, endSound: sound);
      await openSettings(tester);

      await pick(tester, EndSound.softBell);
      await pick(tester, EndSound.softBell);

      expect(sound.played, [EndSound.softBell, EndSound.softBell]);
    });

    testWidgets('picking None previews the silence it promises',
        (tester) async {
      // The player is asked, like it is for the other five, and it is the
      // player that knows `none` is not a file. Asking is what keeps the
      // announcer and the picker from each having their own opinion about it.
      final sound = FakeEndSoundPlayer();
      await pumpApp(tester, endSound: sound);
      await openSettings(tester);

      await pick(tester, EndSound.none);

      expect(sound.played, [EndSound.none]);
    });
  });

  group('the choice is stored', () {
    late Directory directory;
    late File file;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('pomodoro_garden_test');
      file = File('${directory.path}/pomodoro_garden.sqlite');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    testWidgets('on the settings row, the moment it is picked', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(tester, database: database);
      await openSettings(tester);

      await pick(tester, EndSound.oceanWave);

      expect((await DriftSettingsRepository(database).load()).endSound,
          EndSound.oceanWave);
    });

    testWidgets('and survives a kill and a relaunch', (tester) async {
      // A real file, closed between the two launches: an in-memory database
      // would prove only that the app can re-read its own process.
      final firstLaunch = AppDatabase.inFile(file);
      await pumpApp(tester, database: firstLaunch);
      await openSettings(tester);
      await pick(tester, EndSound.birdsong);

      await killApp(tester);
      await firstLaunch.close();

      final secondLaunch = AppDatabase.inFile(file);
      addTearDown(secondLaunch.close);
      await pumpApp(tester, database: secondLaunch);
      await openSettings(tester);

      final chip = await scrollToSetting(
        tester,
        EndSoundKeys.chip(EndSound.birdsong),
      );
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
      expect((await DriftSettingsRepository(secondLaunch).load()).endSound,
          EndSound.birdsong);
    });

    testWidgets('and survives a reset, which clears a garden and not a '
        'preference', (tester) async {
      // ADR 0019: what a reset forgets is the garden. The settings are the
      // other half of that sentence, and this sound is one of them.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(
        tester,
        database: database,
        settings: GardenSettings.defaults.withEndSound(EndSound.singingBowl),
      );
      await openSettings(tester);

      await tester.tap(await scrollToSetting(tester, ResetGardenKeys.control));
      await settle(tester);
      await tester.tap(find.descendant(
        of: find.byKey(ResetGardenKeys.firstConfirmation),
        matching: find.text('Continue'),
      ));
      await settle(tester);
      await tester.tap(find.descendant(
        of: find.byKey(ResetGardenKeys.secondConfirmation),
        matching: find.text('Reset my garden'),
      ));
      await settle(tester);

      expect((await DriftSettingsRepository(database).load()).endSound,
          EndSound.singingBowl);
    });
  });

  group('what actually plays when a session ends', () {
    testWidgets('is the sound the user chose, in front of them',
        (tester) async {
      final clock = FixedClock(testInstant);
      final sound = FakeEndSoundPlayer();
      await pumpApp(
        tester,
        clock: clock,
        endSound: sound,
        settings: GardenSettings.defaults.withEndSound(EndSound.oceanWave),
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      expect(sound.played, [EndSound.oceanWave]);
    });

    testWidgets('and it is None that plays when None is what they chose',
        (tester) async {
      final clock = FixedClock(testInstant);
      final sound = FakeEndSoundPlayer();
      final haptics = FakeHaptics();
      await pumpApp(
        tester,
        clock: clock,
        endSound: sound,
        haptics: haptics,
        settings: GardenSettings.defaults.withEndSound(EndSound.none),
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      expect(sound.played, [EndSound.none]);
      // The rest of the completion is untouched: **None** is a sound the user
      // turned off, not the announcement.
      expect(find.text('Session complete'), findsOneWidget);
      expect(haptics.completions, 1);
    });

    testWidgets('a break that runs out makes the same chosen sound',
        (tester) async {
      final clock = FixedClock(testInstant);
      final sound = FakeEndSoundPlayer();
      await pumpApp(
        tester,
        clock: clock,
        endSound: sound,
        settings: GardenSettings.defaults
            .withEndSound(EndSound.softBell)
            .withAutoStartBreak(enabled: true),
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await settle(tester);

      expect(sound.played, [EndSound.softBell, EndSound.softBell]);
    });

    testWidgets('and a session the app is away for carries it on the notice',
        (tester) async {
      final clock = FixedClock(testInstant);
      final notifications = FakeSessionNotifications();
      await pumpApp(
        tester,
        clock: clock,
        notifications: notifications,
        settings: GardenSettings.defaults.withEndSound(EndSound.birdsong),
      );

      await startSession(tester);
      await sendToBackground(tester);

      expect(notifications.pending, isNotNull);
      expect(notifications.pending!.sound, EndSound.birdsong);
    });

    testWidgets('None still leaves a notice behind — the announcement is the '
        'news, not the noise', (tester) async {
      final clock = FixedClock(testInstant);
      final notifications = FakeSessionNotifications();
      await pumpApp(
        tester,
        clock: clock,
        notifications: notifications,
        settings: GardenSettings.defaults.withEndSound(EndSound.none),
      );

      await startSession(tester);
      await sendToBackground(tester);

      expect(notifications.pending, isNotNull,
          reason: 'turning the sound off must not turn the notice off');
      expect(notifications.pending!.sound, EndSound.none);
      expect(notifications.pending!.title, isNotEmpty);
    });

    testWidgets('a sound picked mid-session is what that session ends with',
        (tester) async {
      // Unlike the session length, and like the bed: nothing freezes this when
      // a session starts, because what it decides has not happened yet.
      final clock = FixedClock(testInstant);
      final sound = FakeEndSoundPlayer();
      await pumpApp(tester, clock: clock, endSound: sound);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 5));
      await openSettings(tester);
      await pick(tester, EndSound.singingBowl);
      await tapTab(tester, AppTab.timer);

      await advance(tester, clock, const Duration(minutes: 20));
      await settle(tester);

      // The preview, then the completion — both the newly chosen sound.
      expect(sound.played, [EndSound.singingBowl, EndSound.singingBowl]);
    });
  });

  group('§7.1 records it', () {
    testWidgets('as a settings_changed with a key of its own', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(tester, database: database);
      await openSettings(tester);

      await pick(tester, EndSound.oceanWave);

      final event =
          await theEventNamed(database, AnalyticsEventName.settingsChanged);

      expect(event.parameters, {
        'setting_key': 'end_sound',
        'old_value': 'windChime',
        'new_value': 'oceanWave',
      });
    });
  });
}
