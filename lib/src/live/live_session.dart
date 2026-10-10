import 'package:pomodoro_domain/pomodoro_domain.dart';

/// A running session, as something outside the app can show it.
///
/// The one value that crosses to the platform, and the whole of what either
/// surface knows: iOS builds a Live Activity out of it, Android builds an
/// ongoing notification out of it, and both are handed the same thing. What
/// each *draws* differs — an island has a ring where a notification has a
/// progress bar — but the description they are drawing from does not, which is
/// what keeps the two surfaces two renderings of one session rather than two
/// features that happen to share a name.
///
/// **[endsAt] is why the countdown does not need this app.** It is an absolute
/// instant, so a surface handed one can count down to it on its own for the
/// next two hours with nothing of ours running — `Text(timerInterval:)` on iOS
/// and a chronometer on Android both take exactly this. Everything else here is
/// a thing that changes rarely enough to push: the stage changes four times in
/// a session, the phase only when the user taps.
final class LiveSession {
  const LiveSession({
    required this.sessionId,
    required this.paused,
    required this.endsAt,
    required this.remaining,
    required this.progress,
    required this.growing,
  });

  /// What [snapshot] should be showing outside the app, or null if nothing
  /// should be.
  ///
  /// Null for idle and for completed, and those are the same answer for
  /// different reasons: idle has no session, and a completed one has already
  /// been announced by ticket 06's notification. A surface that lingered after
  /// the session it describes would be the second thing telling the user about
  /// one completion, which is exactly what ticket 06's rule forbids.
  ///
  /// Null too for a session with no plant to name, or none due to end —
  /// reachable only for a snapshot the machine could not describe, and a
  /// surface with a blank where the plant goes is worse than no surface.
  ///
  /// **A break is not shown outside the app.** It has no plant, and a plant is
  /// what both surfaces are built around — REQ-010's expanded island is the
  /// growth stage, and an ongoing notification with an empty icon is a worse
  /// answer than no notification. The break still ends on time and still says
  /// so: it is anchored to the wall clock like everything else here, and ticket
  /// 06's scheduled notice is what announces it. A break is a rest, and a lock
  /// screen counting one down is the app asking to be watched during the one
  /// stretch it has just told the user not to.
  static LiveSession? of(SessionSnapshot snapshot) {
    final growing = snapshot.growing;
    final dueAt = snapshot.dueAt;
    if (growing == null || dueAt == null) return null;

    return switch (snapshot.phase) {
      SessionPhase.idle ||
      SessionPhase.completed ||
      SessionPhase.onBreak ||
      SessionPhase.breakOver =>
        null,
      SessionPhase.running || SessionPhase.paused => LiveSession(
          sessionId: growing.sessionId,
          paused: snapshot.phase == SessionPhase.paused,
          endsAt: dueAt,
          remaining: snapshot.remaining,
          progress: snapshot.progress,
          growing: growing,
        ),
    };
  }

  /// The session being shown. What tells an update to an existing surface apart
  /// from a new session's — the platforms need to know whether to replace or to
  /// start again.
  final String sessionId;

  /// Whether the countdown is held.
  ///
  /// A paused surface shows [remaining] standing still. Neither platform can
  /// hold a running countdown — both count against the wall clock — so a held
  /// session is drawn rather than timed, and [endsAt] is what it *would* end at
  /// if it were resumed this instant.
  final bool paused;

  /// The instant this session reaches its planned duration, as things stand —
  /// the snapshot's `dueAt`.
  ///
  /// Moves while the session is held, which is the only time it moves. That is
  /// what makes it safe to compare surfaces on: a running session's end instant
  /// is the same number on every tick, so a surface pushed once keeps counting
  /// down correctly without being pushed again.
  final DateTime endsAt;

  /// Planned duration minus elapsed, at the instant this was read.
  final Duration remaining;

