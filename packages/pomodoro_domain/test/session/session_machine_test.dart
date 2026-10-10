import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

/// An arbitrary instant. Nothing in the machine reads the calendar, so which
/// one it is never matters — only that it is fixed.
final anchor = DateTime.utc(2026, 8, 11, 9, 41);

const classic = Duration(minutes: 25);

/// A clock a test can move in either direction. [FixedClock] deliberately
/// refuses to rewind; this one exists to exercise what happens when the device
/// clock is corrected backwards under a running session.
final class AdjustableClock implements Clock {
  AdjustableClock(this._instant);

  DateTime _instant;

  @override
  DateTime now() => _instant;

  void set(DateTime instant) => _instant = instant.toUtc();
}

void main() {
  late FixedClock clock;
  late SessionMachine machine;

  setUp(() {
    clock = FixedClock(anchor);
    machine = SessionMachine(clock, SequentialIdSource());
  });

  group('starting', () {
    test('a started session is running, with the whole duration remaining', () {
      machine.start(plannedDuration: classic);

      final snapshot = machine.snapshot;
      expect(snapshot.phase, SessionPhase.running);
      expect(snapshot.remaining, classic);
      expect(snapshot.elapsed, Duration.zero);
      expect(snapshot.progress, 0);
    });
  });

  group('snapshots', () {
    test('two readings of the same instant are the same state', () {
      // The screen rebuilds when the state changes. A snapshot that compared
      // by identity would repaint the ring every tick of a session that has
      // not moved — and would keep `pumpAndSettle` awake forever.
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 3));

      expect(machine.snapshot, machine.snapshot);
      expect(machine.snapshot.hashCode, machine.snapshot.hashCode);

      final before = machine.snapshot;
      clock.advance(const Duration(seconds: 1));
      expect(machine.snapshot, isNot(before));
    });
  });

  group('when the session is due', () {
    test('nothing is due before a session has run', () {
      expect(machine.snapshot.dueAt, isNull);
    });

    test('a running session is due its whole duration after the anchor', () {
      machine.start(plannedDuration: classic);

      expect(machine.snapshot.dueAt, anchor.add(classic));
    });

    test('and stays due at the same instant however often it is asked', () {
      // The reason this is on the snapshot at all. `now + remaining` is the
      // same instant recomputed from a fresh clock reading every time, so it
      // slides forward by however long the caller took to ask — which on a
      // lock-screen countdown is a redraw a second for nothing, and on a
      // scheduled alarm is a chime that is late by the same amount.
      machine.start(plannedDuration: classic);
      final due = machine.snapshot.dueAt;

      clock.advance(const Duration(minutes: 7));

      expect(machine.snapshot.dueAt, due);
    });

    test('a held session is due later by however long it has been held', () {
      machine
        ..start(plannedDuration: classic)
        ..pause();

      clock.advance(const Duration(minutes: 4));

      expect(machine.snapshot.dueAt, anchor.add(classic + const Duration(minutes: 4)));
    });

    test('a resumed session is due later by the whole of the pause', () {
      machine
        ..start(plannedDuration: classic)
        ..pause();
      clock.advance(const Duration(minutes: 4));
      machine.resume();
      clock.advance(const Duration(minutes: 10));

      expect(machine.snapshot.dueAt, anchor.add(classic + const Duration(minutes: 4)));
    });

    test('a completed session was due when it completed', () {
      machine.start(plannedDuration: classic);
      clock.advance(classic);
      final completed = machine.poll()!;

      expect(machine.snapshot.dueAt, completed.endedAt);
    });
  });

  group('illegal transitions', () {
    test('a session cannot be started while one is running', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 5));

      expect(
        () => machine.start(plannedDuration: classic),
        throwsA(isA<SessionTransitionError>()),
      );
      expect(machine.snapshot.elapsed, const Duration(minutes: 5),
          reason: 'the running session is untouched by the refusal');
    });

    test('a session cannot be started over one that completed but has not been '
        'handed over', () {
      machine.start(plannedDuration: classic);
      clock.advance(classic);

      // The completion has not been polled, so its record does not exist
      // anywhere yet. Starting here would drop a session the user earned.
      expect(
        () => machine.start(plannedDuration: classic),
        throwsA(isA<SessionTransitionError>()),
      );
    });

    test('a session cannot last no time at all', () {
      expect(
        () => machine.start(plannedDuration: Duration.zero),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => machine.start(plannedDuration: const Duration(seconds: -1)),
        throwsA(isA<ArgumentError>()),
      );
      expect(machine.snapshot.phase, SessionPhase.idle);
    });
  });

  group('a clock that moves backwards', () {
    test('does not put a session ahead of where it started', () {
      // A device clock correction — NTP, or the user setting the time by hand —
      // can land `now` behind the anchor. Ticket 05 decides what a session
      // *means* after that; what must never happen is negative time.
      final adjustable = AdjustableClock(anchor);
      final machine =
          SessionMachine(adjustable, SequentialIdSource());
      machine.start(plannedDuration: classic);

      adjustable.set(anchor.subtract(const Duration(hours: 2)));

      final snapshot = machine.snapshot;
      expect(snapshot.elapsed, Duration.zero);
      expect(snapshot.remaining, classic);
      expect(snapshot.progress, 0);
      expect(snapshot.phase, SessionPhase.running);
      expect(machine.poll(), isNull);
    });

    test('does not un-complete a session that already completed', () {
      // The session is over and recorded. A clock correction afterwards must
      // not put it back on the ring: it would count down a second time, and
      // the record it left behind says it is done.
      final adjustable = AdjustableClock(anchor);
      final machine = SessionMachine(adjustable, SequentialIdSource());
      machine.start(plannedDuration: classic);
      adjustable.set(anchor.add(classic));
      expect(machine.poll(), isNotNull);

      adjustable.set(anchor.add(const Duration(minutes: 10)));

      final snapshot = machine.snapshot;
      expect(snapshot.phase, SessionPhase.completed);
      expect(snapshot.remaining, Duration.zero);
      expect(snapshot.elapsed, classic);
      expect(snapshot.progress, 1);
      expect(machine.poll(), isNull, reason: 'and not recorded twice');
    });
  });

  group('the record', () {
    test('a started session is recorded as running, anchored to now', () {
      final session = machine.start(plannedDuration: classic);

      expect(session.id, '1', reason: 'the id comes from the injected source');
      expect(session.startedAt, anchor);
      expect(session.plannedDuration, classic);
      expect(session.completed, isFalse);
      expect(session.outcome, isNull);
      expect(session.endedAt, isNull);
      expect(session.pausedDuration, Duration.zero);
      expect(session.pausedSince, isNull);
    });
  });

  group('elapsed time', () {
    test('is the gap between the anchor and now, with nothing counted in '
        'between', () {
      machine.start(plannedDuration: classic);

      // One jump, no polling in between. A machine that accumulated ticks
      // would still read 25:00 here, because nothing ticked.
      clock.advance(const Duration(minutes: 10));

      final snapshot = machine.snapshot;
      expect(snapshot.elapsed, const Duration(minutes: 10));
      expect(snapshot.remaining, const Duration(minutes: 15));
      expect(snapshot.progress, closeTo(0.4, 1e-9));
    });
  });

  group('completing', () {
    test('the session is complete the instant the planned duration is up', () {
      machine.start(plannedDuration: classic);

      clock.advance(classic);

      final snapshot = machine.snapshot;
      expect(snapshot.phase, SessionPhase.completed);
      expect(snapshot.remaining, Duration.zero);
      expect(snapshot.elapsed, classic);
      expect(snapshot.progress, 1);
    });

    test('polling hands over the completed session exactly once', () {
      machine.start(plannedDuration: classic);

      expect(machine.poll(), isNull, reason: 'nothing has happened yet');

      clock.advance(const Duration(minutes: 24, seconds: 59));
      expect(machine.poll(), isNull, reason: 'one second short');

      clock.advance(const Duration(seconds: 1));
      final completed = machine.poll();
      expect(completed, isNotNull);
      expect(completed!.id, '1');
      expect(completed.completed, isTrue);
      expect(completed.endedAt, anchor.add(classic));

      expect(machine.poll(), isNull,
          reason: 'the session is recorded once, not once per tick');
    });

    test('a session noticed late ended when the timer ran out, not when the '
        'app looked', () {
      machine.start(plannedDuration: classic);

      // Phone in a pocket for an hour; the first poll comes long after.
      clock.advance(const Duration(hours: 1));

      expect(machine.poll()!.endedAt, anchor.add(classic));
    });

    test('polling an idle machine hands over nothing', () {
      expect(machine.poll(), isNull);
    });

    test('the next session starts clean once the last one is handed over', () {
      machine.start(plannedDuration: classic);
      clock.advance(classic);
      machine.poll();
      clock.advance(const Duration(minutes: 7));

      final second = machine.start(plannedDuration: const Duration(minutes: 50));

      expect(second.id, '2', reason: 'a session of its own, not the first one');
      expect(second.startedAt, anchor.add(const Duration(minutes: 32)));
      expect(machine.snapshot.phase, SessionPhase.running);
      expect(machine.snapshot.remaining, const Duration(minutes: 50));
    });

    test('a two-hour session is accurate to well within a second, polled at '
        'irregular intervals throughout', () {
      // PRD §4.4: ±1 second over a 120-minute session. Ticking would accrue
      // error at every one of these steps; deriving from the anchor cannot.
      const planned = Duration(minutes: 120);
      machine.start(plannedDuration: planned);

      var advanced = Duration.zero;
      var step = 0;
      while (advanced < planned) {
        // Jitter of the kind a real scheduler produces: a late frame here, a
        // dropped one there, never exactly one second.
        final jitter = Duration(milliseconds: 900 + (step * 37) % 300);
        final next = advanced + jitter <= planned ? jitter : planned - advanced;
        clock.advance(next);
        advanced += next;
        step++;

        final remaining = machine.snapshot.remaining;
        final error = (remaining - (planned - advanced)).abs();
        expect(error, lessThan(const Duration(seconds: 1)),
            reason: 'drifted by $error after $advanced (step $step)');
      }

      expect(step, greaterThan(6000), reason: 'a realistic number of polls');
      expect(machine.snapshot.phase, SessionPhase.completed);
      expect(machine.poll()!.endedAt, anchor.add(planned),
          reason: 'the session ended exactly two hours after it started');
    });

    test('overshooting the end does not overshoot the numbers', () {
      // The app was suspended and nobody looked at the clock for three hours.
      machine.start(plannedDuration: classic);

      clock.advance(const Duration(hours: 3));

      final snapshot = machine.snapshot;
      expect(snapshot.phase, SessionPhase.completed);
      expect(snapshot.elapsed, classic, reason: 'elapsed is capped at planned');
      expect(snapshot.remaining, Duration.zero,
          reason: 'remaining never goes negative');
      expect(snapshot.progress, 1, reason: 'progress never exceeds 1');
    });
  });

  group('what is growing', () {
    test('nothing grows before a session starts', () {
      expect(machine.snapshot.growing, isNull);
    });

    test('a seed drops the instant the session does', () {
      machine.start(plannedDuration: classic);

      final growing = machine.snapshot.growing!;
      expect(growing.stage, GrowthStage.seed);
      expect(growing.type, PlantType.flower, reason: '25 minutes');
    });

    test('the plant advances with the session', () {
      machine.start(plannedDuration: classic);

      clock.advance(const Duration(minutes: 5));
      expect(machine.snapshot.growing!.stage, GrowthStage.sprout);

      clock.advance(const Duration(minutes: 8));
      expect(machine.snapshot.growing!.stage, GrowthStage.young);

      clock.advance(const Duration(minutes: 7));
      expect(machine.snapshot.growing!.stage, GrowthStage.maturing);

      clock.advance(const Duration(minutes: 5));
      expect(machine.snapshot.growing!.stage, GrowthStage.mature);
    });

    test('a longer session grows a bigger plant', () {
      machine.start(plannedDuration: const Duration(minutes: 90));

      expect(machine.snapshot.growing!.type, PlantType.largeTree);
    });

    test('the species holds still for the whole session', () {
      machine.start(plannedDuration: const Duration(minutes: 90));
      final species = machine.snapshot.growing!.species;

      for (var minute = 0; minute < 90; minute++) {
        clock.advance(const Duration(minutes: 1));
        expect(machine.snapshot.growing!.species, species,
            reason: 'at minute $minute');
      }
    });

    test('the plant a completed session leaves is the one that grew', () {
      machine.start(plannedDuration: classic);
      final watched = machine.snapshot.growing!;

      clock.advance(classic);
      final plant = Plant.fromSession(machine.poll()!, id: 'plant-1');

      expect(plant.species, watched.species);
      expect(plant.type, watched.type);
    });

    test('the last session stays on screen until the next one starts', () {
      // Between a completion and the next START the timer still shows the
      // finished session, so its mature plant is still what is growing.
      machine.start(plannedDuration: classic);
      clock.advance(classic);
      machine.poll();

      expect(machine.snapshot.growing!.stage, GrowthStage.mature);
    });
  });

  group('pausing', () {
    test('holds the countdown where it was', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 10));

      machine.pause();
      expect(machine.snapshot.phase, SessionPhase.paused);

      clock.advance(const Duration(minutes: 7));

      final snapshot = machine.snapshot;
      expect(snapshot.phase, SessionPhase.paused);
      expect(snapshot.elapsed, const Duration(minutes: 10));
      expect(snapshot.remaining, const Duration(minutes: 15));
      expect(snapshot.progress, closeTo(0.4, 1e-9));
    });

    test('resuming loses and gains nothing', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 10));
      machine.pause();
      clock.advance(const Duration(minutes: 7));
      machine.resume();

      expect(machine.snapshot.elapsed, const Duration(minutes: 10),
          reason: 'exactly where it was held');
      expect(machine.snapshot.phase, SessionPhase.running);

      clock.advance(const Duration(minutes: 5));
      expect(machine.snapshot.elapsed, const Duration(minutes: 15),
          reason: 'and running again at the ordinary rate');
    });

    test('the session ends late by exactly what it spent paused', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 10));
      machine.pause();
      clock.advance(const Duration(minutes: 7));
      machine.resume();

      // 15 minutes of the session are still to run, and the wall clock is
      // already 17 minutes past the anchor.
      clock.advance(const Duration(minutes: 14, seconds: 59));
      expect(machine.poll(), isNull, reason: 'one second short');

      clock.advance(const Duration(seconds: 1));
      final completed = machine.poll()!;
      expect(completed.endedAt,
          anchor.add(const Duration(minutes: 32)),
          reason: '25 minutes of focus, pushed out by a 7-minute pause');
      expect(completed.pausedDuration, const Duration(minutes: 7));
    });

    test('several pauses add up', () {
      machine.start(plannedDuration: classic);

      for (var pause = 0; pause < 3; pause++) {
        clock.advance(const Duration(minutes: 2));
        machine.pause();
        clock.advance(const Duration(minutes: 1));
        machine.resume();
      }

      expect(machine.snapshot.pausedSoFar, const Duration(minutes: 3));
      expect(machine.snapshot.elapsed, const Duration(minutes: 6));
    });

    test('the paused duration includes the pause still open', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 2));
      machine.pause();
      clock.advance(const Duration(minutes: 4));

      expect(machine.snapshot.pausedSoFar, const Duration(minutes: 4));
    });

    test('a pause is recorded on the session the moment it begins', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 2));

      final paused = machine.pause();
      expect(paused.isPaused, isTrue);
      expect(paused.pausedSince, anchor.add(const Duration(minutes: 2)));
      expect(paused.pausedDuration, Duration.zero,
          reason: 'a pause that has not ended has no length yet');

      clock.advance(const Duration(minutes: 4));
      final resumed = machine.resume();
      expect(resumed.isPaused, isFalse);
      expect(resumed.pausedSince, isNull);
      expect(resumed.pausedDuration, const Duration(minutes: 4));
    });

    test('a session cannot be paused twice, or resumed while running', () {
      machine.start(plannedDuration: classic);

      machine.pause();
      expect(machine.pause, throwsA(isA<SessionTransitionError>()));

      machine.resume();
      expect(machine.resume, throwsA(isA<SessionTransitionError>()));
      expect(machine.snapshot.phase, SessionPhase.running,
          reason: 'the refusals left the session alone');
    });

    test('nothing can be paused, resumed or cancelled when nothing is running',
        () {
      expect(machine.pause, throwsA(isA<SessionTransitionError>()));
      expect(machine.resume, throwsA(isA<SessionTransitionError>()));
      expect(machine.cancel, throwsA(isA<SessionTransitionError>()));

      // And not once a session is over either: what is on screen then is a
      // finished session's plant, not a session anyone can hold.
      machine.start(plannedDuration: classic);
      clock.advance(classic);
      machine.poll();

      expect(machine.pause, throwsA(isA<SessionTransitionError>()));
      expect(machine.cancel, throwsA(isA<SessionTransitionError>()));
    });

    test('a session whose time is up cannot be paused before it is collected',
        () {
      // The window between the clock passing the end and the caller polling.
      // Pausing here would hold a session that is already over.
      machine.start(plannedDuration: classic);
      clock.advance(classic);

      expect(machine.pause, throwsA(isA<SessionTransitionError>()));
      expect(machine.poll(), isNotNull, reason: 'and it is still collectable');
    });
  });

  group('growth while paused', () {
    test('continues at half the ordinary rate — REQ-009', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 5));
      expect(machine.snapshot.growthProgress, closeTo(0.2, 1e-9));

      machine.pause();

      // Ten paused minutes buy five minutes of growth: 5 + 5 of 25.
      clock.advance(const Duration(minutes: 10));
      expect(machine.snapshot.growthProgress, closeTo(0.4, 1e-9));
      expect(machine.snapshot.progress, closeTo(0.2, 1e-9),
          reason: 'the countdown itself has not moved');
    });

    test('the plant keeps advancing through its stages while held', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 5));
      machine.pause();
      expect(machine.snapshot.growing!.stage, GrowthStage.sprout);

      // 7½ more minutes of growth, bought with 15 paused minutes: 12½ of 25,
      // which is where young begins.
      clock.advance(const Duration(minutes: 15));
      expect(machine.snapshot.growing!.stage, GrowthStage.young);
    });

    test('a session that was never paused grows exactly with its countdown',
        () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 9));

      final snapshot = machine.snapshot;
      expect(snapshot.growthProgress, snapshot.progress);
    });

    test('a plant does not grow past mature, however long the pause', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 5));
      machine.pause();
      clock.advance(const Duration(hours: 8));

      expect(machine.snapshot.growthProgress, 1);
      expect(machine.snapshot.growing!.stage, GrowthStage.mature);
      expect(machine.snapshot.phase, SessionPhase.paused,
          reason: 'a mature plant does not finish the session for you');
      expect(machine.snapshot.remaining, const Duration(minutes: 20));
    });
  });

  group('cancelling', () {
    test('hands back a cancelled record and empties the machine', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 8));

      final cancelled = machine.cancel();

      expect(cancelled.outcome, SessionOutcome.cancelled);
      expect(cancelled.completed, isFalse);
      expect(cancelled.endedAt, anchor.add(const Duration(minutes: 8)));
      expect(machine.snapshot.phase, SessionPhase.idle);
      expect(machine.snapshot.growing, isNull,
          reason: 'an abandoned session leaves no plant on screen');
      expect(machine.poll(), isNull);
    });

    test('a cancelled session is not a plant', () {
      machine.start(plannedDuration: classic);
      final cancelled = machine.cancel();

      expect(
        () => Plant.fromSession(cancelled, id: 'plant-1'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('cancelling a paused session records the pause it was in', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 8));
      machine.pause();
      clock.advance(const Duration(minutes: 3));

      final cancelled = machine.cancel();

      expect(cancelled.pausedDuration, const Duration(minutes: 3));
      expect(cancelled.isPaused, isFalse);
      expect(cancelled.endedAt, anchor.add(const Duration(minutes: 11)));
    });

    test('the next session starts clean after a cancellation', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 8));
      machine.cancel();

      final second = machine.start(plannedDuration: classic);

      expect(second.id, '2');
      expect(second.startedAt, anchor.add(const Duration(minutes: 8)));
      expect(machine.snapshot.remaining, classic);
    });
  });

  group('voiding', () {
    test('ends a running session as voided rather than cancelled', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 8));

      final voided = machine.voidInFlight()!;

      expect(voided.outcome, SessionOutcome.voided,
          reason: 'nobody decided to end this one — the app went away');
      expect(voided.completed, isFalse);
      expect(voided.endedAt, anchor.add(const Duration(minutes: 8)));
      expect(machine.snapshot.phase, SessionPhase.idle);
    });

    test('voids a paused session too, pause and all', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 8));
      machine.pause();
      clock.advance(const Duration(minutes: 2));

      final voided = machine.voidInFlight()!;

      expect(voided.outcome, SessionOutcome.voided);
      expect(voided.pausedDuration, const Duration(minutes: 2));
    });

    test('there is nothing to void when nothing is in flight', () {
      expect(machine.voidInFlight(), isNull);
    });

    test('a session that already earned its plant is not voided', () {
      // The app is being torn down after the timer ran out. The user sat
      // through the whole session; taking it back would be theft.
      machine.start(plannedDuration: classic);
      clock.advance(classic);

      expect(machine.voidInFlight(), isNull);
      expect(machine.poll(), isNotNull,
          reason: 'and the completion is still there to be recorded');
    });
  });

  group('restoring', () {
    /// The record of a session started 10 minutes ago, as storage would hand it
    /// back on a cold start.
    FocusSession inFlight({
      Duration ago = const Duration(minutes: 10),
      Duration pausedDuration = Duration.zero,
      DateTime? pausedSince,
    }) =>
        FocusSession(
          id: 'stored-1',
          startedAt: anchor.subtract(ago),
          plannedDuration: classic,
          pausedDuration: pausedDuration,
          pausedSince: pausedSince,
        );

    test('puts a session back exactly where the wall clock says it is', () {
      machine.restore(inFlight(ago: const Duration(minutes: 15)));

      final snapshot = machine.snapshot;
      expect(snapshot.phase, SessionPhase.running);
      expect(snapshot.elapsed, const Duration(minutes: 15));
      expect(snapshot.remaining, const Duration(minutes: 10));
      expect(snapshot.growing!.stage, GrowthStage.young,
          reason: 'the stage it should have reached, not the one it left at');
    });

    test('a session restored paused comes back paused, still growing', () {
      // Held five minutes in, and the app has been away for six.
      machine.restore(inFlight(
        ago: const Duration(minutes: 11),
        pausedSince: anchor.subtract(const Duration(minutes: 6)),
      ));

      final snapshot = machine.snapshot;
      expect(snapshot.phase, SessionPhase.paused);
      expect(snapshot.elapsed, const Duration(minutes: 5));
      expect(snapshot.pausedSoFar, const Duration(minutes: 6));
      // 5 minutes focused plus half of 6 paused, of 25.
      expect(snapshot.growthProgress, closeTo(0.32, 1e-9));
    });

    test('paused time already recorded still counts against the countdown', () {
      machine.restore(inFlight(
        ago: const Duration(minutes: 18),
        pausedDuration: const Duration(minutes: 4),
      ));

      expect(machine.snapshot.elapsed, const Duration(minutes: 14));
    });

    test('a session whose time ran out while the app was away completes on the '
        'next poll', () {
      machine.restore(inFlight(ago: const Duration(minutes: 40)));

      expect(machine.snapshot.phase, SessionPhase.completed);
      final completed = machine.poll()!;
      expect(completed.id, 'stored-1');
      expect(completed.endedAt, anchor.subtract(const Duration(minutes: 15)),
          reason: 'it ended when the timer ran out, not when the app opened');
    });

    test('the restored session is the one handed back', () {
      final stored = inFlight();
      expect(machine.restore(stored), same(stored));
    });

    test('nothing already ended goes back in flight', () {
      final ended = inFlight().cancelledAt(anchor);

      expect(
        () => machine.restore(ended),
        throwsA(isA<ArgumentError>()),
      );
      expect(machine.snapshot.phase, SessionPhase.idle);
    });

    test('a machine already holding a session refuses to restore over it', () {
      machine.start(plannedDuration: classic);

      expect(
        () => machine.restore(inFlight()),
        throwsA(isA<SessionTransitionError>()),
      );
    });

    test('a restored session can be paused, resumed and cancelled like any '
        'other', () {
      machine.restore(inFlight());

      machine.pause();
      clock.advance(const Duration(minutes: 3));
      expect(machine.snapshot.elapsed, const Duration(minutes: 10));

      machine.resume();
      clock.advance(const Duration(minutes: 2));
      expect(machine.snapshot.elapsed, const Duration(minutes: 12));

      expect(machine.cancel().outcome, SessionOutcome.cancelled);
    });
  });

  group('a device clock that jumps', () {
    test('moving backwards mid-pause does not invent paused time', () {
      final adjustable = AdjustableClock(anchor);
      final machine = SessionMachine(adjustable, SequentialIdSource());
      machine.start(plannedDuration: classic);

      adjustable.set(anchor.add(const Duration(minutes: 5)));
      machine.pause();
      adjustable.set(anchor.add(const Duration(minutes: 1)));

      expect(machine.snapshot.pausedSoFar, Duration.zero,
          reason: 'a pause cannot have run for a negative length of time');
      expect(machine.snapshot.elapsed, const Duration(minutes: 5),
          reason: 'and the countdown is still held where it was');

      adjustable.set(anchor.add(const Duration(minutes: 9)));
      expect(machine.resume().pausedDuration, const Duration(minutes: 4));
    });

    test('a device changing timezone changes nothing about the session', () {
      // The anchor is an absolute instant, so flying across nine timezones —
      // or a DST boundary — changes how the instant is *written*, not which
      // instant it is. 18:51+09:00 is 09:51 UTC: ten minutes past the anchor,
      // and the same ten minutes it was before the phone moved.
      final adjustable = AdjustableClock(anchor);
      final machine = SessionMachine(adjustable, SequentialIdSource());
      machine.start(plannedDuration: classic);

      adjustable.set(anchor.add(const Duration(minutes: 10)));
      final beforeTheFlight = machine.snapshot;

      adjustable.set(DateTime.parse('2026-08-11T18:51:00+09:00'));

      expect(machine.snapshot.elapsed, const Duration(minutes: 10));
      expect(machine.snapshot.remaining, const Duration(minutes: 15));
      expect(machine.snapshot, beforeTheFlight,
          reason: 'the same instant is the same state, however it is written');
    });

    test('a correction forwards ends the session early, and is allowed to', () {
      // Pinning a consequence rather than praising it. Elapsed time is the gap
      // to a wall-clock anchor (ADR 0001), so a clock corrected *forwards* is
      // indistinguishable from time having passed, and the session ends. There
      // is no monotonic reference that could tell the difference and also
      // survive the process dying, which is what the anchor is for.
      //
      // The bound on the damage is that nothing here is corrupt: the session
      // completes cleanly, once, and its end is stamped where the arithmetic
      // says rather than where the clock jumped to.
      final adjustable = AdjustableClock(anchor);
      final machine = SessionMachine(adjustable, SequentialIdSource());
      machine.start(plannedDuration: classic);

      adjustable.set(anchor.add(const Duration(hours: 3)));

      final snapshot = machine.snapshot;
      expect(snapshot.phase, SessionPhase.completed);
      expect(snapshot.elapsed, classic, reason: 'capped at what was planned');
      expect(snapshot.remaining, Duration.zero);
      expect(snapshot.progress, 1);

      final completed = machine.poll()!;
      expect(completed.endedAt, anchor.add(classic),
          reason: 'the anchor plus the plan, not the instant of the jump');
      expect(machine.poll(), isNull, reason: 'and it pays out once');
    });

    test('a correction forwards during a pause does not end the session', () {
      // The one place a jump forwards is harmless: a held countdown does not
      // read the clock, so there is nothing for the jump to move. It buys the
      // plant a great deal of half-rate growth and nothing else.
      final adjustable = AdjustableClock(anchor);
      final machine = SessionMachine(adjustable, SequentialIdSource());
      machine.start(plannedDuration: classic);

      adjustable.set(anchor.add(const Duration(minutes: 5)));
      machine.pause();
      adjustable.set(anchor.add(const Duration(hours: 3)));

      expect(machine.snapshot.phase, SessionPhase.paused);
      expect(machine.snapshot.elapsed, const Duration(minutes: 5));
      expect(machine.poll(), isNull);
    });

    test('a timezone change mid-pause does not move the paused duration', () {
      final adjustable = AdjustableClock(anchor);
      final machine = SessionMachine(adjustable, SequentialIdSource());
      machine.start(plannedDuration: classic);

      adjustable.set(anchor.add(const Duration(minutes: 5)));
      machine.pause();
      adjustable.set(DateTime.parse('2026-08-11T18:51:00+09:00'));

      expect(machine.snapshot.pausedSoFar, const Duration(minutes: 5));
      expect(machine.snapshot.elapsed, const Duration(minutes: 5));
    });
  });
}
