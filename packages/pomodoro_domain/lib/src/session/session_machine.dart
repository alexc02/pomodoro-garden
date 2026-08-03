import '../garden/growth_stage.dart';
import '../garden/plant.dart';
import '../time/clock.dart';
import 'focus_session.dart';
import 'id_source.dart';
import 'rest_break.dart';

/// Timer phase. Sessions and breaks share one timer, so one enum.
enum SessionPhase {
  /// No session in flight.
  idle,

  /// Unpaused and not yet at its planned duration.
  running,

  /// Countdown held. The plant still grows (see
  /// [SessionSnapshot.growthProgress]).
  paused,

  /// Reached its planned duration; a break is on offer.
  completed,

  /// Break running. Nothing grows.
  onBreak,

  /// The break ran out. Separate from [idle] because this is what triggers the
  /// end sound and notification; a skipped break goes to [idle] and stays
  /// quiet.
  breakOver,
}

/// A command that doesn't fit the current phase (start over a live session,
/// resume when not paused, etc). Always a caller bug.
final class SessionTransitionError extends StateError {
  SessionTransitionError(super.message);
}

/// The state of the timer at one instant.
final class SessionSnapshot {
  const SessionSnapshot({
    required this.phase,
    required this.elapsed,
    required this.remaining,
    required this.progress,
    required this.growthProgress,
    this.pausedSoFar = Duration.zero,
    this.dueAt,
    this.growing,
    this.breakKind,
    this.cyclePosition = 0,
  });

  final SessionPhase phase;

  /// Capped at the planned duration. Frozen while paused.
  final Duration elapsed;

  /// What the countdown shows.
  final Duration remaining;

  /// 0 to 1. What the ring fills to.
  final double progress;

  /// 0 to 1. Ahead of [progress] once the session has been paused, since
  /// paused time grows the plant at half rate.
  final double growthProgress;

  /// Includes the current open pause, unlike `FocusSession.pausedDuration`.
  final Duration pausedSoFar;

  /// When the session will finish. Null only before any session has run.
  ///
  /// Use this for notifications and the lock screen instead of computing
  /// `now + remaining`, which drifts. Moves later while paused.
  final DateTime? dueAt;

  /// Null before any session and during breaks (breaks don't grow plants).
  /// Value-equal, so it only changes four times per session.
  final PlantGrowth? growing;

  /// Null unless on a break or just finished one.
  final BreakKind? breakKind;

  /// Completed sessions since the last long break started. Compared against
  /// the setting in [BreakOffer.at].
  final int cyclePosition;

  @override
  bool operator ==(Object other) =>
      other is SessionSnapshot &&
      other.phase == phase &&
      other.elapsed == elapsed &&
      other.remaining == remaining &&
      other.progress == progress &&
      other.growthProgress == growthProgress &&
      other.pausedSoFar == pausedSoFar &&
      other.dueAt == dueAt &&
      other.growing == growing &&
      other.breakKind == breakKind &&
      other.cyclePosition == cyclePosition;

  @override
  int get hashCode => Object.hash(
        phase,
        elapsed,
        remaining,
        progress,
        growthProgress,
        pausedSoFar,
        dueAt,
        growing,
        breakKind,
        cyclePosition,
      );

  @override
  String toString() => 'SessionSnapshot(${phase.name}, $remaining remaining)';
}

/// The timer state machine: sessions, pauses, completion and breaks.
///
/// Time only comes in through [Clock]; elapsed is derived from the anchor,
/// never accumulated (ADR 0001). Paused time is subtracted from the gap.
/// Breaks use the same anchoring but grow nothing and record nothing; they
/// only reset [SessionSnapshot.cyclePosition].
final class SessionMachine {
  /// Positional because named params can't initialise private fields.
  /// [_cyclePosition] restores the cycle from a previous launch.
  SessionMachine(this._clock, this._ids, {this._cyclePosition = 0});

  /// Growth rate while paused, relative to focusing.
  static const double pausedGrowthRate = 0.5;

  final Clock _clock;

  final IdSource _ids;

  FocusSession? _session;

  Break? _break;

  int _cyclePosition;

