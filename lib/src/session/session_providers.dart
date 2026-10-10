import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../analytics/analytics_providers.dart';
import '../data/database_providers.dart';
import '../garden/decor_providers.dart';
import '../garden/plant_providers.dart';
import '../journal/journal_providers.dart';
import '../settings/settings_providers.dart';
import '../time/clock_provider.dart';

/// The source of session ids. Overridden in tests with one that counts.
final idSourceProvider = Provider<IdSource>((ref) => RandomIdSource());

/// Every session the user has completed, most recent first.
///
/// Invalidated by [SessionController] when a session completes, so anything
/// watching a count of sessions refreshes on its own.
final completedSessionsProvider = FutureProvider<List<FocusSession>>(
  (ref) => ref.watch(sessionRepositoryProvider).completedSessions(),
);

/// The session that was still running when the app was last here, read once at
/// launch.
///
/// A row with no outcome is a session nothing ever ended — the app was killed
/// while it ran, by the system or by running out of memory — and the wall clock
/// says where it should be now. Force-quitting is the case this does *not*
/// catch, because [SessionLifecycle] closes the row before the process goes;
/// see `docs/adr/0005-a-session-outlives-the-app-unless-the-user-quit-it.md`.
///
/// Errors are swallowed rather than surfaced, on the same reasoning
/// `SettingsController` swallows its own: a launch that cannot read its last
/// session is better spent letting the user start a new one than refusing to
/// open.
final restoredSessionProvider = FutureProvider<FocusSession?>((ref) async {
  try {
    return await ref.watch(sessionRepositoryProvider).inFlightSession();
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'pomodoro_garden',
      context: ErrorDescription('restoring the session in flight'),
    ));
    return null;
  }
});

/// The live timer.
final sessionControllerProvider =
    NotifierProvider<SessionController, SessionSnapshot>(SessionController.new);

/// The break the user would get if they took one now: a short one, or the long
/// one their cycle has earned.
///
/// What the screen offering the break watches, so that the offer follows both
/// the cycle and a setting changed while the offer is on screen.
/// [SessionController.startBreak] asks [BreakOffer.at] directly rather than
/// reading this — a provider that watches the controller cannot be read from
/// inside it — and the two cannot disagree, because the rule is in neither of
/// them.
final breakOnOfferProvider = Provider<BreakOffer>(
  (ref) => BreakOffer.at(
    ref.watch(sessionControllerProvider).cyclePosition,
    settings: ref.watch(settingsProvider),
  ),
);

/// Drives the session state machine and keeps storage in step with it.
///
/// The division of labour: the machine decides what is true, this controller
/// decides when to look and what to write down. It holds the only timer in the
/// app, and that timer exists solely to repaint — the countdown it drives is
/// read from the clock every time, never counted.
class SessionController extends Notifier<SessionSnapshot> {
  SessionMachine? _cachedMachine;
  Timer? _ticker;

  /// The phase the last [_publish] put on screen, or null if nothing has been
  /// published yet.
  ///
  /// Kept for one reason: auto-start reacts to something *ending*, and a phase
  /// is not an ending. Without this, a user sitting in `completed` who turns
  /// auto-start on and then backgrounds the app would come back to a break they
  /// never asked to begin — the resume calls [catchUp], and a rule written
  /// against the phase alone cannot tell that tick apart from the one that
  /// noticed the session finish.
  ///
  /// Null rather than the phase [build] returned, deliberately: a launch that
  /// restores a session which already ran out has published nothing, and the
  /// break it earned is as due as one earned a second ago.
  SessionPhase? _published;

  /// How many times the session in flight has been held: §7.1's `pause_count`,
  /// and the `paused_count` its completion reports.
  ///
  /// Held here rather than on the session, and that is a trade worth naming: a
  /// session restored after the app was killed comes back with this at zero,
  /// because nothing wrote it down. The alternative was a column on `sessions`
  /// for a number nothing but an analytics event reads — a migration, a mapping
  /// and a field on the domain's `FocusSession`, so that a log line is right
  /// about a case a log line does not decide anything on.
  int _pauses = 0;

