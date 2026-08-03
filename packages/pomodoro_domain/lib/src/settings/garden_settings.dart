import '../garden/garden_theme.dart';
import 'ambient_sound.dart';
import 'break_preset.dart';
import 'end_sound.dart';
import 'session_preset.dart';
import 'setting_range.dart';

/// Setting bounds. The UI controls read these too.
abstract final class SettingsRanges {
  /// 5 to 120 min. The minimum also keeps `SessionMachine.start` from getting
  /// a zero-length session.
  static const SettingRange<Duration> sessionLength = SettingRange(
    min: Duration(minutes: 5),
    max: Duration(minutes: 120),
  );

  /// 1 to 30 min.
  static const SettingRange<Duration> breakLength = SettingRange(
    min: Duration(minutes: 1),
    max: Duration(minutes: 30),
  );

  /// 2–6 sessions between long breaks.
  static const SettingRange<int> longBreakAfter = SettingRange(min: 2, max: 6);
}

/// All user settings as one immutable value. Changing a setting doesn't
/// affect a running session, which keeps its own planned duration.
final class GardenSettings {
  const GardenSettings({
    required this.sessionLength,
    required this.breakLength,
    required this.longBreakAfter,
    required this.hapticsEnabled,
    required this.liveSurfaceEnabled,
    required this.autoStartBreak,
    required this.autoStartNextSession,
    required this.ambientSound,
    required this.endSound,
    required this.gardenTheme,
    required this.quietModeEnabled,
    required this.quietModeHintDismissed,
    required this.onboardingCompleted,
  });

  /// First-run values. Also used when the stored row can't be read.
  static const GardenSettings defaults = GardenSettings(
    sessionLength: Duration(minutes: 25),
    breakLength: Duration(minutes: 5),
    longBreakAfter: 4,
    hapticsEnabled: true,
    liveSurfaceEnabled: true,
    autoStartBreak: false,
    autoStartNextSession: false,
    ambientSound: AmbientSound.silence,
    endSound: EndSound.windChime,
    gardenTheme: GardenTheme.fallback,
    quietModeEnabled: false,
    quietModeHintDismissed: false,
    onboardingCompleted: false,
  );

  static const int longBreakMultiple = 3;

  /// Length of the next session started.
  final Duration sessionLength;

  final Duration breakLength;

  /// Focus sessions before the break becomes a long one.
  final int longBreakAfter;

  /// Covers both the completion buzz and the per-stage tap.
  final bool hapticsEnabled;

  /// Show the running session outside the app (Live Activity on iOS, ongoing
  /// notification on Android). Doesn't affect whether a session completes.
  final bool liveSurfaceEnabled;

  /// Start the break automatically when a session ends. Off by default.
  final bool autoStartBreak;

  /// Start the next session automatically when a break ends. Off by default.
  final bool autoStartNextSession;

  /// Not frozen when a session starts: changing it mid-session changes what's
  /// playing right away. Picked from the timer screen.
  final AmbientSound ambientSound;

  /// No separate on/off switch: [EndSound.none] is how you turn it off.
  final EndSound endSound;

  /// The app reads this through `gardenThemeProvider`, not directly.
  final GardenTheme gardenTheme;

  /// Ask the phone to go quiet during focus. Android only (zen rule); iOS has
  /// no public API to enable Focus, so the toggle isn't shown there. Off by
  /// default.
  final bool quietModeEnabled;

  /// The one-time "how to silence your phone" hint was dismissed. Stored so it
  /// stays dismissed across launches.
  final bool quietModeHintDismissed;

  /// Onboarding done. False when there's no settings row, so a fresh install
  /// shows onboarding.
  final bool onboardingCompleted;

  /// Null for a custom length.
  SessionPreset? get preset => SessionPreset.matching(sessionLength);

  /// Null for a custom length.
  BreakPreset? get breakPreset => BreakPreset.matching(breakLength);

  /// [longBreakMultiple] ordinary breaks, clamped to
  /// [SettingsRanges.breakLength].
  Duration get longBreakLength =>
      SettingsRanges.breakLength.clamp(breakLength * longBreakMultiple);

  /// Clamps instead of throwing: out-of-range values come from old rows or a
  /// miswired control.
  GardenSettings withSessionLength(Duration value) => _copyWith(
        sessionLength: SettingsRanges.sessionLength.clamp(value),
      );

  GardenSettings withBreakLength(Duration value) => _copyWith(
        breakLength: SettingsRanges.breakLength.clamp(value),
      );

  GardenSettings withLongBreakAfter(int value) => _copyWith(
        longBreakAfter: SettingsRanges.longBreakAfter.clamp(value),
      );

