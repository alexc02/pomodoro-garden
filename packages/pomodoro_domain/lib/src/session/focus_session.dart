/// How a session stopped running.
///
/// Null on a session still in flight; set once, when the session ends, and
/// never changed after. Cancelled and voided are told apart even though they
/// earn the same nothing, because the user's intent differs: one is a decision,
/// the other is the app going away underneath them.
enum SessionOutcome {
  /// Reached its planned duration. The only outcome that earns a plant.
  completed,

  /// The user deliberately abandoned it.
  cancelled,

  /// The app was force-quit while it ran. Nobody decided to end it.
  voided,
}

/// One stretch of intentional focus: what was planned, when it was anchored,
/// how much of it was spent paused, and — once it is over — how it ended.
///
/// Immutable, and the unit both the database and the garden work in. A session
/// is created when the user starts one and updated when it pauses, resumes and
/// ends; see `docs/adr/0002-sessions-are-recorded-when-they-start.md`.
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

  /// The anchor: the UTC instant the session began. Elapsed time is measured
  /// from here, never accumulated.
  final DateTime startedAt;

  /// How long the session was meant to run. Fixed for the life of the session.
  final Duration plannedDuration;

  /// How much of the session has been spent paused, over every pause that has
  /// finished. The pause currently open, if there is one, is not in here — it
  /// has no length yet.
  final Duration pausedDuration;

  /// When the pause currently open began, or null if the session is not paused.
  ///
  /// Stored rather than held in memory so a session restored after the app went
  /// away comes back paused if that is how the user left it.
  final DateTime? pausedSince;

  /// When the session ended, by any route — completed, cancelled or voided.
  /// Null while it runs.
  ///
  /// For a completed session this is the instant it *became* complete, not the
  /// instant the app noticed. A session that finishes while the phone is in a
  /// pocket ended when the timer ran out, not when the screen came back on.
  final DateTime? endedAt;

  /// How the session ended, or null while it is still in flight.
  final SessionOutcome? outcome;

  /// Whether the session reached its planned duration. The only outcome that
  /// earns a plant, and the flag every count of sessions has to filter on.
  bool get completed => outcome == SessionOutcome.completed;

  /// Whether a pause is currently open.
  bool get isPaused => pausedSince != null;

  /// Whether the session has stopped running, however it stopped.
  bool get hasEnded => outcome != null;

  /// This session, paused from [instant].
  ///
  /// Nothing is added to [pausedDuration] here: the pause has only just begun,
  /// and how long it lasts is not known until it ends.
  FocusSession pausedAt(DateTime instant) => FocusSession(
        id: id,
        startedAt: startedAt,
        plannedDuration: plannedDuration,
        pausedDuration: pausedDuration,
        pausedSince: instant,
        endedAt: endedAt,
        outcome: outcome,
      );

  /// This session, running again from [instant], with the pause it was in
  /// folded into [pausedDuration].
  FocusSession resumedAt(DateTime instant) => _withPauseClosedAt(instant);

  /// This session, ended in completion at [endedAt].
  FocusSession completedAt(DateTime instant) =>
      _endedAt(instant, SessionOutcome.completed);

  /// This session, abandoned by the user at [instant].
  FocusSession cancelledAt(DateTime instant) =>
      _endedAt(instant, SessionOutcome.cancelled);

  /// This session, ended at [instant] by the app going away rather than by
  /// anyone deciding to end it.
  FocusSession voidedAt(DateTime instant) =>
      _endedAt(instant, SessionOutcome.voided);

  /// Ends the session, closing any pause still open.
  FocusSession _endedAt(DateTime instant, SessionOutcome outcome) =>
      _withPauseClosedAt(instant, endedAt: instant, outcome: outcome);

  /// This session with no pause open, whatever it takes to get there: an open
  /// pause is folded into [pausedDuration] and the start of it forgotten.
  ///
  /// Both ways out of a pause come through here — resuming and ending — because
  /// both owe the same thing to [pausedDuration]: it has to be the whole of the
  /// time this session spent paused, which is what makes it worth recording.
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

  /// How long the open pause ran, if it were to end at [instant].
  ///
  /// Never negative. A device clock corrected backwards mid-pause would
  /// otherwise hand back time the user never spent paused, and every reading
  /// of elapsed time downstream is a subtraction of this.
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