  @override
  SessionSnapshot build() {
    // Read, not watched. The machine holds the running session, so rebuilding
    // it would drop a session mid-flight — and neither the clock nor the id
    // source is a value that changes under a running app. Overrides are in
    // place before this first runs, so a test still gets the clock it supplied.
    var machine = _cachedMachine;
    if (machine == null) {
      machine = _cachedMachine = SessionMachine(
        ref.read(clockProvider),
        ref.read(idSourceProvider),
      );
      _restore(machine);
    }

    ref.onDispose(_stopTicking);
    // A rebuild disposes the ticker along with everything else. If a session is
    // still in flight, it needs a new one, or the countdown freezes while the
    // session underneath it carries on.
    _scheduleTick();

    return machine.snapshot;
  }

  SessionMachine get _machine => _cachedMachine!;

  /// Where this controller says what happened — §7.1's session events.
  ///
  /// Read on each use rather than held: recording is one call that returns
  /// immediately and never throws, so there is nothing here to keep alive and
  /// nothing to handle. See `analytics_providers.dart`.
  Analytics get _analytics => ref.read(analyticsProvider);

  /// Puts back the session the app was killed in the middle of, if there was
  /// one.
  ///
  /// Only ever runs on the first build of a fresh machine — a rebuild keeps the
  /// machine it had, and restoring into it would be restoring over a live
  /// session.
  void _restore(SessionMachine machine) {
    final stored = ref.read(restoredSessionProvider);
    if (!stored.hasValue) {
      throw StateError(
        'The session in flight was read before it finished loading. Anything '
        'that reads sessionControllerProvider must be below SessionGate, which '
        'is what guarantees there is an answer here to read.',
      );
    }

    final restored = stored.requireValue;
    if (restored == null) return;

    machine.restore(restored);
    // The restored session may already be over — its timer ran out while the
    // app was not there to notice. Nothing fires at the end of a session, so
    // somebody has to look; the ticker will not, because a session that is
    // already finished schedules no ticks. This is that look, off the end of
    // the build that restored it.
    scheduleMicrotask(_tick);
  }

  /// Starts a session of the user's current session length and records it as
  /// running.
  Future<void> start() async {
    // Before anything else: a session that finished between the last tick and
    // this tap still has to be written down. The machine refuses to start over
    // an unrecorded session, and it is right to.
    await _recordAnyCompletion();

    // Read here, at the tap, and never again for this session. That one line is
    // what makes a change to the setting apply to the *next* session: the
    // machine is handed a planned duration, the session keeps it for its whole
    // life, and nothing consults the setting again until the next START.
    final session = _machine.start(
      plannedDuration: ref.read(settingsProvider).sessionLength,
    );
    _pauses = 0;
    _publish();

    _analytics.record(SessionStarted.of(session.plannedDuration));
    await _save(session);
  }

  /// Starts the break the cycle says is due — the short one, or the long one
  /// after every `longBreakAfter` sessions.
  ///
  /// Nothing is written down. A break earns no plant and moves no count, so
  /// there is no row to open and none to close; the whole of a break lives on
  /// the machine that is running it, which is also why the app being killed
  /// during one costs the user nothing.
  ///
  /// [from] anchors the break at an earlier instant rather than now: what
  /// REQ-032's auto-start does with the break a session earned while the app
  /// was away (ADR 0022). A break the user asks for starts when they ask.
  Future<void> startBreak({DateTime? from}) async {
    // The same first line [start] has, for the same reason: a session that
    // finished between the last tick and this tap still has to be written down
    // and planted before anything replaces it.
    await _recordAnyCompletion();
    // Nothing may be in flight under it: not a session, and not another break.
    // The offer is read *after* the completion above has been collected,
    // because collecting it is what moves the cycle on — a break asked for
    // before that would be the break the previous session earned.
    if (!_atRest.contains(_machine.snapshot.phase)) {
      _publish();
      return;
    }

    _machine.startBreak(
      BreakOffer.at(
        _machine.snapshot.cyclePosition,
        settings: ref.read(settingsProvider),
      ),
      at: from,
    );
    _publish();
  }