  GardenSettings withPreset(SessionPreset preset) =>
      withSessionLength(preset.length);

  GardenSettings withBreakPreset(BreakPreset preset) =>
      withBreakLength(preset.length);

  GardenSettings withHaptics({required bool enabled}) =>
      _copyWith(hapticsEnabled: enabled);

  GardenSettings withLiveSurface({required bool enabled}) =>
      _copyWith(liveSurfaceEnabled: enabled);

  GardenSettings withAutoStartBreak({required bool enabled}) =>
      _copyWith(autoStartBreak: enabled);

  GardenSettings withAutoStartNextSession({required bool enabled}) =>
      _copyWith(autoStartNextSession: enabled);

  GardenSettings withAmbientSound(AmbientSound sound) =>
      _copyWith(ambientSound: sound);

  GardenSettings withEndSound(EndSound sound) => _copyWith(endSound: sound);

  GardenSettings withGardenTheme(GardenTheme theme) =>
      _copyWith(gardenTheme: theme);

  GardenSettings withQuietMode({required bool enabled}) =>
      _copyWith(quietModeEnabled: enabled);

  /// One way only; nothing brings the hint back.
  GardenSettings withQuietModeHintDismissed() =>
      _copyWith(quietModeHintDismissed: true);

  /// Called when the first session starts, not when the last coach mark
  /// closes.
  GardenSettings withOnboardingCompleted() =>
      _copyWith(onboardingCompleted: true);

  /// Debug only (settings screen, compiled out of release builds).
  GardenSettings withOnboardingReset() => _copyWith(onboardingCompleted: false);

  GardenSettings _copyWith({
    Duration? sessionLength,
    Duration? breakLength,
    int? longBreakAfter,
    bool? hapticsEnabled,
    bool? liveSurfaceEnabled,
    bool? autoStartBreak,
    bool? autoStartNextSession,
    AmbientSound? ambientSound,
    EndSound? endSound,
    GardenTheme? gardenTheme,
    bool? quietModeEnabled,
    bool? quietModeHintDismissed,
    bool? onboardingCompleted,
  }) {
    return GardenSettings(
      sessionLength: sessionLength ?? this.sessionLength,
      breakLength: breakLength ?? this.breakLength,
      longBreakAfter: longBreakAfter ?? this.longBreakAfter,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      liveSurfaceEnabled: liveSurfaceEnabled ?? this.liveSurfaceEnabled,
      autoStartBreak: autoStartBreak ?? this.autoStartBreak,
      autoStartNextSession: autoStartNextSession ?? this.autoStartNextSession,
      ambientSound: ambientSound ?? this.ambientSound,
      endSound: endSound ?? this.endSound,
      gardenTheme: gardenTheme ?? this.gardenTheme,
      quietModeEnabled: quietModeEnabled ?? this.quietModeEnabled,
      quietModeHintDismissed:
          quietModeHintDismissed ?? this.quietModeHintDismissed,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GardenSettings &&
      other.sessionLength == sessionLength &&
      other.breakLength == breakLength &&
      other.longBreakAfter == longBreakAfter &&
      other.hapticsEnabled == hapticsEnabled &&
      other.liveSurfaceEnabled == liveSurfaceEnabled &&
      other.autoStartBreak == autoStartBreak &&
      other.autoStartNextSession == autoStartNextSession &&
      other.ambientSound == ambientSound &&
      other.endSound == endSound &&
      other.gardenTheme == gardenTheme &&
      other.quietModeEnabled == quietModeEnabled &&
      other.quietModeHintDismissed == quietModeHintDismissed &&
      other.onboardingCompleted == onboardingCompleted;

  @override
  int get hashCode => Object.hash(
        sessionLength,
        breakLength,
        longBreakAfter,
        hapticsEnabled,
        liveSurfaceEnabled,
        autoStartBreak,
        autoStartNextSession,
        ambientSound,
        endSound,
        gardenTheme,
        quietModeEnabled,
        quietModeHintDismissed,
        onboardingCompleted,
      );

  @override
  String toString() => 'GardenSettings(session $sessionLength, '
      'break $breakLength, long break after $longBreakAfter, '
      'haptics ${hapticsEnabled ? 'on' : 'off'}, '
      'live surface ${liveSurfaceEnabled ? 'on' : 'off'}, '
      'auto-start break ${autoStartBreak ? 'on' : 'off'}, '
      'auto-start next session ${autoStartNextSession ? 'on' : 'off'}, '
      'ambience ${ambientSound.name}, '
      'end sound ${endSound.name}, '
      'quiet mode ${quietModeEnabled ? 'on' : 'off'})';
}
