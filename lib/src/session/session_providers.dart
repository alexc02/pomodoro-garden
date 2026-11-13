import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../analytics/analytics_providers.dart';
import '../data/database_providers.dart';
import '../garden/decor_providers.dart';
import '../garden/plant_providers.dart';
import '../garden/season_providers.dart';
import '../journal/journal_providers.dart';
import '../settings/settings_providers.dart';
import '../time/clock_provider.dart';

/// The source of session ids. Overridden in tests with one that counts.
final idSourceProvider = Provider<IdSource>((ref) => RandomIdSource());

/// Completed sessions, newest first. [SessionController] invalidates it on
/// each completion.
final completedSessionsProvider = FutureProvider<List<FocusSession>>(
  (ref) => ref.watch(sessionRepositoryProvider).completedSessions(),
);

/// A session left open by a killed app, read once at launch. Force-quit
/// sessions are already voided by [SessionLifecycle]; see
/// `docs/adr/0004-a-session-outlives-the-app-unless-the-user-quit-it.md`.
///
/// Errors are reported and treated as no session, so launch still works.
final restoredSessionProvider = FutureProvider<FocusSession?>((ref) async {
  try {
    return await ref.watch(sessionRepositoryProvider).inFlightSession();
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'pip_garden',
      context: ErrorDescription('restoring the session in flight'),
    ));
    return null;
  }
});

/// Saved Pomodoro cycle position, read once before [SessionGate] opens. On
/// error the cycle restarts at 0.
final restoredCyclePositionProvider = FutureProvider<int>((ref) async {
  try {
    return await ref.watch(cycleStoreProvider).load();
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'pip_garden',
      context: ErrorDescription('restoring the cycle position'),
    ));
    return 0;
  }
});

/// The live timer.
final sessionControllerProvider =
    NotifierProvider<SessionController, SessionSnapshot>(SessionController.new);

/// The break on offer right now (short or long). For the UI;
/// [SessionController.startBreak] calls [BreakOffer.at] directly since it
/// can't read a provider that watches itself.
final breakOnOfferProvider = Provider<BreakOffer>(
  (ref) => BreakOffer.at(
    ref.watch(sessionControllerProvider).cyclePosition,
    settings: ref.watch(settingsProvider),
  ),
);

/// Drives [SessionMachine] and persists its changes. The ticker only
/// triggers repaints; time always comes from the clock.
class SessionController extends Notifier<SessionSnapshot> {
  SessionMachine? _cachedMachine;
  Timer? _ticker;

  /// Last published phase, so auto-start only fires on a phase change.
  /// Otherwise sitting in `completed`, enabling auto-start and resuming the
  /// app would start a break. Starts null so a session restored already
  /// finished still gets its break.
  SessionPhase? _published;

  /// Pause count for analytics. In memory only, so it resets to 0 for a
  /// restored session; not worth a DB column.
  int _pauses = 0;

  @override
  SessionSnapshot build() {
    // Read, not watched: rebuilding the machine would drop the running
    // session.
    var machine = _cachedMachine;
    if (machine == null) {
      machine = _cachedMachine = SessionMachine(
        ref.read(clockProvider),
        ref.read(idSourceProvider),
        cyclePosition: ref.read(restoredCyclePositionProvider).value ?? 0,
        hemisphere: ref.read(hemisphereProvider),
      );
      _restore(machine);
    }

    ref.onDispose(_stopTicking);
    // A rebuild disposed the old ticker.
    _scheduleTick();

    return machine.snapshot;
  }

  SessionMachine get _machine => _cachedMachine!;

  Analytics get _analytics => ref.read(analyticsProvider);