  /// Ends the break the user is on, skipped or cut short, and goes back to
  /// idle.
  Future<void> skipBreak() async {
    await _recordAnyCompletion();
    // A break that ran out while the user was reaching for SKIP is already
    // over, and ending it here would swallow the [SessionPhase.breakOver] the
    // end sound hangs off. The same race [_command] guards against.
    if (_machine.snapshot.phase != SessionPhase.onBreak) {
      _publish();
      return;
    }

    _machine.endBreak();
    _publish();
  }

  /// Holds the countdown. The plant carries on at half speed — REQ-009.
  Future<void> pause() async {
    final held = await _command(_running, _machine.pause);
    // Null when the guard refused — a session that finished between the frame
    // that drew PAUSE and the tap on it was never held, and must not be
    // recorded as though it had been.
    if (held == null) return;

    _pauses++;
    _analytics.record(SessionPaused(
      duration: held.plannedDuration,
      pauseCount: _pauses,
    ));
  }

  /// Starts the countdown again from where it was held.
  Future<void> resume() => _command(_held, _machine.resume);

  /// Abandons the session, and everything it was growing.
  ///
  /// The confirmation is the screen's business, not this class's: by the time
  /// anything gets here the user has said yes twice.
  Future<void> cancel() async {
    // Read before the command rather than after it: cancelling returns the
    // machine to idle, and by the time there is a cancelled session to report
    // there is no longer anything to ask how far it got. Safe to read this
    // early because the only way the command does not go through is the session
    // having completed, in which case none of this is recorded at all.
    final abandoning = _machine.snapshot;

    final cancelled = await _command(_inFlight, _machine.cancel);
    if (cancelled == null) return;

    _analytics.record(SessionAbandoned(
      duration: cancelled.plannedDuration,
      elapsedBeforeAbandon: abandoning.elapsed,
    ));
  }

  /// Ends whatever is in flight because the app is going away for good.
  ///
  /// REQ-013: a force-quit is not an interruption the session survives. What
  /// makes this different from [cancel] is only the record it leaves — voided
  /// rather than cancelled — because the user made no decision here.
  ///
  /// Best-effort, and knowingly so: this runs while the process is being torn
  /// down, and the write may not land. If it does not, the row stays open and
  /// the next launch restores the session instead. See ADR 0005.
  Future<void> voidInFlight() async {
    await _recordAnyCompletion();

    final voided = _machine.voidInFlight();
    _publish();
    if (voided != null) await _save(voided);
  }

  /// Re-reads the clock and catches the timer up with it.
  ///
  /// What the app does on coming back from the background. Nothing here
  /// *changes* the session — the wall clock has always known where it is — but
  /// the ticker that repaints it has been asleep, and the first frame the user
  /// sees on returning should be right rather than one tick stale.
  Future<void> catchUp() => _tick();

  static const Set<SessionPhase> _running = {SessionPhase.running};
  static const Set<SessionPhase> _held = {SessionPhase.paused};
  static const Set<SessionPhase> _inFlight = {
    SessionPhase.running,
    SessionPhase.paused,
  };

  /// The phases with nothing counting down: where a break may be started.
  static const Set<SessionPhase> _atRest = {
    SessionPhase.idle,
    SessionPhase.completed,
    SessionPhase.breakOver,
  };

  /// Runs [transition] if the timer is in one of [from], records what it
  /// returns, and hands it back — or null if the phase check refused it.
  ///
  /// The phase check is not belt and braces over the machine's own: the machine
  /// throws, correctly, because a UI that offers RESUME on a running session is
  /// broken — but a session can finish between the frame that drew the button
  /// and the tap that hits it, and that race is not a bug for the user to see.
  ///
  /// Null is what tells a caller the difference, and the reason this returns
  /// anything at all: an event about a pause that did not happen is worse than
  /// no event.
  Future<FocusSession?> _command(
    Set<SessionPhase> from,
    FocusSession Function() transition,
  ) async {
    await _recordAnyCompletion();
    if (!from.contains(_machine.snapshot.phase)) {
      _publish();
      return null;
    }

    final session = transition();
    _publish();
    await _save(session);
    return session;
  }

