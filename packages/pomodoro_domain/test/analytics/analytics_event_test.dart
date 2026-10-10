import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

/// PRD §7.1's table, as types: what each event is called and what it carries.
///
/// The parameters are asserted by name because they are the *contract* — the
/// column a future sink reads and the line the debug screen shows — and a rename
/// that nothing catches is a rename that silently splits a user's log in two.
void main() {
  group('event names', () {
    test('every event is named as §7.1 names it', () {
      expect(
        AnalyticsEventName.values.map((name) => name.recorded),
        containsAll(<String>[
          'session_started',
          'session_completed',
          'session_abandoned',
          'session_paused',
          'plant_grown',
          'garden_viewed',
          'ambient_sound_toggled',
          'settings_changed',
          'app_opened',
          'onboarding_completed',
          'garden_exported',
        ]),
      );
    });

    test('a name reads back, and an unknown one is null rather than a throw',
        () {
      expect(
        AnalyticsEventName.named('session_started'),
        AnalyticsEventName.sessionStarted,
      );
      // A row written by a later build than this one. An older app has to be
      // able to open its own log without knowing what it is looking at — which
      // is the case §7.1's table will keep producing every time it grows.
      expect(AnalyticsEventName.named('garden_composted'), isNull);
    });
  });

  group('the session events', () {
    test('a preset length is not custom, and a length between two is', () {
      expect(SessionStarted.of(SessionPreset.classic.length).isCustom, isFalse);
      expect(SessionStarted.of(const Duration(minutes: 37)).isCustom, isTrue);
    });

    test('session_started carries its length in seconds', () {
      expect(
        SessionStarted.of(const Duration(minutes: 25)).parameters,
        {'duration_seconds': 1500, 'is_custom': false},
      );
    });

    test('session_completed carries how many times it was held', () {
      const event = SessionCompleted(
        duration: Duration(minutes: 25),
        pausedCount: 2,
      );

      expect(event.name, AnalyticsEventName.sessionCompleted);
      expect(event.parameters, {'duration_seconds': 1500, 'paused_count': 2});
    });

    test('session_abandoned carries how far the user got', () {
      const event = SessionAbandoned(
        duration: Duration(minutes: 25),
        elapsedBeforeAbandon: Duration(minutes: 4),
      );

      expect(event.parameters, {
        'duration_seconds': 1500,
        'elapsed_before_abandon_seconds': 240,
      });
    });

    test('session_paused carries which pause this is', () {
      const event = SessionPaused(
        duration: Duration(minutes: 25),
        pauseCount: 1,
      );

      expect(event.parameters, {'duration_seconds': 1500, 'pause_count': 1});
    });
  });

  test('plant_grown carries the species and the stage it reached', () {
    const event = PlantGrown(
      species: PlantSpecies.basil,
      stageReached: GrowthStage.mature,
    );

    expect(event.parameters, {'species': 'basil', 'stage_reached': 'mature'});
  });

  test('garden_viewed carries how long and how far in', () {
    const event = GardenViewed(
      timeSpent: Duration(seconds: 42),
      zoomLevel: 1.5,
    );

    expect(event.parameters, {'time_spent_seconds': 42, 'zoom_level': 1.5});
  });

  group('ambient_sound_toggled', () {
    test('a bed is enabled', () {
      const event = AmbientSoundToggled(sound: AmbientSound.rain);

      expect(event.enabled, isTrue);
      expect(event.parameters, {'sound_type': 'rain', 'enabled': true});
    });

    test('silence is a choice, and it is the one that is not enabled', () {
      // REQ-012 has no off switch: a user who wants nothing has chosen
      // something, and this is the only event where that distinction shows.
      const event = AmbientSoundToggled(sound: AmbientSound.silence);

      expect(event.enabled, isFalse);
      expect(event.parameters['enabled'], isFalse);
    });
  });

  group('settings_changed', () {
    test('nothing changed is no events', () {
      expect(
        AnalyticsEvent.forSettingsChange(
          before: GardenSettings.defaults,
          after: GardenSettings.defaults,
        ),
        isEmpty,
      );
    });

    test('one slider moved is one event, with both values', () {
      final events = AnalyticsEvent.forSettingsChange(
        before: GardenSettings.defaults,
        after: GardenSettings.defaults
            .withSessionLength(const Duration(minutes: 50)),
      );

      expect(events, hasLength(1));
      expect(events.single.parameters, {
        'setting_key': 'session_length',
        'old_value': '1500',
        'new_value': '3000',
      });
    });

    test('a switch says on and off rather than true and false', () {
      final events = AnalyticsEvent.forSettingsChange(
        before: GardenSettings.defaults,
        after: GardenSettings.defaults.withHaptics(enabled: false),
      );

      expect(events.single.parameters, {
        'setting_key': 'haptics',
        'old_value': 'on',
        'new_value': 'off',
      });
    });

    test('two settings moved at once are two events', () {
      final events = AnalyticsEvent.forSettingsChange(
        before: GardenSettings.defaults,
        after: GardenSettings.defaults
            .withBreakLength(const Duration(minutes: 10))
            .withLongBreakAfter(6),
      );

      expect(
        events.map((event) => event.parameters['setting_key']),
        ['break_length', 'long_break_after'],
      );
    });

    test('a bed is both a setting changed and a sound toggled', () {
      // §7.1 asks for both, and they answer different questions: what people
      // customise, and which sounds are popular.
      final events = AnalyticsEvent.forSettingsChange(
        before: GardenSettings.defaults,
        after: GardenSettings.defaults.withAmbientSound(AmbientSound.forest),
      );

      expect(events.map((event) => event.name), [
        AnalyticsEventName.settingsChanged,
        AnalyticsEventName.ambientSoundToggled,
      ]);
      expect(events.first.parameters, {
        'setting_key': 'ambient_sound',
        'old_value': 'silence',
        'new_value': 'forest',
      });
    });

    test('a garden theme is a setting like the others', () {
      // PRD v2.2 §7.1: every user-chosen setting is covered, the theme
      // included. It was the one the picker changed without a trace.
      final events = AnalyticsEvent.forSettingsChange(
        before: GardenSettings.defaults,
        after: GardenSettings.defaults.withGardenTheme(GardenTheme.tropical),
      );

      expect(events.single.parameters, {
        'setting_key': 'garden_theme',
        'old_value': 'zen',
        'new_value': 'tropical',
      });
    });

    test('the flags that are not preferences are not settings changes', () {
      // Onboarding has an event of its own, and a dismissed hint is not
      // something the user chose between — both live in `GardenSettings`
      // because it is the app's single-row store, not because they are
      // settings.
      expect(
        AnalyticsEvent.forSettingsChange(
          before: GardenSettings.defaults,
          after: GardenSettings.defaults
              .withOnboardingCompleted()
              .withQuietModeHintDismissed(),
        ),
        isEmpty,
      );
    });
  });

  test('app_opened carries nothing for a first open', () {
    const event = AppOpened(daysSinceLastOpen: null, streakDays: 0);

    expect(event.parameters, {'days_since_last_open': null, 'streak_days': 0});
  });

  test('onboarding_completed has no time to a session nobody started', () {
    const skipped = OnboardingCompleted(
      stepsCompleted: 1,
      timeToFirstSession: null,
    );

    expect(skipped.parameters, {
      'steps_completed': 1,
      'time_to_first_session_seconds': null,
    });
  });

  group('garden_exported', () {
    test('is the whole event — there is one kind of export', () {
      const event = GardenExported();

      expect(event.name, AnalyticsEventName.gardenExported);
      expect(event.parameters, isEmpty);
    });
  });

  test('there is no event for a paywall or a purchase', () {
    // The app is free: §7.1's `paywall_viewed` and `premium_purchased` were
    // removed with the screen and the store that emitted them, on the rule this
    // enum is kept by — a name lands with its call site and leaves with it. See
    // `docs/adr/0021-…`.
    expect(
      AnalyticsEventName.values.map((name) => name.recorded),
      isNot(anyElement(anyOf('paywall_viewed', 'premium_purchased'))),
    );
    expect(AnalyticsEventName.named('paywall_viewed'), isNull);
    expect(AnalyticsEventName.named('premium_purchased'), isNull);
  });

  test('NoAnalytics takes an event and does nothing with it', () {
    // The port's other implementation, and the proof that a call site cannot
    // tell what is behind it.
    expect(
      () => const NoAnalytics().record(const AppOpened(
        daysSinceLastOpen: 1,
        streakDays: 3,
      )),
      returnsNormally,
    );
  });
}
