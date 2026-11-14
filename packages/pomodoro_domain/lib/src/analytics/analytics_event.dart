import '../garden/growth_stage.dart';
import '../garden/plant_type.dart';
import '../settings/ambient_sound.dart';
import '../settings/garden_settings.dart';
import '../settings/session_preset.dart';

/// Event names, so call sites can't typo them. Only events something actually
/// records are listed (paywall and purchase events went with ADR 0005).
enum AnalyticsEventName {
  sessionStarted('session_started'),
  sessionCompleted('session_completed'),
  sessionAbandoned('session_abandoned'),
  sessionPaused('session_paused'),
  plantGrown('plant_grown'),
  plantShelved('plant_shelved'),
  plantReplanted('plant_replanted'),
  gardenViewed('garden_viewed'),
  ambientSoundToggled('ambient_sound_toggled'),
  settingsChanged('settings_changed'),
  appOpened('app_opened'),
  onboardingCompleted('onboarding_completed'),
  gardenExported('garden_exported');

  const AnalyticsEventName(this.recorded);

  /// The stored name. Spelled out instead of derived from [name] so renaming a
  /// member doesn't split the log.
  final String recorded;

  /// Null for names from a newer build instead of throwing.
  static AnalyticsEventName? named(String recorded) {
    for (final name in values) {
      if (name.recorded == recorded) return name;
    }
    return null;
  }
}

/// The user-facing settings tracked by [SettingsChanged]. Leaves out the hint
/// and onboarding flags, which aren't preferences.
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

  /// Value of the `setting_key` parameter.
  final String recorded;
}

/// A typed analytics event. Call sites build these so params can't be
/// misspelled or missing; [parameters] flattens them for the log.
///
/// Durations go out in seconds (`duration_seconds`), per ADR 0003.
sealed class AnalyticsEvent {
  const AnalyticsEvent();

  /// Events for a settings change, found by diffing [before] and [after] so no
  /// control has to report itself. A sound change also emits
  /// [AmbientSoundToggled].
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

  AnalyticsEventName get name;

  /// JSON-safe values only (strings, numbers, bools, null).
  Map<String, Object?> get parameters;

  @override
  String toString() => '${name.recorded}($parameters)';
}

/// A focus session started.
final class SessionStarted extends AnalyticsEvent {
  const SessionStarted({required this.duration, required this.isCustom});

  factory SessionStarted.of(Duration plannedDuration) => SessionStarted(
        duration: plannedDuration,
        isCustom: SessionPreset.matching(plannedDuration) == null,
      );

  final Duration duration;

  /// True when no preset matches the length.
  final bool isCustom;

  @override
  AnalyticsEventName get name => AnalyticsEventName.sessionStarted;

  @override
  Map<String, Object?> get parameters => {
        'duration_seconds': duration.inSeconds,
        'is_custom': isCustom,
      };
}

/// A focus session reached its planned duration.
final class SessionCompleted extends AnalyticsEvent {
  const SessionCompleted({required this.duration, required this.pausedCount});

  final Duration duration;

  /// Counted in memory by `SessionController`, not stored, so it resets if the
  /// app is killed mid-session.
  final int pausedCount;

  @override
  AnalyticsEventName get name => AnalyticsEventName.sessionCompleted;

  @override
  Map<String, Object?> get parameters => {
        'duration_seconds': duration.inSeconds,
        'paused_count': pausedCount,
      };
}

/// The user cancelled a focus session. Not sent for voided sessions (app
/// killed), since nobody chose to stop.
final class SessionAbandoned extends AnalyticsEvent {
  const SessionAbandoned({
    required this.duration,
    required this.elapsedBeforeAbandon,
  });

  final Duration duration;

  /// Focused time before cancelling.
  final Duration elapsedBeforeAbandon;

  @override
  AnalyticsEventName get name => AnalyticsEventName.sessionAbandoned;

  @override
  Map<String, Object?> get parameters => {
        'duration_seconds': duration.inSeconds,
        'elapsed_before_abandon_seconds': elapsedBeforeAbandon.inSeconds,
      };
}

/// The user paused a running session.
final class SessionPaused extends AnalyticsEvent {
  const SessionPaused({required this.duration, required this.pauseCount});

  final Duration duration;

  /// 1 for the first pause.
  final int pauseCount;

  @override
  AnalyticsEventName get name => AnalyticsEventName.sessionPaused;