  /// First build only; a rebuild keeps its machine.
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
    // It may have already run out, and a finished session schedules no
    // ticks, so check once after this build.
    scheduleMicrotask(_tick);
  }

  Future<void> start() async {
    // A session may have finished since the last tick; the machine won't
    // start over an unrecorded one.
    await _recordAnyCompletion();
    // Double tap.
    if (_inFlight.contains(_machine.snapshot.phase)) {
      _publish();
      return;
    }

    // Read once; changing the setting only affects the next session.
    final session = _machine.start(
      plannedDuration: ref.read(settingsProvider).sessionLength,
    );
    _pauses = 0;
    _publish();

    _analytics.record(SessionStarted.of(session.plannedDuration));
    await _save(session);
  }

  /// Starts the short or long break the cycle is due. Breaks aren't stored
  /// (only the cycle position is).
  ///
  /// [from] backdates the start, for auto-start after a session that ended
  /// while the app was away.
  Future<void> startBreak({DateTime? from}) async {
    await _recordAnyCompletion();
    // The offer must be read after recording, which advances the cycle.
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
    await _saveCycle();
  }

  /// Ends the break early and goes to idle.
  Future<void> skipBreak() async {
    await _recordAnyCompletion();
    // If it ran out just before the tap, keep breakOver so the end sound
    // plays.
    if (_machine.snapshot.phase != SessionPhase.onBreak) {
      _publish();
      return;
    }

    _machine.endBreak();
    _publish();
  }

  /// The plant keeps growing at half speed while paused.
  Future<void> pause() async {
    final held = await _command(_running, _machine.pause);
    // Null if it finished before the tap.
    if (held == null) return;

    _pauses++;
    _analytics.record(SessionPaused(
      duration: held.plannedDuration,
      pauseCount: _pauses,
    ));
  }

  Future<void> resume() => _command(_held, _machine.resume);

  /// The screen handles confirmation.
  Future<void> cancel() async {
    // Snapshot first: after cancel the machine is idle and elapsed is gone.
    final abandoning = _machine.snapshot;

    final cancelled = await _command(_inFlight, _machine.cancel);
    if (cancelled == null) return;

    _analytics.record(SessionAbandoned(
      duration: cancelled.plannedDuration,
      elapsedBeforeAbandon: abandoning.elapsed,
    ));
  }

  /// Force-quit. Like [cancel] but recorded as voided.
  ///
  /// Runs during teardown, so the write may not land; then the session gets
  /// restored next launch instead. See ADR 0004.
  Future<void> voidInFlight() async {
    await _recordAnyCompletion();

    final voided = _machine.voidInFlight();
    _publish();
    if (voided != null) await _save(voided);
  }

  /// On resume, so the first frame isn't a tick stale.
  Future<void> catchUp() => _tick();

  /// After a garden reset.
  void resetCycle() {
    _machine.resetCycle();
    _publish();
  }

  static const Set<SessionPhase> _running = {SessionPhase.running};
  static const Set<SessionPhase> _held = {SessionPhase.paused};
  static const Set<SessionPhase> _inFlight = {
    SessionPhase.running,
    SessionPhase.paused,
  };

  /// Nothing counting down, so a break may start.
  static const Set<SessionPhase> _atRest = {
    SessionPhase.idle,
    SessionPhase.completed,
    SessionPhase.breakOver,
  };

  /// Runs [transition] if the phase is in [from], saves and returns the
  /// result, else null.
  ///
  /// The machine throws on a bad transition, but a session can finish between
  /// drawing a button and the tap, so check here and return null quietly.
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

    // Only on a phase change, i.e. something just ended.
    if (_machine.snapshot.phase != shown) await _autoStart();
  }

  /// Auto-starts the next break or session if the settings say so.
  ///
  /// A break is backdated to when the session ended; a session always starts
  /// now, so time in a pocket never earns a plant. Skipped breaks go to idle, so they never auto-start a session.
  Future<void> _autoStart() async {
    final settings = ref.read(settingsProvider);

    final snapshot = _machine.snapshot;
    switch (snapshot.phase) {
      case SessionPhase.completed when settings.autoStartBreak:
        await startBreak(from: snapshot.dueAt);
        // The backdated break may already be over.
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
    await _saveCycle();
    await _sow(completed);
    ref.invalidate(completedSessionsProvider);
    // Whole families: every week/month that was read is stale.
    ref.invalidate(journalProvider);
    ref.invalidate(journalMonthProvider);
  }

  /// Publishes the snapshot and reschedules the ticker.
  void _publish() {
    state = _machine.snapshot;
    _published = state.phase;
    _scheduleTick();
  }

  /// Stores the plant and its plot now, so later changes to growth rules or
  /// layout don't change existing gardens.
  ///
  /// May remove a decor item, but only when all 200 plots are taken. See
  /// [GardenPlots.sow].
  Future<void> _sow(FocusSession session) async {
    final garden = ref.read(plantRepositoryProvider);
    final decor = ref.read(decorRepositoryProvider);

    await _write('planting for session ${session.id}', () async {
      // A completion can be seen twice (ticker and next START).
      if (await garden.plantForSession(session.id) != null) return;

      // plot is null if the garden is full of plants; still saved.
      final sowing = GardenPlots.sow(
        plants: await garden.occupiedPlots(),
        decor: await decor.occupiedPlots(),
      );
      final plot = sowing.plot;

      // Remove decor before writing the plant. If the second write fails we
      // lose a decor item rather than the plant's plot (`GardenLayout` favours
      // the plant if both end up in one plot).
      final displaced = sowing.displacing;
      if (displaced != null) {
        await decor.removeIn(displaced);
        ref.invalidate(decorProvider);
      }

      final plant = Plant.fromSession(
        session,
        id: ref.read(idSourceProvider).newId(),
        plot: plot,
        // The machine's, so the plant is the one the timer showed growing.
        hemisphere: _machine.hemisphere,
      );
      await garden.save(plant);
      // Only after a successful, non-duplicate write.
      _analytics.record(
        PlantGrown(species: plant.species, stageReached: plant.stage),
      );
      ref.invalidate(plantsProvider);
    });
  }

  Future<void> _saveCycle() => _write(
        'saving the cycle position',
        () => ref
            .read(cycleStoreProvider)
            .save(_machine.snapshot.cyclePosition),
      );

  Future<void> _save(FocusSession session) => _write(
        'saving session ${session.id}',
        () => ref.read(sessionRepositoryProvider).save(session),
      );

  /// Reports rather than rethrows, so the timer keeps running.
  Future<void> _write(String what, Future<void> Function() write) async {
    try {
      await write();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription(what),
      ));
    }
  }

  /// Aims at the next whole-second boundary rather than using a periodic
  /// timer, which drifts late and skips visible seconds.
  ///
  /// Paused still ticks: paused time counts up and the plant still grows.
  void _scheduleTick() {
    _stopTicking();

    final snapshot = _machine.snapshot;
    final until = switch (snapshot.phase) {
      // Counting down.
      SessionPhase.running || SessionPhase.onBreak =>
        _remainder(snapshot.remaining),
      // Counting up.
      SessionPhase.paused => _untilFull(snapshot.pausedSoFar),
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
