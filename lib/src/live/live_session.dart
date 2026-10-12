import 'package:pomodoro_domain/pomodoro_domain.dart';

/// What gets sent to the iOS Live Activity / Android ongoing notification.
///
/// The platforms count down to [endsAt] themselves (`Text(timerInterval:)`, a
/// chronometer), so this only needs pushing when the stage or phase changes.
final class LiveSession {
  const LiveSession({
    required this.sessionId,
    required this.paused,
    required this.endsAt,
    required this.remaining,
    required this.progress,
    required this.growing,
  });

  /// Null unless a focus session is running or paused. Completed sessions are
  /// announced by the notification instead, and breaks have no plant to show
  /// (their end is still announced by the scheduled notification).
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

  /// Lets the platform tell an update from a new session.
  final String sessionId;

  /// Neither platform can pause a countdown, so when paused the surface shows
  /// a static [remaining] instead.
  final bool paused;

  /// The snapshot's `dueAt`. Constant while running; moves while paused.
  final DateTime endsAt;

  /// As of when this was read.
  final Duration remaining;

  /// 0 to 1.
  final double progress;

  final PlantGrowth growing;

  /// Whether [other] would look identical on the surface, so the push can be
  /// skipped. Compares [endsAt] while running and [remaining] while paused,
  /// since the other one changes every tick. Resuming flips [paused], so a
  /// fresh [endsAt] still gets pushed.
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

/// Shows a running session outside the app. iOS: an ActivityKit Live
/// Activity (Dynamic Island or lock screen). Android: a foreground service
/// with an ongoing notification.
///
/// Best-effort; nothing here may throw at a caller.
abstract interface class LiveSessionSurface {
  /// Starts or updates; the platform uses [LiveSession.sessionId] to tell
  /// which.
  Future<void> show(LiveSession session);

  /// Safe to call when nothing is showing.
  Future<void> hide();

  /// Taps on the surface. Broadcast, and also emits after a cold launch from a
  /// tap. No payload.
  Stream<void> get opened;
}
