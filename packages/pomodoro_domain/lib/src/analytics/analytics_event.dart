import '../garden/growth_stage.dart';
import '../garden/plant_type.dart';
import '../settings/ambient_sound.dart';
import '../settings/garden_settings.dart';
import '../settings/session_preset.dart';

/// The name PRD §7.1 gives an event, as a value rather than as a string at a
/// call site.
///
/// Nothing outside this file writes one of these names down. A call site builds
/// an [AnalyticsEvent] and the event knows what it is called, which is what
/// makes a typo in an event name a thing the compiler catches rather than a
/// thing that shows up as an empty column in six months.
///
/// Eleven of §7.1's thirteen are here. `paywall_viewed` and `premium_purchased`
/// are not, and there is nothing left in the app that could record them — the
/// paywall and the purchase are gone, see `docs/adr/0021-…`. That is the rule
/// this enum is kept by: a name lands with its call site, never ahead of one and
/// never after one, so nothing in here is a column that is always empty.
enum AnalyticsEventName {
  sessionStarted('session_started'),
  sessionCompleted('session_completed'),
  sessionAbandoned('session_abandoned'),
  sessionPaused('session_paused'),
  plantGrown('plant_grown'),
  gardenViewed('garden_viewed'),
  ambientSoundToggled('ambient_sound_toggled'),
  settingsChanged('settings_changed'),
  appOpened('app_opened'),
  onboardingCompleted('onboarding_completed'),
  gardenExported('garden_exported');

  const AnalyticsEventName(this.recorded);

  /// What §7.1 calls this event, and what the log stores.
  ///
  /// Written out rather than derived from [name], because the enum's own
  /// spelling is Dart's convention and this one is the PRD's: a rename here
  /// would otherwise quietly split a user's log into two events.
  final String recorded;

  /// The name for [recorded], or null if this build has never heard of it.
  ///
  /// Null rather than a throw, for the reason `SessionOutcome` is read back the
  /// same way: a row written by a later version must not stop an older build
  /// from opening its own log.
  static AnalyticsEventName? named(String recorded) {
    for (final name in values) {
      if (name.recorded == recorded) return name;
    }
    return null;
  }
}

/// Which setting a [SettingsChanged] is about.
///
/// The switches and sliders a user actually chooses between, and only those:
/// `quietModeHintDismissed` and `onboardingCompleted` live in the same stored
/// value and are not preferences — one is a hint the user put away and the
/// other is whether they have met the app, which has an event of its own.
enum SettingKey {
  sessionLength('session_length'),
  breakLength('break_length'),
  longBreakAfter('long_break_after'),
  haptics('haptics'),
  liveSurface('live_surface'),
  autoStartBreak('auto_start_break'),
  autoStartNextSession('auto_start_next_session'),
  ambientSound('ambient_sound'),
  endSound('end_sound'),
  quietMode('quiet_mode'),
  gardenTheme('garden_theme');

  const SettingKey(this.recorded);

  /// What §7.1's `setting_key` parameter carries for this setting.
  final String recorded;
}

/// One thing worth knowing about how the app is used: PRD §7.1's table, as
/// types.
///
/// **Sealed, and every event carries its own parameters as fields.** That is the
/// whole point of this file: a call site says
/// `SessionStarted(duration: …, isCustom: …)` and cannot misspell a parameter,
/// omit one, or put a species where a stage goes. [parameters] exists for the
/// log to store and the debug screen to show — it is the *edge* where the types
/// are flattened, and nothing in the app builds one by hand.
///
/// **Durations are said in seconds**, so `duration` arrives as
/// `duration_seconds`. The same reasoning as
/// `docs/adr/0003-durations-are-stored-in-seconds.md`: a number in a log with no
/// unit on it is a number somebody will read as minutes.
///
/// Nothing here leaves the device — see PRD §7.2 and [Analytics].
sealed class AnalyticsEvent {
  const AnalyticsEvent();

