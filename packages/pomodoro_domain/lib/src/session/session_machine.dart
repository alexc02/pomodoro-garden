import '../garden/growth_stage.dart';
import '../garden/plant.dart';
import '../time/clock.dart';
import 'focus_session.dart';
import 'id_source.dart';
import 'rest_break.dart';

/// Where the timer is in the cycle.
///
/// One enum for sessions and breaks, because there is one timer: the ring, the
/// countdown, the ticker that repaints them and the alarm that announces the
/// end are the same machinery whichever of the two is running, and a second
/// phase field would be a second answer to "what is the timer doing".
enum SessionPhase {
  /// No session in flight.
  idle,

  /// A session is anchored, unpaused, and has not yet reached its planned
  /// duration.
  running,

  /// A session is in flight but its countdown is held. Its plant is still
  /// growing — see [SessionSnapshot.growthProgress].
  paused,

  /// The last session reached its planned duration. The break it earned is on
  /// offer.
  completed,

  /// A break is running. Nothing is growing: see [Break].
  onBreak,

  /// The break ran its course. A restful idle — there is nothing in flight, and
  /// the only thing left to do is start the next session.
  ///
  /// Told apart from [idle] because a break that *ended* is news, and a timer
  /// that has never run is not. It is this transition the end sound and the
  /// scheduled notice hang off, and a break skipped rather than finished goes
  /// to [idle] instead precisely so that it makes no sound.
  breakOver,
}

/// Thrown when a command does not belong to the phase the session is in —
/// starting a second session over a live one, resuming one that is not paused,
/// cancelling one that is not there.
///
/// A [StateError] rather than a checked exception because it reports a caller
/// bug, not a condition a correct caller has to handle: the UI only offers
/// PAUSE while a session runs and RESUME while one is held.
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

  /// How much of the planned duration has been consumed. Never exceeds it, and
  /// does not move while the session is paused.
  final Duration elapsed;

  /// Planned duration minus [elapsed]. What the countdown shows.
  final Duration remaining;

  /// [elapsed] as a fraction of the planned duration, 0 to 1. What the ring
  /// fills to.
  final double progress;

  /// How grown the plant is, as a fraction of the planned duration, 0 to 1.
  ///
  /// Not the same number as [progress], and REQ-009 is why: paused time buys
  /// growth at half rate, so a session that has been paused grows a plant that
  /// runs ahead of its own countdown. They are equal for a session that was
  /// never paused, which is every session until the user taps PAUSE.
  final double growthProgress;

  /// How long this session has spent paused, including the pause it is in —
  /// which is what makes it a reading rather than the record `FocusSession`
  /// keeps. A pause that has not ended has no length to record yet; it does
  /// have a length to *show*, and this is it.
  final Duration pausedSoFar;

  /// The instant this session reaches its planned duration — null only when no
  /// session has run yet.
  ///
  /// An absolute instant, and the one thing on a snapshot that something
  /// *outside* this app can act on: hand it to a scheduler and the completion
  /// is announced at the right moment with nothing of ours awake, hand it to a
  /// lock screen and the countdown runs there. Both are things this app does,
  /// and both are wrong if they compute it themselves — `now + remaining` at a
  /// caller is the same number a fraction of a millisecond later, which is a
  /// countdown that drifts and a surface that redraws for nothing.
  ///
  /// It stands still while the session runs and moves out while it is held, by
  /// exactly as long as the hold has lasted. That is the same sentence as "a
  /// session resumes where it was held and ends later by however long it was
  /// held for", said as an instant.
  final DateTime? dueAt;

  /// What this session is growing, and how grown it looks — null only when no
  /// session has run yet.
  ///
  /// Carried on the snapshot rather than asked for separately because it is
  /// part of what the timer *is* at this instant, and because deriving it
  /// anywhere else would mean handing the running session out to be re-read.
  /// It changes four times in a session, and compares by value, so watching it
  /// repaints the plant only when the plant actually changed.
  ///
  /// Null throughout a break, and that is the whole of "breaks do not grow
  /// plants" said where every reader of the timer will see it: the screen draws
  /// bare soil, the live surface declines to show anything, and no stage can
  /// change, because there is nothing there to change.
  final PlantGrowth? growing;

  /// Which kind of break is running, or has just run out — null whenever the
  /// timer is not on one.
  final BreakKind? breakKind;

  /// How many focus sessions have completed since the last long break began.
  ///
  /// Where the user is in the Pomodoro cycle, counted rather than named: it
  /// rises by one with every completed session, and drops to zero the moment a
  /// long break starts, which is the wrap back to session one. Compared against
  /// the "long break after" setting by [BreakOffer.at] and nowhere else, which
  /// is what keeps the rule in one place while the count lives here.
  final int cyclePosition;

  /// Snapshots compare by value: two readings of a session at the same instant
  /// describe the same state, and the UI should not repaint between them.
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