  Future<void> _tick() async {
    final shown = _published;

    await _recordAnyCompletion();
    _publish();

    // Only when this tick *changed* something. A tick that found the timer
    // where it left it has noticed no ending, and REQ-032 is about what happens
    // when a session or a break ends — not about what the timer is sitting in.
    if (_machine.snapshot.phase != shown) await _autoStart();
  }

  /// Starts the next leg of the cycle, if the user has asked for it to start
  /// itself. REQ-032.
  ///
  /// Both halves are off by default and each is read fresh, so the cycle runs
  /// unattended only for as long as the user leaves it switched on.
  ///
  /// **A break is anchored where the session ended; a session is anchored to
  /// now.** Nothing of this app runs while it is away — REQ-005 — so whatever
  /// happened in a pocket is found on the way back in. A break earns nothing,
  /// so it is replayed from the instant its session ended, and its end was
  /// announced on time by the notification scheduled on the way out. A *focus*
  /// session is never replayed: anchoring one in the past would hand out a
  /// plant for time spent in a pocket. See
  /// `docs/adr/0022-a-break-replays-and-a-session-never-does.md`, which amends
  /// `0008-the-cycle-advances-when-the-app-is-awake-to-advance-it.md`.
  ///
  /// A break the user skipped lands in [SessionPhase.idle] rather than
  /// [SessionPhase.breakOver], so nothing here starts a session over it: walking
  /// out of a break is the user taking the cycle back, and the app should let
  /// them have it.
  Future<void> _autoStart() async {
    final settings = ref.read(settingsProvider);

    final snapshot = _machine.snapshot;
    switch (snapshot.phase) {
      // The break replays from the instant the session ended, not from the
      // instant the app noticed: a break earns nothing, so anchoring it in the
      // past hands out nothing for time nobody watched. ADR 0022.
      case SessionPhase.completed when settings.autoStartBreak:
        await startBreak(from: snapshot.dueAt);
        // A break that ran its whole course while the app was away is over the
        // moment it starts, and that ending has been noticed now: the next
        // session may follow it, anchored to now as 0008 requires.
        if (_machine.snapshot.phase == SessionPhase.breakOver) {
          await _autoStart();
        }
      case SessionPhase.breakOver when settings.autoStartNextSession:
        await start();
      case _:
        return;
    }
  }

  Future<void> _recordAnyCompletion() async {
    final completed = _machine.poll();
    if (completed == null) return;

    _analytics.record(SessionCompleted(
      duration: completed.plannedDuration,
      pausedCount: _pauses,
    ));

    await _save(completed);
    await _sow(completed);
    ref.invalidate(completedSessionsProvider);
    // The journal counts the sessions table by query rather than watching the
    // list above, so it has to be told the table moved. Invalidating the family
    // rather than one of its parameterisations: the locale decides which week
    // was read, and every week that was read is now out of date.
    ref.invalidate(journalProvider);
    ref.invalidate(journalMonthProvider);
  }

  /// Hands the machine's state to the screen and re-aims the ticker at it.
  ///
  /// Every command ends here, because every command can change which of those
  /// two the timer needs: pausing keeps the ticker but stops the countdown,
  /// cancelling ends both.
  void _publish() {
    state = _machine.snapshot;
    _published = state.phase;
    _scheduleTick();
  }