  /// Every event worth recording about the move from [before] to [after].
  ///
  /// Settings are written as a whole [GardenSettings] — one accessor, one
  /// writer — so the app finds out *which* setting a user changed by comparing
  /// two of them rather than by asking every control to announce itself. That
  /// is what keeps the settings screen, the ambience picker on the timer and
  /// onboarding's length step all instrumented without any of them knowing this
  /// file exists.
  ///
  /// The bed shows up twice on purpose: it is a setting like the others *and*
  /// §7.1 gives it an event of its own, because "which sounds are popular" is a
  /// different question from "what do people customise".
  static List<AnalyticsEvent> forSettingsChange({
    required GardenSettings before,
    required GardenSettings after,
  }) {
    final events = <AnalyticsEvent>[];

    void changed<T extends Object>(
      SettingKey key,
      T Function(GardenSettings) read,
      String Function(T) show,
    ) {
      final was = read(before);
      final now = read(after);
      if (was == now) return;
      events.add(SettingsChanged(
        setting: key,
        oldValue: show(was),
        newValue: show(now),
      ));
    }

    changed(SettingKey.sessionLength, (s) => s.sessionLength, _seconds);
    changed(SettingKey.breakLength, (s) => s.breakLength, _seconds);
    changed(SettingKey.longBreakAfter, (s) => s.longBreakAfter, _number);
    changed(SettingKey.haptics, (s) => s.hapticsEnabled, _switched);
    changed(SettingKey.liveSurface, (s) => s.liveSurfaceEnabled, _switched);
    changed(SettingKey.autoStartBreak, (s) => s.autoStartBreak, _switched);
    changed(
      SettingKey.autoStartNextSession,
      (s) => s.autoStartNextSession,
      _switched,
    );
    changed(SettingKey.ambientSound, (s) => s.ambientSound, _named);
    changed(SettingKey.endSound, (s) => s.endSound, _named);
    changed(SettingKey.quietMode, (s) => s.quietModeEnabled, _switched);
    changed(SettingKey.gardenTheme, (s) => s.gardenTheme, _named);

    if (before.ambientSound != after.ambientSound) {
      events.add(AmbientSoundToggled(sound: after.ambientSound));
    }

    return events;
  }

  /// What this event is called, in §7.1's words.
  AnalyticsEventName get name;

  /// This event's parameters, flattened for storage.
  ///
  /// JSON-shaped values only — strings, numbers, booleans and nulls — because
  /// this is what gets written to the log and read back by a screen that has
  /// only the map to go on.
  Map<String, Object?> get parameters;

  @override
  String toString() => '${name.recorded}($parameters)';
}

/// A focus session began. §7.1: understand preferred session lengths.
final class SessionStarted extends AnalyticsEvent {
  const SessionStarted({required this.duration, required this.isCustom});

  /// The session [plannedDuration] runs for, said as this event.
  ///
  /// Here rather than at the call site because "is this length custom" is the
  /// same question as "does a preset name it", and the answer belongs beside
  /// the presets rather than in a timer.
  factory SessionStarted.of(Duration plannedDuration) => SessionStarted(
        duration: plannedDuration,
        isCustom: SessionPreset.matching(plannedDuration) == null,
      );

  /// The planned duration the session started with.
  final Duration duration;

  /// Whether that length is one no preset names — REQ-006's Short, Classic and
  /// Deep are the three that are not custom, and everything the slider can
  /// reach between them is.
  final bool isCustom;

  @override
  AnalyticsEventName get name => AnalyticsEventName.sessionStarted;

  @override
  Map<String, Object?> get parameters => {
        'duration_seconds': duration.inSeconds,
        'is_custom': isCustom,
      };
}

/// A focus session reached its planned duration. §7.1: completion rate by
/// session type.
final class SessionCompleted extends AnalyticsEvent {
  const SessionCompleted({required this.duration, required this.pausedCount});

  final Duration duration;