  /// Starts a session now and returns it for storing. Ends any running break.
  FocusSession start({required Duration plannedDuration}) {
    _requirePositive(plannedDuration);
    // A completed session that [poll] hasn't collected yet still counts as in
    // flight. Callers poll first, then start.
    final inFlight = _session;
    if (inFlight != null && !inFlight.completed) {
      throw SessionTransitionError(
        'Cannot start a session while ${inFlight.id} is in flight. '
        'Poll for its completion first.',
      );
    }

    _break = null;
    return _session = FocusSession(
      id: _ids.newId(),
      startedAt: _clock.now(),
      plannedDuration: plannedDuration,
    );
  }

  /// Starts a break and returns it. Nothing to store.
  ///
  /// A long break resets the cycle when it starts, not when it ends, so cutting
  /// it short doesn't get you offered it again.
  Break startBreak(BreakOffer offer, {DateTime? at}) {
    _requirePositive(offer.length);

    // [at] can be in the past (the session ended while backgrounded) but not
    // the future.
    final now = _clock.now();
    if (at != null && at.isAfter(now)) {
      throw ArgumentError.value(at, 'at', 'is later than now ($now)');
    }

    final inFlight = _session;
    if (inFlight != null && !inFlight.completed) {
      throw SessionTransitionError(
        'Cannot start a break while ${inFlight.id} is in flight. Poll for its '
        'completion first.',
      );
    }
    if (_break != null) {
      throw SessionTransitionError('A break is already running.');
    }

    if (offer.kind == BreakKind.long) _cyclePosition = 0;

    // Drop the completed session; it's already been saved and planted.
    _session = null;
    return _break = Break(
      startedAt: at ?? now,
      plannedDuration: offer.length,
      kind: offer.kind,
    );
  }

  /// Skips or cuts short the break. Goes to idle, not
  /// [SessionPhase.breakOver], so there's no end sound.
  void endBreak() {
    if (_break == null) {
      throw SessionTransitionError(
        'Cannot end a break: the timer is ${snapshot.phase.name}.',
      );
    }

    _break = null;
  }

  /// Puts an unfinished session from storage back in flight on launch.
  /// Nothing is recomputed; [snapshot] works it out from the clock.
  FocusSession restore(FocusSession session) {
    if (_session != null) {
      throw SessionTransitionError(
        'Cannot restore ${session.id} over ${_session!.id}. A machine restores '
        'at most one session, at launch, before anything else touches it.',
      );
    }
    if (session.hasEnded) {
      throw ArgumentError.value(
        session,
        'session',
        'has already ended, and an ended session does not go back in flight',
      );
    }
    _requirePositive(session.plannedDuration);

    return _session = session;
  }

  /// Used after a garden reset.
  void resetCycle() => _cyclePosition = 0;

  /// Returns the session for storing. The plant keeps growing.
  FocusSession pause() {
    final session = _inFlight('pause');
    if (session.isPaused) {
      throw SessionTransitionError('${session.id} is already paused.');
    }

    return _session = session.pausedAt(_clock.now());
  }

  /// Returns the session for storing.
  FocusSession resume() {
    final session = _inFlight('resume');
    if (!session.isPaused) {
      throw SessionTransitionError('${session.id} is not paused.');
    }

    return _session = session.resumedAt(_clock.now());
  }

  /// Returns the cancelled session for storing. Goes straight to idle
  /// (unlike completed, there's nothing to show).
  FocusSession cancel() {
    final cancelled = _inFlight('cancel').cancelledAt(_clock.now());
    _session = null;
    return cancelled;
  }

  /// Called when the app is going away. Returns the voided session, or null if
  /// nothing was running. Doesn't throw. A session that already hit its time is
  /// left alone so it keeps its plant; callers poll first.
  FocusSession? voidInFlight() {
    // Breaks have no record, just drop it.
    _break = null;

    final session = _session;
    if (session == null) return null;

    final now = _clock.now();
    if (_phaseOf(session, now) == SessionPhase.completed) return null;

    _session = null;
    return session.voidedAt(now);
  }

  /// Returns the session that just completed (once), or null. Completion is
  /// only noticed here; nothing fires on its own, so poll rate doesn't matter.
  FocusSession? poll() {
    final session = _session;
    if (session == null || session.completed) return null;
    // [_phaseOf] avoids building a full snapshot on every tick.
    if (_phaseOf(session, _clock.now()) != SessionPhase.completed) return null;

    // Cycle only advances on completion. Cancelled/voided don't count.
    _cyclePosition++;

    // Completion time is anchor + planned + paused, not when we noticed.
    return _session = session
        .completedAt(session.startedAt.add(
          session.plannedDuration + session.pausedDuration,
        ));
  }