  /// Plants what [session] grew, in the nearest plot the garden has free.
  ///
  /// The plant is created here, at the moment of completion, rather than
  /// derived on the way out of the database: what the user watched grow for
  /// twenty-five minutes is written down, so a later change to the growth rules
  /// cannot reach back and turn their sunflower into a tulip. The plot is
  /// chosen the same way and for the same reason — a garden that re-laid itself
  /// on every read would be a different garden every launch.
  ///
  /// **REQ-040's decor is read here and can be written**, which is the one
  /// place in the app where finishing a session touches somebody's
  /// arrangement. [GardenPlots.sow] decides: ordinarily an object is stepped
  /// over and nothing about the arrangement changes, and only in a garden whose
  /// two hundred plots are every one of them spoken for does an object give way
  /// — see `docs/adr/0017-decor-never-costs-a-plant-its-plot.md`.
  Future<void> _sow(FocusSession session) async {
    final garden = ref.read(plantRepositoryProvider);
    final decor = ref.read(decorRepositoryProvider);

    await _write('planting for session ${session.id}', () async {
      // One session, one plant. A completion can be noticed more than once —
      // by the ticker and by the tap that starts the next session — and the
      // second one must not double the garden.
      if (await garden.plantForSession(session.id) != null) return;

      // Null when the garden is full *of plants*: the plant is still recorded,
      // and the garden says how many it is holding without a plot for. See
      // `docs/adr/0006-the-garden-has-a-plot-for-every-plant-it-can-hold.md`.
      final sowing = GardenPlots.sow(
        plants: await garden.occupiedPlots(),
        decor: await decor.occupiedPlots(),
      );
      final plot = sowing.plot;

      // The displacement, and it happens before the plant is written. Nothing
      // in the schema would stop the other order — the plants and the
      // arrangement are two tables with two indexes, so a plant and a bench in
      // one plot is a state SQLite would accept — which is exactly why the
      // order is chosen here rather than left to chance. `GardenLayout` gives
      // the plot to the plant if it ever sees both, so the worst a failure
      // between these two writes can do is lose an object; the reverse order
      // could lose the plant's plot instead.
      final displaced = sowing.displacing;
      if (displaced != null) {
        await decor.removeIn(displaced);
        ref.invalidate(decorProvider);
      }

      final plant = Plant.fromSession(
        session,
        id: ref.read(idSourceProvider).newId(),
        plot: plot,
      );
      await garden.save(plant);
      // After the write, and inside the guard above it: what §7.1 wants counted
      // is plants that are in the ground, so a second notice of the same
      // completion records nothing and a failed write records nothing either.
      _analytics.record(
        PlantGrown(species: plant.species, stageReached: plant.stage),
      );
      ref.invalidate(plantsProvider);
    });
  }

  Future<void> _save(FocusSession session) => _write(
        'saving session ${session.id}',
        () => ref.read(sessionRepositoryProvider).save(session),
      );

  /// Runs a write, and reports rather than rethrows if it fails.
  ///
  /// A failed write loses work the user actually sat through, which is worth
  /// reporting loudly — but not worth taking the running timer down with it, so
  /// the ticker keeps its schedule either way.
  Future<void> _write(String what, Future<void> Function() write) async {
    try {
      await write();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pomodoro_garden',
        context: ErrorDescription(what),
      ));
    }
  }

  /// Schedules the next repaint for the moment the timer's next second begins.
  ///
  /// Not a one-second periodic timer: those fire *no sooner* than their period
  /// and so slide later and later, which on a countdown shows up as a second
  /// that visibly gets skipped. Aiming at the boundary re-aims every time, so
  /// lateness never accumulates.
  ///
  /// A paused session keeps its ticker. The countdown is standing still, but
  /// the time spent paused is counting up and the plant is still growing, so
  /// there is as much to repaint as there is for a running one.
  void _scheduleTick() {
    _stopTicking();

    final snapshot = _machine.snapshot;
    final until = switch (snapshot.phase) {
      // Counting down: the next second begins when the fraction runs out. A
      // break is counting down the same way a session is, and the tick that
      // lands on its last second is also what notices it is over — so the two
      // share this line rather than each having one.
      SessionPhase.running || SessionPhase.onBreak =>
        _remainder(snapshot.remaining),
      // Counting up: it begins when the fraction fills.
      SessionPhase.paused => _untilFull(snapshot.pausedSoFar),
      // Nothing is moving, so nothing needs repainting.
      SessionPhase.idle ||
      SessionPhase.completed ||
      SessionPhase.breakOver =>
        null,
    };
    if (until == null) return;

    _ticker = Timer(until, _tick);
  }

  static Duration _remainder(Duration of) {
    final into = of.inMicroseconds % Duration.microsecondsPerSecond;
    return Duration(
      microseconds: into == 0 ? Duration.microsecondsPerSecond : into,
    );
  }

  static Duration _untilFull(Duration of) => Duration(
        microseconds: Duration.microsecondsPerSecond -
            of.inMicroseconds % Duration.microsecondsPerSecond,
      );

  void _stopTicking() {
    _ticker?.cancel();
    _ticker = null;
  }
}