  /// Elapsed as a fraction of the planned duration, 0 to 1 — what the ring
  /// fills to.
  final double progress;

  /// What the session is growing and how grown it looks: the plant icon and the
  /// growth stage REQ-010 asks the expanded surface to show.
  final PlantGrowth growing;

  /// Whether [other] would be drawn exactly as this is.
  ///
  /// **The rule is: compare what the surface draws, and nothing else.** A push
  /// per second would be sixty platform channel crossings a minute — and on
  /// Android sixty notification updates — to redraw something already correct,
  /// so anything the platform works out for itself has no business here.
  ///
  /// Which of [endsAt] and [remaining] that is depends on whether the session
  /// is held, because the two are drawn by different means:
  ///
  /// - **Running**, the platform counts down to [endsAt] on its own, so that is
  ///   what is compared. It stands still while a session runs, and [remaining]
  ///   is the thing moving.
  /// - **Held**, neither platform can hold a countdown — both count against the
  ///   wall clock — so what is drawn is [remaining], standing still, and
  ///   [endsAt] is the thing moving. Comparing [endsAt] here would push once a
  ///   second for the whole of a pause, to redraw an unchanged number.
  ///
  /// The moving one is never lost: resuming flips [paused], which is a
  /// difference, so the surface is pushed with a fresh [endsAt] at the moment
  /// it starts counting again.
  bool showsTheSameAs(LiveSession other) =>
      other.sessionId == sessionId &&
      other.paused == paused &&
      other.growing == growing &&
      (paused ? other.remaining == remaining : other.endsAt == endsAt);

  @override
  bool operator ==(Object other) =>
      other is LiveSession &&
      other.sessionId == sessionId &&
      other.paused == paused &&
      other.endsAt == endsAt &&
      other.remaining == remaining &&
      other.progress == progress &&
      other.growing == growing;

  @override
  int get hashCode =>
      Object.hash(sessionId, paused, endsAt, remaining, progress, growing);

  @override
  String toString() => 'LiveSession($sessionId, ${growing.stage.name}, '
      '${paused ? 'paused at' : 'ends at'} $endsAt)';
}

/// The one port the app shows a running session through, wherever the user is
/// not looking.
///
/// **Two implementations sit behind this and no Dart code knows which.** On
/// iOS it is an ActivityKit Live Activity — the Dynamic Island when the device
/// has one, the lock screen when it does not, both from the same activity. On
/// Android there is no equivalent of either, so it is a foreground service
/// posting an ongoing notification, which additionally keeps the process alive
/// in a way iOS gets for free. That asymmetry is real and it stops here: above
/// this line there is one running session being shown, and REQ-010 and REQ-011
/// are two answers to it rather than two features.
///
/// Every method is best-effort by contract, on the same reasoning
/// [SessionNotifications] is: a refused permission, a device that will not
/// start an activity, an OEM that kills the service — none of them changes
/// whether the session completes, so none of them may throw at a caller. The
/// session is anchored to the wall clock and recorded from it whether or not
/// any of this works.
abstract interface class LiveSessionSurface {
  /// Shows [session] outside the app, replacing whatever was showing.
  ///
  /// One call for both starting and updating. The platforms tell the two apart
  /// from [LiveSession.sessionId] — there is one session, so there is one
  /// surface, and a caller has nothing to remember.
  Future<void> show(LiveSession session);

  /// Takes the surface down.
  ///
  /// Safe to call when nothing is showing, which is what makes "hide on
  /// anything that is not a running session" a rule the caller can follow
  /// without tracking what it last did.
  Future<void> hide();

  /// The user tapping the surface to come back to their session.
  ///
  /// A broadcast stream, and it emits for a *cold* launch too: tapping the
  /// notification of an app that is not running starts the app, and the tap has
  /// to survive until there is Dart alive to hear it. What arrives is the
  /// event, not a payload — there is one session, so "which" is not a question.
  Stream<void> get opened;
}