/// The timer's lifecycle: the one place that decides whether a session is
/// running, how far along it is, whether it is held, when it is over, and
/// whether what is counting down is a session or the break after one.
///
/// Time enters through [Clock] and nowhere else, and elapsed time is always
/// derived from the anchor rather than accumulated — see
/// `docs/adr/0001-elapsed-time-is-derived-from-a-wall-clock-anchor.md`. Pausing
/// does not break that: a pause is stored as the instants it spans, and elapsed
/// time is the gap to the anchor *less* the time spent paused, which is still a
/// subtraction of two readings rather than a counter anyone advances.
///
/// **A break runs on this same machinery and earns none of what a session
/// earns.** It is anchored and read from the clock the same way, so it survives
/// backgrounding and finishes on time whether or not anyone is watching — and
/// it grows no plant, records no row, and moves no count, because nothing here
/// hands one out. What it does move is [SessionSnapshot.cyclePosition], and
/// only by resetting it: the counting is done by completed sessions.
final class SessionMachine {
  /// Both collaborators are positional because the analyzer will not let a
  /// named parameter initialise a private field, and these two fields have no
  /// business being public.
  ///
  /// [cyclePosition] is where a previous launch left the cycle, so that a
  /// relaunch does not start it over.
  SessionMachine(this._clock, this._ids, {this._cyclePosition = 0});

  /// REQ-009: while a session is paused its plant keeps growing, at this
  /// fraction of the rate it grows at while the user is actually focusing. Half
  /// makes a pause cost something without making it a punishment.
  static const double pausedGrowthRate = 0.5;

  /// The only way time enters this class.
  final Clock _clock;

  final IdSource _ids;

  FocusSession? _session;

  Break? _break;

  int _cyclePosition;