  SessionSnapshot get snapshot {
    final rest = _break;
    if (rest != null) return _breakSnapshot(rest);

    final session = _session;
    if (session == null) {
      return SessionSnapshot(
        phase: SessionPhase.idle,
        elapsed: Duration.zero,
        remaining: Duration.zero,
        progress: 0,
        growthProgress: 0,
        cyclePosition: _cyclePosition,
      );
    }

    final now = _clock.now();
    final planned = session.plannedDuration;
    final paused = _pausedBy(session, now);
    final phase = _phaseOf(session, now);

    // Clamp both ends: ran long, or clock went backwards (ADR 0001).
    final elapsed = switch (_focusedBy(session, now)) {
      _ when phase == SessionPhase.completed => planned,
      final net when net.isNegative => Duration.zero,
      final net => net,
    };

    // Paused time counts at half rate. Unfinished plants stop at maturing;
    // mature is reserved for completion.
    final growth = elapsed + paused * SessionMachine.pausedGrowthRate;
    final growthProgress =
        (growth.inMicroseconds / planned.inMicroseconds).clamp(0.0, 1.0);

    return SessionSnapshot(
      phase: phase,
      elapsed: elapsed,
      remaining: planned - elapsed,
      progress: elapsed.inMicroseconds / planned.inMicroseconds,
      growthProgress: growthProgress,
      pausedSoFar: paused,
      // Same formula as [poll]. Not `now + remaining`, which drifts.
      dueAt: session.startedAt.add(planned + paused),
      growing: PlantGrowth.forSession(
        session,
        progress: phase == SessionPhase.completed
            ? growthProgress
            : growthProgress.clamp(0.0, GrowthStage.maturing.threshold).toDouble(),
      ),
      cyclePosition: _cyclePosition,
    );
  }

  /// Like a session snapshot minus pauses, growth and plant.
  SessionSnapshot _breakSnapshot(Break rest) {
    final planned = rest.plannedDuration;
    // Clamp both ends, same as sessions (ADR 0001).
    final ran = _clock.now().difference(rest.startedAt);
    final elapsed = switch (ran) {
      _ when ran >= planned => planned,
      _ when ran.isNegative => Duration.zero,
      _ => ran,
    };

    return SessionSnapshot(
      phase: elapsed >= planned ? SessionPhase.breakOver : SessionPhase.onBreak,
      elapsed: elapsed,
      remaining: planned - elapsed,
      progress: elapsed.inMicroseconds / planned.inMicroseconds,
      growthProgress: 0,
      dueAt: rest.dueAt,
      breakKind: rest.kind,
      cyclePosition: _cyclePosition,
    );
  }

  /// Focused time: gap to the anchor minus paused time. While paused it
  /// ignores [now], so clock changes during a pause can't move the countdown.
  Duration _focusedBy(FocusSession session, DateTime now) =>
      (session.pausedSince ?? now).difference(session.startedAt) -
      session.pausedDuration;

  /// Includes the open pause.
  Duration _pausedBy(FocusSession session, DateTime now) {
    final open = session.pausedSince;
    if (open == null) return session.pausedDuration;

    // Clamp in case the clock went backwards (ADR 0001).
    final soFar = now.difference(open);
    return session.pausedDuration + (soFar.isNegative ? Duration.zero : soFar);
  }

  SessionPhase _phaseOf(FocusSession session, DateTime now) {
    // Completed is final. Otherwise a backwards clock correction could restart
    // a finished session.
    if (session.completed) return SessionPhase.completed;

    if (_focusedBy(session, now) >= session.plannedDuration) {
      return SessionPhase.completed;
    }

    return session.isPaused ? SessionPhase.paused : SessionPhase.running;
  }

  /// Checks the phase, not the record: an uncollected completion can't be
  /// paused or cancelled. Breaks are ended with [endBreak] instead.
  FocusSession _inFlight(String command) {
    final session = _session;
    final phase = snapshot.phase;

    if (session == null ||
        (phase != SessionPhase.running && phase != SessionPhase.paused)) {
      throw SessionTransitionError(
        'Cannot $command: no session is in flight. The timer is ${phase.name}.',
      );
    }
    return session;
  }

  void _requirePositive(Duration plannedDuration) {
    if (plannedDuration <= Duration.zero) {
      throw ArgumentError.value(
        plannedDuration,
        'plannedDuration',
        'must be positive',
      );
    }
  }
}
