import '../garden/garden_theme.dart';
import 'ambient_sound.dart';
import 'break_preset.dart';
import 'end_sound.dart';
import 'session_preset.dart';
import 'setting_range.dart';

/// REQ-030's bounds, and the only place they are written down.
///
/// Both the control that offers a value and the code that accepts one read
/// them from here, so a slider cannot offer a length the settings would refuse.
abstract final class SettingsRanges {
  /// 5–120 minutes. The lower bound is what stops a mis-wired control handing
  /// `SessionMachine.start` a session with no time in it.
  static const SettingRange<Duration> sessionLength = SettingRange(
    min: Duration(minutes: 5),
    max: Duration(minutes: 120),
  );

  /// 1–30 minutes.
  static const SettingRange<Duration> breakLength = SettingRange(
    min: Duration(minutes: 1),
    max: Duration(minutes: 30),
  );

  /// 2–6 sessions between long breaks.
  static const SettingRange<int> longBreakAfter = SettingRange(min: 2, max: 6);
}

/// Everything the user has chosen about how their timer behaves.
///
/// One immutable value rather than a bag of keys: this is the typed accessor
/// the whole app reads its settings through, so a later ticket adding a field
/// adds it here and to the row mapping, and touches no call site. Changing a
/// setting produces a new [GardenSettings] — nothing mutates underneath a
/// session that is already running, because a running session holds the planned
/// duration it started with.
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

  /// What a first run looks like, before anything has been stored: REQ-002's
  /// 25-minute session, a 5-minute break, and a long break after 4 sessions.
  ///
  /// Also the fallback for a settings row that cannot be read. A user who has
  /// never opened settings and one whose row is missing want the same thing —
  /// a timer that works — and neither is served by an error.
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

  /// How many ordinary breaks a long one is worth. See [longBreakLength].
  static const int longBreakMultiple = 3;

  /// How long the *next* session started will run. REQ-006, REQ-030.
  final Duration sessionLength;

  /// How long a break runs. REQ-007, REQ-030. Ticket 09 is the first to start
  /// one; it is settable now because settings are a surface, not a feature —
  /// see the ticket-03 note in the README.
  final Duration breakLength;

  /// How many focus sessions run before the break becomes a long one.
  final int longBreakAfter;

  /// Whether the phone is allowed to answer with a tap: REQ-037's gentle buzz
  /// at completion, and the subtler one each time the plant grows a stage.
  ///
  /// One switch for both, because they are one thing to the user — whether the
  /// app talks to their hand — and a screen that offered two would be asking
  /// them to have an opinion they do not have.
  final bool hapticsEnabled;

  /// REQ-033: whether a running session is shown outside the app — on the lock
  /// screen and the Dynamic Island on iOS, in an ongoing notification on
  /// Android.
  ///
  /// One switch for both platforms, because it is one thing to the user:
  /// whether their phone shows the session while they are not looking at the
  /// app. What that looks like is the platform's business, not the setting's.
  ///
  /// Turning it off never touches whether a session *completes*. The session is
  /// anchored to the wall clock and its end is announced by the notification
  /// ticket 06 schedules; the live surface is a window onto a session, not the
  /// thing that runs it.
  final bool liveSurfaceEnabled;

  /// REQ-032: whether a break begins on its own when a focus session finishes,
  /// rather than waiting for the user to accept the one they were offered.
  ///
  /// Off by default, and that is the ticket's requirement rather than a
  /// preference: an app that starts counting something the user did not ask for
  /// has taken a decision away from them. Turning it on is how they give it.
  final bool autoStartBreak;

  /// REQ-032: whether a focus session begins on its own when a break ends.
  ///
  /// The other half of the unattended cycle, and off by default for the same
  /// reason. With both on, focus → break → focus runs without a tap.
  final bool autoStartNextSession;

  /// REQ-012: which of the six beds plays under a focus session.
  ///
  /// A setting rather than a per-session choice, and that is the ticket's
  /// requirement — the bed the user picked mid-session is the one the next
  /// session starts with. Unlike [sessionLength] it is *not* frozen when a
  /// session begins: changing it while one runs changes what is playing, there
  /// and then, because a bed is something the user is listening to rather than
  /// something the session was handed.
  ///
  /// The control lives on the timer screen rather than in settings, which is
  /// the one place the user is when the answer matters.
  final AmbientSound ambientSound;

  /// REQ-031: which of the six sounds a finished session or break makes.
  ///
  /// A setting rather than a per-session choice, and unlike [ambientSound] it
  /// has no reason to be reachable from the timer: the moment it matters is the
  /// moment the session ends, which is too late to choose. One row in settings
  /// is the whole surface.
  ///
  /// **No switch beside it.** [EndSound.none] is already the user's way of
  /// turning the sound off, and the reasoning in [hapticsEnabled] applies here
  /// unchanged — a separate on/off next to a six-way choice would be two
  /// controls for one decision.
  ///
  /// Defaulted to the wind chime rather than to silence, which is the opposite
  /// of the bed and right for the opposite reason: a chime at the end of
  /// something the user asked for is the app answering, where a bed under the
  /// whole session is the app deciding about the room they are sitting in.
  final EndSound endSound;

  /// REQ-034: which of the three biomes the garden is dressed in.
  ///
  /// What the user picked, and what the garden is drawn in — the app reads it
  /// through `gardenThemeProvider` rather than reaching for this field, so that
  /// "which biome is on screen" stays one question with one answer.
  ///
  /// Defaulted to `GardenTheme.fallback`, which is both what a fresh install
  /// means and the only safe reading of a row written before this ticket.
  final GardenTheme gardenTheme;

  /// REQ-014: whether the phone is asked to go quiet for the length of a focus
  /// session.
  ///
  /// One field, and it means one thing — *the user asked for their phone to be
  /// silenced while they focus* — but only one of the two platforms can act on
  /// it. Android registers a zen rule and turns it on; iOS has no public API
  /// that can enable a Focus mode at all, so the control that writes this never
  /// appears there. What can be done about it is asked of the quiet-mode port,
  /// which is the only thing in the app that knows the difference.
  ///
  /// Off by default, and unlike every other default in here that is not a
  /// preference but a rule: an app that silenced somebody's phone because they
  /// installed it would be deciding, on their behalf, which calls they miss.
  final bool quietModeEnabled;

  /// Whether the user has put away the one-time hint explaining how to silence
  /// a phone the app cannot silence itself.
  ///
  /// Stored rather than shown once per run, because "one-time" has to mean once
  /// ever — a hint that came back on every launch would be the nagging PRD §2
  /// is written against. It stays false forever on a platform that never shows
  /// the hint, which costs nothing and keeps the field free of any notion of
  /// which phone this is.
  final bool quietModeHintDismissed;

  /// REQ-003: whether the user has been through the three steps that end in
  /// their first session.
  ///
  /// Not a preference either, and here for the reason [quietModeHintDismissed]
  /// is: this is the app's single-row store, and "has this person met the app
  /// before" is one bit that would otherwise need a table of its own for the
  /// rest of the app's life. PRD §4.3 puts it here by name.
  ///
  /// False on a device with no settings row — which is a device the app has
  /// never been opened on — so the absence of a row is what makes onboarding
  /// appear, and the row written when it finishes is what stops it appearing
  /// again.
  final bool onboardingCompleted;

  /// The preset [sessionLength] is currently on, or null when it is a length no
  /// preset names.
  SessionPreset? get preset => SessionPreset.matching(sessionLength);

  /// The preset [breakLength] is currently on, or null when it is a length no
  /// preset names.
  BreakPreset? get breakPreset => BreakPreset.matching(breakLength);

  /// How long the long break runs: [longBreakMultiple] ordinary breaks, and
  /// never longer than the longest break these settings would accept.
  ///
  /// **Derived rather than chosen.** REQ-030 gives the user one break slider
  /// and one long-break cycle, and no second length — so a long break has to
  /// come from somewhere, and the only honest source is the break they already
  /// chose. Three times over lands the default 5-minute break on the 15 minutes
  /// REQ-007 names as its Long preset, which is the number this would have been
  /// given a slider of its own.
  ///
  /// Clamped into [SettingsRanges.breakLength] so that a user who drags the
  /// break slider to its 30-minute end does not thereby invent a 90-minute
  /// break the settings would refuse to store.
  Duration get longBreakLength =>
      SettingsRanges.breakLength.clamp(breakLength * longBreakMultiple);

  /// These settings with [value] as the session length, clamped into
  /// [SettingsRanges.sessionLength].
  ///
  /// Clamped rather than rejected because out-of-range values arrive from
  /// places that cannot usefully handle an exception: a row written by a build
  /// whose bounds differed, or a control wired up wrong. Refusing would leave
  /// the app with no session length at all; clamping leaves it with the nearest
  /// legal one.
  GardenSettings withSessionLength(Duration value) => _copyWith(
        sessionLength: SettingsRanges.sessionLength.clamp(value),
      );

  /// These settings with [value] as the break length, clamped into
  /// [SettingsRanges.breakLength].
  GardenSettings withBreakLength(Duration value) => _copyWith(
        breakLength: SettingsRanges.breakLength.clamp(value),
      );

  /// These settings with [value] as the long-break cycle, clamped into
  /// [SettingsRanges.longBreakAfter].
  GardenSettings withLongBreakAfter(int value) => _copyWith(
        longBreakAfter: SettingsRanges.longBreakAfter.clamp(value),
      );

  /// These settings with [preset]'s length as the session length.
  GardenSettings withPreset(SessionPreset preset) =>
      withSessionLength(preset.length);

  /// These settings with [preset]'s length as the break length.
  GardenSettings withBreakPreset(BreakPreset preset) =>
      withBreakLength(preset.length);

  /// These settings with haptic feedback on or off. REQ-037.
  ///
  /// Named rather than positional because `withHaptics(false)` at a call site
  /// reads as if it turned something else off.
  GardenSettings withHaptics({required bool enabled}) =>
      _copyWith(hapticsEnabled: enabled);

  /// These settings with the live session surface on or off. REQ-033. Named for
  /// the same reason [withHaptics] is.
  GardenSettings withLiveSurface({required bool enabled}) =>
      _copyWith(liveSurfaceEnabled: enabled);

  /// These settings with breaks starting on their own, or waiting to be
  /// accepted. REQ-032, and named for the same reason [withHaptics] is.
  GardenSettings withAutoStartBreak({required bool enabled}) =>
      _copyWith(autoStartBreak: enabled);

  /// These settings with the session after a break starting on its own, or
  /// waiting to be started. REQ-032.
  GardenSettings withAutoStartNextSession({required bool enabled}) =>
      _copyWith(autoStartNextSession: enabled);

  /// These settings with [sound] as the bed under a focus session. REQ-012.
  ///
  /// Positional rather than named, unlike the switches above it: a bed has a
  /// name of its own and `withAmbientSound(AmbientSound.rain)` cannot be read
  /// as turning anything else on.
  GardenSettings withAmbientSound(AmbientSound sound) =>
      _copyWith(ambientSound: sound);

  /// These settings with [sound] as what a finished session makes. REQ-031.
  ///
  /// Positional for the reason [withAmbientSound] is: a sound has a name of its
  /// own, and `withEndSound(EndSound.none)` cannot be read as turning anything
  /// else off.
  GardenSettings withEndSound(EndSound sound) => _copyWith(endSound: sound);

  /// These settings with [theme] as the garden's biome. REQ-034.
  ///
  /// Stores what the user picked, and the garden is drawn from the same value
  /// on the next frame.
  GardenSettings withGardenTheme(GardenTheme theme) =>
      _copyWith(gardenTheme: theme);

  /// These settings with quiet mode asked for, or not. REQ-014, and named for
  /// the same reason [withHaptics] is.
  GardenSettings withQuietMode({required bool enabled}) =>
      _copyWith(quietModeEnabled: enabled);

  /// These settings with the quiet-mode hint put away for good.
  ///
  /// One direction only, deliberately: the hint is dismissed by the user and
  /// nothing brings it back, so there is no `enabled:` to get the wrong way
  /// round and no path by which the app can decide to show it again.
  GardenSettings withQuietModeHintDismissed() =>
      _copyWith(quietModeHintDismissed: true);

  /// These settings with onboarding behind the user. REQ-003.
  ///
  /// Written the moment their first session starts rather than when the last
  /// coach mark is put away: what onboarding is for is the session, and a user
  /// who has one running has been through it whatever happens to the app next.
  GardenSettings withOnboardingCompleted() =>
      _copyWith(onboardingCompleted: true);

  /// These settings with onboarding ahead of the user again.
  ///
  /// The one setter in here that undoes something rather than recording it, and
  /// it exists for the debug affordance the ticket asks for: onboarding is seen
  /// once per install, so without a way back there is no way to look at it
  /// twice. See the settings screen's **Onboarding (debug)** section, which is
  /// compiled out of release builds — nothing a user can reach calls this.
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

  /// Settings compare by value: two readings that describe the same choices are
  /// the same choices, and nothing watching them should repaint between them.
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