  /// Starts a session of [plannedDuration], anchored to the current instant,
  /// and returns the record of it for the caller to store.
  ///
  /// A break in flight is ended by this, without ceremony: starting the next
  /// session *is* how a user cuts a break short, and a break that has already
  /// run out is over anyway.
  FocusSession start({required Duration plannedDuration}) {
    _requirePositive(plannedDuration);
    // Not merely "is a session running": a session whose time is up but whose
    // record has not been collected by [poll] is still in flight as far as this
    // machine is concerned. Starting over it would discard a session the user
    // sat through. Callers poll first, then start.
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

  /// Starts a break of [offer]'s kind and length, anchored to the current
  /// instant, and returns it.
  ///
  /// Nothing is returned for a caller to *store*, unlike every other command
  /// here, and that is the point: a break leaves no record. What comes back is
  /// the break itself, for a caller that wants to say how long it will be.
  ///
  /// A long break wraps the cycle back to session one as it begins rather than
  /// as it ends, so that a user who cuts one short is not offered the same long
  /// break again — they took it, and how long they chose to sit in it is theirs
  /// to decide.
  Break startBreak(BreakOffer offer, {DateTime? at}) {
    _requirePositive(offer.length);

    // A break may be anchored in the past — at the instant the session that
    // earned it ended, when that happened while nobody was watching — and
    // never in the future, which would be a break that has not begun counting
    // shown as if it had. See ADR 0022.
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

    // The session that earned this break is let go of here. Its record has
    // already been collected by [poll] and its plant already planted; what is
    // left is the completed phase the screen has been showing, and a break
    // replaces it.
    _session = null;
    return _break = Break(
      startedAt: at ?? now,
      plannedDuration: offer.length,
      kind: offer.kind,
    );
  }

  /// Ends the break — skipped before it started properly, or cut short — and
  /// returns the timer to idle.
  ///
  /// Idle rather than [SessionPhase.breakOver], because the two mean different
  /// things to everything downstream: a break that ran out is announced, and a
  /// break the user walked away from is not something to chime about.
  void endBreak() {
    if (_break == null) {
      throw SessionTransitionError(
        'Cannot end a break: the timer is ${snapshot.phase.name}.',
      );
    }

    _break = null;
  }

  /// Puts [session] back in flight — the session found unfinished in storage
  /// when the app was launched.
  ///
  /// Nothing about the session is recomputed on the way in. It comes back with
  /// the anchor, the paused time and the open pause it was written down with,
  /// and the next reading of [snapshot] works out where it should be from the
  /// clock, exactly as it would have if the app had never gone away. That is
  /// what makes a cold start indistinguishable from a stalled frame.
  ///
  /// Returns the restored session, so a caller can hand it straight on.
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

  /// Puts the cycle back at session one — a garden that has been reset has
  /// no completed sessions left to count towards a long break.
  void resetCycle() => _cyclePosition = 0;

  /// Holds the countdown from the current instant, and returns the session to
  /// be recorded.
  ///
  /// The plant does not stop: see [SessionSnapshot.growthProgress].
  FocusSession pause() {
    final session = _inFlight('pause');
    if (session.isPaused) {
      throw SessionTransitionError('${session.id} is already paused.');
    }

    return _session = session.pausedAt(_clock.now());
  }

  /// Starts the countdown again from where it was held, and returns the session
  /// to be recorded, with the pause that just ended folded into its paused
  /// duration.
  FocusSession resume() {
    final session = _inFlight('resume');
    if (!session.isPaused) {
      throw SessionTransitionError('${session.id} is not paused.');
    }

    return _session = session.resumedAt(_clock.now());
  }

  /// Abandons the session the user decided to abandon, and returns its record
  /// for the caller to store.
  ///
  /// The machine goes back to idle rather than holding the cancelled session
  /// the way it holds a completed one: a completed session stays on screen
  /// because its plant is the reward, and a cancelled one has no reward to
  /// show.
  FocusSession cancel() {
    final cancelled = _inFlight('cancel').cancelledAt(_clock.now());
    _session = null;
    return cancelled;
  }

  /// Ends whatever is in flight because the app is going away, and returns its
  /// record — or null if there was nothing in flight to void.
  ///
  /// Null rather than a throw, unlike every other command here, because this
  /// one is not a user's decision: it arrives from the platform whether or not
  /// a session happens to be running, and "there was nothing to void" is an
  /// ordinary answer rather than a caller bug.
  ///
  /// A session whose time is already up is left alone — it earned its plant
  /// before the app went away, and voiding it would take that back. The caller
  /// polls first, then voids.
  FocusSession? voidInFlight() {
    // A break in flight goes away with the app and leaves nothing behind —
    // there was never a record of it to close. Dropped rather than left
    // standing so that nothing downstream is still counting down to a break
    // whose app has detached.
    _break = null;

    final session = _session;
    if (session == null) return null;

    final now = _clock.now();
    if (_phaseOf(session, now) == SessionPhase.completed) return null;

    _session = null;
    return session.voidedAt(now);
  }

  /// Applies any completion that has fallen due, and returns the session that
  /// just completed — once, for the caller to record — or null.
  ///
  /// This is how completion is *noticed*. Nothing inside the machine fires at
  /// the end of a session; the clock simply passes the end, and the next poll
  /// sees it. Polling more often than once a second, or not for an hour, both
  /// give the same answer.
  FocusSession? poll() {
    final session = _session;
    if (session == null || session.completed) return null;
    // [_phaseOf] rather than `snapshot.phase`: this runs on every tick of every
    // session, and building a whole snapshot — species choice and all — to
    // answer one question about the clock is work nobody asked for.
    if (_phaseOf(session, _clock.now()) != SessionPhase.completed) return null;

    // The one place the cycle advances, and it advances on completion rather
    // than on starting the next session: what earns a long break is sessions
    // finished, not sessions begun. Cancelled and voided sessions never reach
    // here, which is why neither moves the cycle.
    _cyclePosition++;

    // The instant it became complete, not the instant anyone looked: the anchor
    // plus the planned duration, pushed out by every minute the session spent
    // paused. A session paused for five minutes ends five minutes later than
    // one that was not, which is exactly what "no time lost or gained" means.
    return _session = session
        .completedAt(session.startedAt.add(
          session.plannedDuration + session.pausedDuration,
        ));
  }

  /// The state of the timer now.
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

    // Clamped at both ends. The upper clamp keeps a session that ran long from
    // reporting more than it planned; the lower one keeps a backwards clock
    // correction from reporting negative time. See ADR 0001.
    final elapsed = switch (_focusedBy(session, now)) {
      _ when phase == SessionPhase.completed => planned,
      final net when net.isNegative => Duration.zero,
      final net => net,
    };

    // REQ-009's half-rate growth, and the only place the plant parts company
    // with the countdown. Clamped at the top for the same reason elapsed is:
    // a session paused for long enough grows its plant as far as it can go
    // before its own countdown runs out. REQ-016 keeps the last stage for the
    // completion itself, so an unfinished plant stops at maturing.
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
      // The anchor plus the planned duration, pushed out by every minute this
      // session has spent paused — which is the same instant [poll] records a
      // completion at, computed the same way. Deliberately not `now +
      // remaining`: that is the same number, arrived at by adding a reading of
      // the clock to a subtraction from it, so it slides by however long the
      // caller took to ask.
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

  /// The state of the timer while it is counting down a break.
  ///
  /// The same arithmetic as a session's, minus everything a session has that a
  /// break does not: no pause to subtract, because a break cannot be held; no
  /// growth, because a break grows nothing; and no plant to name. What is left
  /// is a countdown to an anchor plus a duration, which is exactly what makes a
  /// break come back correct from an hour in the background.
  SessionSnapshot _breakSnapshot(Break rest) {
    final planned = rest.plannedDuration;
    // Clamped at both ends, for the two reasons a session's is: a break nobody
    // looked at for an hour has still only spent its planned duration, and a
    // clock corrected backwards must not report negative time. See ADR 0001.
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

  /// How much of [session] has actually been focused as of [now]: the gap to
  /// the anchor, less every minute spent paused.
  ///
  /// While a pause is open this does not read [now] at all — the countdown
  /// stopped at the instant the pause began, and it is still standing there.
  /// That is what makes a device clock corrected in either direction during a
  /// pause unable to move the countdown by so much as a second.
  Duration _focusedBy(FocusSession session, DateTime now) =>
      (session.pausedSince ?? now).difference(session.startedAt) -
      session.pausedDuration;

  /// How long [session] has spent paused as of [now], including the pause it is
  /// in.
  Duration _pausedBy(FocusSession session, DateTime now) {
    final open = session.pausedSince;
    if (open == null) return session.pausedDuration;

    // Never negative: a clock corrected backwards mid-pause must not hand back
    // time the user never spent paused. See ADR 0001.
    final soFar = now.difference(open);
    return session.pausedDuration + (soFar.isNegative ? Duration.zero : soFar);
  }

  SessionPhase _phaseOf(FocusSession session, DateTime now) {
    // Once a session has completed it stays completed. Its record says so, and
    // the clock does not get to argue: a correction that moves time backwards
    // would otherwise put a finished session back on the ring to be counted
    // down — and lived through — a second time.
    if (session.completed) return SessionPhase.completed;

    if (_focusedBy(session, now) >= session.plannedDuration) {
      return SessionPhase.completed;
    }

    return session.isPaused ? SessionPhase.paused : SessionPhase.running;
  }

  /// The session a pause, resume or cancel applies to.
  ///
  /// Deliberately reads the phase rather than the record: a session whose time
  /// is up but whose completion nobody has collected yet is not something the
  /// user gets to pause. Callers poll first, then command — the same order
  /// [start] asks for. A break is not a session, so none of the three reaches
  /// one; a break is ended with [endBreak].
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
