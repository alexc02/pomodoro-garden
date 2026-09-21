import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_settings_repository.dart';
import 'package:pip_garden/src/features/settings/end_sound_picker.dart';
import 'package:pip_garden/src/features/settings/reset_garden.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/features/timer/ambience_picker.dart';
import 'package:pip_garden/src/features/timer/timer_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/announcement_fakes.dart';
import '../../support/app_harness.dart';
import '../../support/event_log.dart';

// Choosing the end-of-session sound. Notification content is checked in
// test/notifications/completion_details_test.dart, the files in
// test/feedback/end_sounds_test.dart.
void main() {
  Future<void> openSettings(WidgetTester tester) =>
      tapTab(tester, AppTab.settings);

  Future<void> pick(WidgetTester tester, EndSound sound) async {
    final chip = await scrollToSetting(tester, EndSoundKeys.chip(sound));
    await tester.tap(chip);
    await settle(tester);
  }

  group('the control', () {
    testWidgets('offers all six choices', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await scrollToSetting(tester, EndSoundKeys.chip(EndSound.windChime));

      for (final sound in EndSound.values) {
        expect(find.byKey(EndSoundKeys.chip(sound)), findsOneWidget,
            reason: '${sound.label} missing');
      }
    });

    testWidgets('defaults to the wind chime', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      final chip = await scrollToSetting(
        tester,
        EndSoundKeys.chip(EndSound.windChime),
      );

      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
    });

    testWidgets('shows the stored sound', (tester) async {
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

    testWidgets('is in settings, not on the timer', (tester) async {
      // Unlike the ambient bed, there's no point choosing this on the timer.
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

      // IndexedStack keeps both tabs built, so search offstage too. The ambient
      // picker is checked alongside so a broken finder would fail.
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

  group('preview', () {
    testWidgets('picking a sound plays it', (tester) async {
      final sound = FakeEndSoundPlayer();
      await pumpApp(tester, endSound: sound);
      await openSettings(tester);

      await pick(tester, EndSound.singingBowl);

      expect(sound.played, [EndSound.singingBowl]);
    });

    testWidgets('re-tapping the current sound plays it again', (tester) async {
      // Re-tapping to compare must not be a dead control.
      final sound = FakeEndSoundPlayer();
      await pumpApp(tester, endSound: sound);
      await openSettings(tester);

      await pick(tester, EndSound.softBell);
      await pick(tester, EndSound.softBell);

      expect(sound.played, [EndSound.softBell, EndSound.softBell]);
    });

    testWidgets('picking None previews silence', (tester) async {
      // The player is still asked; it knows none isn't a file.
      final sound = FakeEndSoundPlayer();
      await pumpApp(tester, endSound: sound);
      await openSettings(tester);

      await pick(tester, EndSound.none);

      expect(sound.played, [EndSound.none]);
    });
  });

  group('persistence', () {
    late Directory directory;
    late File file;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('pip_garden_test');
      file = File('${directory.path}/pip_garden.sqlite');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    testWidgets('saved on pick', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(tester, database: database);
      await openSettings(tester);

      await pick(tester, EndSound.oceanWave);

      expect((await DriftSettingsRepository(database).load()).endSound,
          EndSound.oceanWave);
    });

    testWidgets('survives a relaunch', (tester) async {
      // Real file, closed between launches. In-memory would only prove the same
      // process can re-read it.
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

    testWidgets('survives a garden reset', (tester) async {
      // A reset clears the garden, not settings.
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

  group('on session end', () {
    testWidgets('plays the chosen sound in the foreground', (tester) async {
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

    testWidgets('plays nothing for None', (tester) async {
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
      // The rest of the completion is unchanged.
      expect(find.text('Session complete'), findsOneWidget);
      expect(haptics.completions, 1);
    });

    testWidgets('break end plays the chosen sound', (tester) async {
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

    testWidgets('background session puts it on the notification',
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

    testWidgets('None still posts the notification', (tester) async {
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

    testWidgets('sound picked mid-session is used at the end', (tester) async {
      // Not frozen at session start, unlike the session length.
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

      // Preview, then completion.
      expect(sound.played, [EndSound.singingBowl, EndSound.singingBowl]);
    });
  });

  group('analytics', () {
    testWidgets('logs settings_changed with its own key', (tester) async {
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