  /// How many times the session was held before it finished.
  ///
  /// Counted by whoever ran the session rather than stored on it, so a session
  /// the app was killed in the middle of comes back to a fresh count — see
  /// `SessionController`. The alternative was a column on `sessions` for a
  /// number nothing but this event reads.
  final int pausedCount;

  @override
  AnalyticsEventName get name => AnalyticsEventName.sessionCompleted;

  @override
  Map<String, Object?> get parameters => {
        'duration_seconds': duration.inSeconds,
        'paused_count': pausedCount,
      };
}

/// The user abandoned a focus session. §7.1: drop-off analysis.
///
/// Cancelled sessions only. A *voided* one — the app force-quit mid-session —
/// is not a drop-off: nobody decided anything, and counting it as one would put
/// a phone running out of battery in the same column as a user giving up.
final class SessionAbandoned extends AnalyticsEvent {
  const SessionAbandoned({
    required this.duration,
    required this.elapsedBeforeAbandon,
  });

  final Duration duration;

  /// How much of the session had actually been focused when the user let it go.
  final Duration elapsedBeforeAbandon;

  @override
  AnalyticsEventName get name => AnalyticsEventName.sessionAbandoned;

  @override
  Map<String, Object?> get parameters => {
        'duration_seconds': duration.inSeconds,
        'elapsed_before_abandon_seconds': elapsedBeforeAbandon.inSeconds,
      };
}

/// The user held a running session. §7.1: pause behaviour patterns.
final class SessionPaused extends AnalyticsEvent {
  const SessionPaused({required this.duration, required this.pauseCount});

  final Duration duration;

  /// Which pause of this session this is: 1 for the first.
  final int pauseCount;

  @override
  AnalyticsEventName get name => AnalyticsEventName.sessionPaused;

  @override
  Map<String, Object?> get parameters => {
        'duration_seconds': duration.inSeconds,
        'pause_count': pauseCount,
      };
}

/// A plant went into the garden. §7.1: garden engagement.
///
/// Both kinds: the plant a completed session earned, and REQ-021's bonus plant
/// an award put there. What they have in common is the one thing this event
/// records — something new is standing in the garden.
final class PlantGrown extends AnalyticsEvent {
  const PlantGrown({required this.species, required this.stageReached});

  final PlantSpecies species;

  /// How grown the plant is as it is written down. Mature for anything that
  /// reaches the garden, which is what makes the parameter worth having: a
  /// value that is ever anything else means the growth rules moved.
  final GrowthStage stageReached;

  @override
  AnalyticsEventName get name => AnalyticsEventName.plantGrown;

  @override
  Map<String, Object?> get parameters => {
        'species': species.name,
        'stage_reached': stageReached.name,
      };
}

/// The user spent a while looking at the garden. §7.1: garden engagement depth.
///
/// Recorded when they *leave* the tab, because that is the first moment there is
/// a length to record.
final class GardenViewed extends AnalyticsEvent {
  const GardenViewed({required this.timeSpent, required this.zoomLevel});

  /// How long the garden was on screen.
  final Duration timeSpent;

  /// How far in the camera was when they left: 1 is the garden at its natural
  /// size, and `GardenProjection` bounds how far either way it can go.
  final double zoomLevel;

  @override
  AnalyticsEventName get name => AnalyticsEventName.gardenViewed;

  @override
  Map<String, Object?> get parameters => {
        'time_spent_seconds': timeSpent.inSeconds,
        'zoom_level': zoomLevel,
      };
}

/// The user chose a bed. §7.1: most popular sounds.
///
/// `enabled` is derived rather than passed, because REQ-012 has no off: silence
/// is one of the six choices, and choosing it is the only way to have no bed.
final class AmbientSoundToggled extends AnalyticsEvent {
  const AmbientSoundToggled({required this.sound});

  final AmbientSound sound;

  /// Whether anything will actually play under the next session.
  bool get enabled => sound != AmbientSound.silence;