  @override
  Map<String, Object?> get parameters => {
        'duration_seconds': duration.inSeconds,
        'pause_count': pauseCount,
      };
}

/// A plant was added to the garden, from a session or a milestone.
final class PlantGrown extends AnalyticsEvent {
  const PlantGrown({required this.species, required this.stageReached});

  final PlantSpecies species;

  /// Should always be mature. Anything else means the growth rules changed.
  final GrowthStage stageReached;

  @override
  AnalyticsEventName get name => AnalyticsEventName.plantGrown;

  @override
  Map<String, Object?> get parameters => {
        'species': species.name,
        'stage_reached': stageReached.name,
      };
}

/// The user moved a plant from the garden to the shelf. Not recorded for
/// plants that go there because the garden is full.
final class PlantShelved extends AnalyticsEvent {
  const PlantShelved({required this.species});

  final PlantSpecies species;

  @override
  AnalyticsEventName get name => AnalyticsEventName.plantShelved;

  @override
  Map<String, Object?> get parameters => {'species': species.name};
}

/// The user planted a shelved plant back in the garden.
final class PlantReplanted extends AnalyticsEvent {
  const PlantReplanted({required this.species, required this.pickedPlot});

  final PlantSpecies species;

  /// True from the arrange picker, where the user chose the plot. False from
  /// the shelf, which takes the nearest free one.
  final bool pickedPlot;

  @override
  AnalyticsEventName get name => AnalyticsEventName.plantReplanted;

  @override
  Map<String, Object?> get parameters => {
        'species': species.name,
        'picked_plot': pickedPlot,
      };
}

/// Time spent on the garden tab, sent when the user leaves it.
final class GardenViewed extends AnalyticsEvent {
  const GardenViewed({required this.timeSpent, required this.zoomLevel});

  final Duration timeSpent;

  /// Zoom when they left. 1 is natural size; `GardenProjection` sets the
  /// bounds.
  final double zoomLevel;

  @override
  AnalyticsEventName get name => AnalyticsEventName.gardenViewed;

  @override
  Map<String, Object?> get parameters => {
        'time_spent_seconds': timeSpent.inSeconds,
        'zoom_level': zoomLevel,
      };
}

/// The user picked an ambient sound. `enabled` is derived because silence is
/// one of the choices rather than an off switch.
final class AmbientSoundToggled extends AnalyticsEvent {
  const AmbientSoundToggled({required this.sound});

  final AmbientSound sound;

  bool get enabled => sound != AmbientSound.silence;

  @override
  AnalyticsEventName get name => AnalyticsEventName.ambientSoundToggled;

  @override
  Map<String, Object?> get parameters => {
        'sound_type': sound.name,
        'enabled': enabled,
      };
}

/// A setting changed. Built by [AnalyticsEvent.forSettingsChange].
final class SettingsChanged extends AnalyticsEvent {
  const SettingsChanged({
    required this.setting,
    required this.oldValue,
    required this.newValue,
  });

  final SettingKey setting;

  /// As text, since the values have different types.
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

/// The app was opened.
final class AppOpened extends AnalyticsEvent {
  const AppOpened({required this.daysSinceLastOpen, required this.streakDays});

  /// Null on the first open the log has seen (fresh install or cleared log).
  final int? daysSinceLastOpen;

  final int streakDays;

  @override
  AnalyticsEventName get name => AnalyticsEventName.appOpened;

  @override
  Map<String, Object?> get parameters => {
        'days_since_last_open': daysSinceLastOpen,
        'streak_days': streakDays,
      };
}

/// The user finished or skipped onboarding.
final class OnboardingCompleted extends AnalyticsEvent {
  const OnboardingCompleted({
    required this.stepsCompleted,
    required this.timeToFirstSession,
  });

  /// 3 if they started a session, fewer if they skipped.
  final int stepsCompleted;

  /// Welcome screen to first session start. Null if skipped.
  final Duration? timeToFirstSession;

  @override
  AnalyticsEventName get name => AnalyticsEventName.onboardingCompleted;

  @override
  Map<String, Object?> get parameters => {
        'steps_completed': stepsCompleted,
        'time_to_first_session_seconds': timeToFirstSession?.inSeconds,
      };
}

/// A garden image was handed to the share sheet. Sent then, not on tap, so
/// failed renders don't count. What happens in the sheet isn't tracked.
/// No parameters (`is_premium` went away with ADR 0005).
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

/// Enum settings, logged by their stored `name`.
String _named(Enum value) => value.name;
