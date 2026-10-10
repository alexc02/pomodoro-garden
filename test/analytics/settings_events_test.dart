import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/features/garden/theme_picker.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/features/timer/ambience_picker.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/event_log.dart';

/// PRD §7.1's `settings_changed` and `ambient_sound_toggled`, driven through the
/// controls a user actually touches.
///
/// `AnalyticsEvent.forSettingsChange` is unit-tested in the domain package,
/// where every key and both values are pinned. What is left to show — and what
/// only the real app can show — is that the *controls are wired to it*: that a
/// tap on a preset, a switch or a chip goes through the one writer that compares
/// two settings, and that no screen has to remember to announce itself.
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  Future<void> launch(WidgetTester tester, {GardenSettings? settings}) =>
      pumpApp(tester, database: database, settings: settings);

  Future<void> openSettings(WidgetTester tester) =>
      tapTab(tester, AppTab.settings);

  /// Picks [sound] from the timer screen, as a user would.
  Future<void> pickBed(WidgetTester tester, AmbientSound sound) async {
    await tapTab(tester, AppTab.timer);
    final chip = find.byKey(AmbienceKeys.chip(sound));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await settle(tester);
  }

  Future<List<LoggedEvent>> changes(AnalyticsEventName name) =>
      eventsNamed(database, name);

  testWidgets('a preset records the length that was and the length that is',
      (tester) async {
    await launch(tester);
    await openSettings(tester);

    await tester.tap(find.text('Deep · 50'));
    await settle(tester);

    final event = await theEventNamed(
      database,
      AnalyticsEventName.settingsChanged,
    );

    expect(event.parameters, {
      'setting_key': 'session_length',
      // Seconds, as §7.1's other durations are, and as strings because one
      // event carries lengths, counts, switches and the name of a bed.
      'old_value': '1500',
      'new_value': '3000',
    });
  });

  testWidgets('picking a garden theme records the theme that was and is',
      (tester) async {
    await launch(tester);
    await openSettings(tester);

    await tester.tap(await scrollToSetting(tester, SettingsKeys.gardenTheme));
    await settle(tester);
    final card = find.byKey(ThemePickerKeys.card(GardenTheme.tropical));
    await tester.ensureVisible(card);
    await settle(tester);
    await tester.tap(card);
    await settle(tester);

    final event = await theEventNamed(
      database,
      AnalyticsEventName.settingsChanged,
    );

    expect(event.parameters, {
      'setting_key': 'garden_theme',
      'old_value': 'zen',
      'new_value': 'tropical',
    });
  });

  testWidgets('a switch is recorded as on and off rather than true and false',
      (tester) async {
    await launch(tester);
    await openSettings(tester);

    await tester.tap(await scrollToSetting(tester, SettingsKeys.haptics));
    await settle(tester);

    final event = await theEventNamed(
      database,
      AnalyticsEventName.settingsChanged,
    );

    expect(event.parameters, {
      'setting_key': 'haptics',
      'old_value': 'on',
      'new_value': 'off',
    });
  });

  testWidgets('a setting set to what it already was records nothing',
      (tester) async {
    // REQ-006's Classic is the default, so this preset is a tap that changes
    // nothing — and a log that recorded it would be a log claiming the user
    // customises their session length every time they look at the screen.
    await launch(tester);
    await openSettings(tester);

    await tester.tap(find.text('Classic · 25'));
    await settle(tester);

    expect(await changes(AnalyticsEventName.settingsChanged), isEmpty);
  });

  testWidgets('two settings moved are two events, one per key', (tester) async {
    await launch(tester);
    await openSettings(tester);

    await tester.tap(find.text('Deep · 50'));
    await settle(tester);
    await tester.tap(await scrollToSetting(tester, SettingsKeys.autoStartBreak));
    await settle(tester);

    expect(
      (await changes(AnalyticsEventName.settingsChanged))
          .map((event) => event.parameters['setting_key']),
      ['session_length', 'auto_start_break'],
    );
  });

  group('the ambience picker', () {
    testWidgets('records a bed as both a setting changed and a sound toggled',
        (tester) async {
      // The one setting §7.1 gives two events, because "what do people
      // customise" and "which sounds are popular" are different questions.
      await launch(tester);

      await pickBed(tester, AmbientSound.rain);

      expect(
        (await theEventNamed(database, AnalyticsEventName.settingsChanged))
            .parameters,
        {
          'setting_key': 'ambient_sound',
          'old_value': 'silence',
          'new_value': 'rain',
        },
      );
      expect(
        (await theEventNamed(database, AnalyticsEventName.ambientSoundToggled))
            .parameters,
        {'sound_type': 'rain', 'enabled': true},
      );
    });

    testWidgets('records silence as the choice that is not enabled',
        (tester) async {
      await launch(
        tester,
        settings: GardenSettings.defaults
            .withAmbientSound(AmbientSound.forest),
      );

      await pickBed(tester, AmbientSound.silence);

      expect(
        (await theEventNamed(database, AnalyticsEventName.ambientSoundToggled))
            .parameters,
        {'sound_type': 'silence', 'enabled': false},
      );
    });

    testWidgets('picking the bed that is already playing records nothing',
        (tester) async {
      await launch(
        tester,
        settings: GardenSettings.defaults.withAmbientSound(AmbientSound.rain),
      );

      await pickBed(tester, AmbientSound.rain);

      expect(await changes(AnalyticsEventName.ambientSoundToggled), isEmpty);
      expect(await changes(AnalyticsEventName.settingsChanged), isEmpty);
    });
  });
}
