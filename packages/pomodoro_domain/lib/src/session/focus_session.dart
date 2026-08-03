/// How a session ended. Null while it's running, then set once.
enum SessionOutcome {
  /// Reached its planned duration. Only this earns a plant.
  completed,

  /// The user stopped it.
  cancelled,

  /// App was force-quit while it ran.
  voided,
}

/// One focus session. Immutable; saved at start and updated on pause, resume
/// and end (ADR 0002).
final class FocusSession {
  const FocusSession({
    required this.id,
    required this.startedAt,
    required this.plannedDuration,
    this.pausedDuration = Duration.zero,
    this.pausedSince,
    this.endedAt,
    this.outcome,
  });

  final String id;

  /// UTC start. Elapsed time is measured from here, not accumulated.
  final DateTime startedAt;

  /// Fixed for the life of the session.
  final Duration plannedDuration;

  /// Total of finished pauses. The open pause, if any, isn't included.
  final Duration pausedDuration;

  /// Start of the current pause, or null. Stored so a restored session comes
  /// back paused.
  final DateTime? pausedSince;

  /// Null while running. For completed sessions this is when the timer ran
  /// out, not when the app noticed.
  final DateTime? endedAt;

  final SessionOutcome? outcome;

  bool get completed => outcome == SessionOutcome.completed;

  bool get isPaused => pausedSince != null;

  bool get hasEnded => outcome != null;

  /// [pausedDuration] isn't updated until the pause ends.
  FocusSession pausedAt(DateTime instant) => FocusSession(
        id: id,
        startedAt: startedAt,
        plannedDuration: plannedDuration,
        pausedDuration: pausedDuration,
        pausedSince: instant,
        endedAt: endedAt,
        outcome: outcome,
      );

  /// Folds the open pause into [pausedDuration].
  FocusSession resumedAt(DateTime instant) => _withPauseClosedAt(instant);

  FocusSession completedAt(DateTime instant) =>
      _endedAt(instant, SessionOutcome.completed);

  FocusSession cancelledAt(DateTime instant) =>
      _endedAt(instant, SessionOutcome.cancelled);

  FocusSession voidedAt(DateTime instant) =>
      _endedAt(instant, SessionOutcome.voided);

  /// Also closes any open pause.
  FocusSession _endedAt(DateTime instant, SessionOutcome outcome) =>
      _withPauseClosedAt(instant, endedAt: instant, outcome: outcome);

  FocusSession _withPauseClosedAt(
    DateTime instant, {
    DateTime? endedAt,
    SessionOutcome? outcome,
  }) =>
      FocusSession(
        id: id,
        startedAt: startedAt,
        plannedDuration: plannedDuration,
        pausedDuration: pausedDuration + _pauseEndingAt(instant),
        endedAt: endedAt ?? this.endedAt,
        outcome: outcome ?? this.outcome,
      );

  /// Clamped at zero in case the clock went backwards mid-pause.
  Duration _pauseEndingAt(DateTime instant) {
    final open = pausedSince;
    if (open == null) return Duration.zero;
    final ran = instant.difference(open);
    return ran.isNegative ? Duration.zero : ran;
  }

  @override
  String toString() => 'FocusSession($id, started $startedAt, '
      'planned $plannedDuration, paused $pausedDuration, '
      'outcome ${outcome?.name ?? 'in flight'})';
}
