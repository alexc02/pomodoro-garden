/// What a phone will let this app do about being quiet during a session.
///
/// Android can enable DND once the user grants notification policy access.
/// iOS has no public API to turn on a Focus, so the best we can do is a
/// Shortcuts automation. Callers see a capability, never a platform; with no
/// implementation registered (tests, desktop) it reads as [unavailable].
enum QuietModeAccess {
  /// No implementation, or Android below 10 (can't switch its own zen rule).
  unavailable,

  /// iOS: the user can set up a Shortcuts automation that turns on Focus and
  /// runs our App Intent (see [QuietMode.sessionRequests]). Settings shows the
  /// recipe instead of a switch.
  byAutomation,

  /// Android without `ACCESS_NOTIFICATION_POLICY`. No runtime dialog; see
  /// [QuietMode.requestAccess].
  denied,

  granted,
}

/// Silences the phone for a focus session. Android: an `AutomaticZenRule`.
/// iOS: an App Intent run from a Shortcuts automation.
///
/// Best-effort; nothing here may throw at a caller.
abstract interface class QuietMode {
  /// Always re-queried, never cached: the user can revoke access in system
  /// settings at any time.
  Future<QuietModeAccess> access();

  /// Opens the system settings screen for DND access (there is no runtime
  /// prompt), so explain first. No-op where there's nothing to grant.
  Future<void> requestAccess();

  /// Silences the phone until [until] at the latest. Safe to call again; that's
  /// how the deadline moves on resume.
  ///
  /// [until] is a fallback: the platform lifts quiet mode itself at that time
  /// in case the app is killed before it can call [end].
  Future<void> begin({required DateTime until});

  /// Safe to call when already loud.
  Future<void> end();

  /// Session starts triggered by the iOS App Intent from a Shortcut.
  ///
  /// Broadcast, and also emits after a cold launch by the intent. Carries no
  /// payload; the length comes from settings like a normal START.
  Stream<void> get sessionRequests;
}