  @override
  AnalyticsEventName get name => AnalyticsEventName.ambientSoundToggled;

  @override
  Map<String, Object?> get parameters => {
        'sound_type': sound.name,
        'enabled': enabled,
      };
}

/// The user changed a setting. §7.1: customisation patterns.
///
/// Built by [AnalyticsEvent.forSettingsChange] rather than by a control, so
/// adding a setting adds a [SettingKey] and a line there — and no screen has to
/// remember to announce itself.
final class SettingsChanged extends AnalyticsEvent {
  const SettingsChanged({
    required this.setting,
    required this.oldValue,
    required this.newValue,
  });

  final SettingKey setting;

  /// What the setting was, as text. Text because one event has to carry a
  /// duration, a count, a switch and the name of a bed, and the log is read by
  /// a human rather than summed by a machine.
  final String oldValue;
  final String newValue;

  @override
  AnalyticsEventName get name => AnalyticsEventName.settingsChanged;

  @override
  Map<String, Object?> get parameters => {
        'setting_key': setting.recorded,
        'old_value': oldValue,
        'new_value': newValue,
      };
}

/// The app was opened. §7.1: retention tracking.
final class AppOpened extends AnalyticsEvent {
  const AppOpened({required this.daysSinceLastOpen, required this.streakDays});

  /// How many days ago the app was last opened, or null on the first open this
  /// log has ever seen — which is a fresh install, or a log that has been
  /// cleared.
  final int? daysSinceLastOpen;

  /// REQ-029's streak as it stands at the moment of opening.
  final int streakDays;

  @override
  AnalyticsEventName get name => AnalyticsEventName.appOpened;

  @override
  Map<String, Object?> get parameters => {
        'days_since_last_open': daysSinceLastOpen,
        'streak_days': streakDays,
      };
}

/// The user left REQ-003's first run, by either route. §7.1: onboarding
/// friction.
final class OnboardingCompleted extends AnalyticsEvent {
  const OnboardingCompleted({
    required this.stepsCompleted,
    required this.timeToFirstSession,
  });

  /// How many of the three steps the user got through: three for a first
  /// session started, and however many are behind them for a skip.
  final int stepsCompleted;

  /// How long from the welcome screen to the tap that started the session, or
  /// null for a user who skipped and therefore started nothing.
  final Duration? timeToFirstSession;

  @override
  AnalyticsEventName get name => AnalyticsEventName.onboardingCompleted;

  @override
  Map<String, Object?> get parameters => {
        'steps_completed': stepsCompleted,
        'time_to_first_session_seconds': timeToFirstSession?.inSeconds,
      };
}

/// The user made a picture of their garden. §7.1: sharing behaviour.
///
/// Recorded when the image has been handed to the platform's share sheet, not
/// when the user taps export: what §7.1 wants to count is exports that
/// happened, and a render that failed is not one. What the user then does with
/// the sheet — post it, save it to their photos, or dismiss it — is the
/// platform's business and is not reported back, deliberately: an app that knew
/// which app you shared to would be an app collecting something PRD §7.2 says
/// it does not.
///
/// **No parameters, and §7.1's `is_premium` is gone with the thing it
/// described.** There was one kind of export while the app sold a clean one;
/// now there is one kind because there is only one kind of user. See
/// `docs/adr/0021-…`.
final class GardenExported extends AnalyticsEvent {
  const GardenExported();

  @override
  AnalyticsEventName get name => AnalyticsEventName.gardenExported;

  @override
  Map<String, Object?> get parameters => const {};
}

String _seconds(Duration value) => '${value.inSeconds}';

String _number(int value) => '$value';

String _switched(bool value) => value ? 'on' : 'off';

/// Any of the enum-valued settings, by the name their row stores.
///
/// One function for the bed and the end sound rather than one each: both are
/// stored as `name` and both are read back through a `named()`, so the log says
/// exactly what the column says.
String _named(Enum value) => value.name;
