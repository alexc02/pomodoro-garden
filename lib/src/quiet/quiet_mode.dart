/// What a phone will let this app do about being quiet during a session.
///
/// **This is the honest asymmetry of REQ-014, as a value.** Android can silence
/// itself on request, once the user has granted notification policy access in
/// system settings. iOS cannot: no public API activates a Focus mode, and the
/// ones Apple does publish are read-only (Focus Status) or reactive
/// (`SetFocusFilterIntent`, which only tells an app that a Focus changed).
///
/// So the difference between the two platforms reaches Dart as a *capability*
/// rather than as a platform: nothing above [QuietMode] asks which phone it is
/// on, and the settings screen offers a switch exactly where there is something
/// for a switch to do. A build with no implementation registered — a widget
/// test, a desktop host — reads as [unavailable], which needs no special case
/// anywhere.
enum QuietModeAccess {
  /// Nothing can be done from in here, and there is nothing to offer the user
  /// instead.
  ///
  /// Where a build has no implementation registered, and where a platform is
  /// too old for the mechanism the app uses — an Android below 10 can hold a
  /// zen rule but has no way for its own app to switch one on. The user's route
  /// is the one they always had: turning Do Not Disturb on themselves.
  unavailable,

  /// The platform will not do it on request, but it will let the *user* wire it
  /// up, and the app has donated the piece they need to.
  ///
  /// iOS, and the whole of why REQ-014 is asymmetric. No public API activates a
  /// Focus mode, so the app cannot — but a Shortcuts automation can turn Focus
  /// on and, through the App Intent behind [QuietMode.sessionRequests], start
  /// the session in the same breath. The settings screen answers this with the
  /// recipe rather than with a switch.
  byAutomation,

  /// It will, and this app has not been allowed to.
  ///
  /// Android's `ACCESS_NOTIFICATION_POLICY`, which has no runtime dialog: the
  /// only way to grant it is a system settings screen the user has to be walked
  /// to. See [QuietMode.requestAccess].
  denied,

  /// It will, and this app may.
  granted,
}

/// The phone going quiet for the length of a focus session. REQ-014.
///
/// **One port, two very different platforms behind it, and no Dart above this
/// line knows which.** On Android it is an `AutomaticZenRule` the app registers
/// once and switches on and off; on iOS it is the App Intent a Shortcuts
/// automation runs, because that is the only route by which an iPhone can be
/// put into Focus for a session at all. The two are not a feature and its
/// fallback — they are one requirement and the two platforms' answers to it,
/// which is why they meet here rather than in a view.
///
/// Every method is best-effort by contract, on the same reasoning
/// `SessionNotifications` and `LiveSessionSurface` are: a permission the user
/// revoked, a platform that refuses, a build with nothing registered — none of
/// them changes whether the session completes, so none of them may throw at a
/// caller. A session that could not silence the phone is a noisier session, not
/// a broken one.
abstract interface class QuietMode {
  /// What this phone will let the app do, asked afresh.
  ///
  /// Asked rather than remembered, and asked again every time the app comes
  /// back to the foreground: policy access is granted and revoked in system
  /// settings, which is somewhere the user goes *by leaving this app*. A cached
  /// answer is how a revoked permission becomes a switch that is on and
  /// silently does nothing.
  Future<QuietModeAccess> access();

  /// Takes the user to where the platform lets them grant what [access] says is
  /// missing.
  ///
  /// Android's DND access has no runtime dialog — there is no
  /// `requestPermission` for it — so this opens a system settings screen with a
  /// list of apps in it, and the caller's job is to have explained that before
  /// sending them. Does nothing where there is nothing to grant.
  Future<void> requestAccess();

  /// Silences the phone for the session in flight, until [until] at the latest.
  ///
  /// Safe to call when quiet mode is already on: it is the same rule either
  /// way, and re-asking is how the deadline moves when a held session resumes.
  ///
  /// **[until] is a deadline, not a schedule.** Quiet mode ends when the
  /// session does, and [end] is what ends it — but the app has to be alive to
  /// call [end], and a process the system kills mid-session never is. So the
  /// platform is told when the session is due, and takes its own silence down
  /// at that instant if nothing else has. A phone left permanently silent by an
  /// app the user force-quit is the one failure this feature must not have.
  Future<void> begin({required DateTime until});

  /// Lets the phone make noise again.
  ///
  /// Safe to call when it already can, which is what lets the caller follow one
  /// rule — anything that is not a session in flight is loud — without tracking
  /// what it last did.
  Future<void> end();

  /// Sessions asked for from outside the app.
  ///
  /// **This is iOS's half of REQ-014.** An iPhone cannot be put into Focus by
  /// this app, but it can by a Shortcut the user builds — and a Shortcut that
  /// turns Focus on is only useful if it can start the session too. So the app
  /// donates an App Intent, the user wires it into an automation next to
  /// *Set Focus*, and running it arrives here.
  ///
  /// A broadcast stream, and it emits for a *cold* launch too: the intent opens
  /// an app that was not running, and the request has to survive until there is
  /// Dart alive to hear it. What arrives is the event, not a payload — the
  /// session's length is the user's setting, exactly as it is for a tap on
  /// START.
  Stream<void> get sessionRequests;
}
