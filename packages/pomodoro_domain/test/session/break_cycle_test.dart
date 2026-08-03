import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

/// Any fixed instant.
final anchor = DateTime.utc(2026, 8, 11, 9, 41);

const classic = Duration(minutes: 25);
const shortBreak = Duration(minutes: 5);
const longBreak = Duration(minutes: 15);

const shortOffer = BreakOffer(kind: BreakKind.short, length: shortBreak);
const longOffer = BreakOffer(kind: BreakKind.long, length: longBreak);

void main() {
  late FixedClock clock;
  late SessionMachine machine;

  setUp(() {
    clock = FixedClock(anchor);
    machine = SessionMachine(clock, SequentialIdSource());
  });

  /// Runs a full session and collects the completion. Most tests need a few
  /// behind them since only finished sessions move the cycle.
  void completeASession({Duration of = classic}) {
    machine.start(plannedDuration: of);
    clock.advance(of);
    machine.poll();
  }

  group('a break runs on the same machinery as a session', () {
    test('a started break is counting down its whole length', () {
      completeASession();

      machine.startBreak(shortOffer);

      final snapshot = machine.snapshot;
      expect(snapshot.phase, SessionPhase.onBreak);
      expect(snapshot.remaining, shortBreak);
      expect(snapshot.elapsed, Duration.zero);
      expect(snapshot.progress, 0);
      expect(snapshot.breakKind, BreakKind.short);
    });

    test('and is read from the clock rather than counted', () {
      completeASession();
      machine.startBreak(shortOffer);

      clock.advance(const Duration(minutes: 2));

      expect(machine.snapshot.elapsed, const Duration(minutes: 2));
      expect(machine.snapshot.remaining, const Duration(minutes: 3));
      expect(machine.snapshot.progress, closeTo(0.4, 1e-9));
    });

    test('and is due at its anchor plus its length, however often it is asked',
        () {
      // Same as a session's `dueAt`: handed to the scheduler, and `now +
      // remaining` would drift.
      completeASession();
      machine.startBreak(shortOffer);

      final due = machine.snapshot.dueAt;
      expect(due, clock.now().add(shortBreak));

      clock.advance(const Duration(minutes: 1));
      expect(machine.snapshot.dueAt, due);
    });

    test('an hour in the background finds the break over, not overrun', () {
      // Nothing runs while backgrounded; the break is just read from the clock.
      completeASession();
      machine.startBreak(shortOffer);

      clock.advance(const Duration(hours: 1));

      final snapshot = machine.snapshot;
      expect(snapshot.phase, SessionPhase.breakOver);
      expect(snapshot.elapsed, shortBreak, reason: 'capped at what was planned');
      expect(snapshot.remaining, Duration.zero);
      expect(snapshot.progress, 1);
    });

    test('a break reaches breakOver exactly at its length, not a moment before',
        () {
      completeASession();
      machine.startBreak(shortOffer);

      clock.advance(shortBreak - const Duration(microseconds: 1));
      expect(machine.snapshot.phase, SessionPhase.onBreak);

      clock.advance(const Duration(microseconds: 1));
      expect(machine.snapshot.phase, SessionPhase.breakOver);
    });
  });

  group('a break anchored where its session ended', () {
    test('counts from that instant, not from when it was started', () {
      machine.start(plannedDuration: classic);
      final ended = anchor.add(classic);
      // Session ran out and nobody looked for three minutes.
      clock.advance(classic + const Duration(minutes: 3));
      machine.poll();

      machine.startBreak(shortOffer, at: ended);

      expect(machine.snapshot.phase, SessionPhase.onBreak);
      expect(machine.snapshot.remaining, const Duration(minutes: 2));
      expect(machine.snapshot.dueAt, ended.add(shortBreak));
    });

    test('is already over when the whole of it passed unseen', () {
      machine.start(plannedDuration: classic);
      clock.advance(classic + const Duration(minutes: 40));
      machine.poll();

      machine.startBreak(shortOffer, at: anchor.add(classic));

      expect(machine.snapshot.phase, SessionPhase.breakOver);
      expect(machine.snapshot.remaining, Duration.zero);
    });

    test('cannot be anchored in the future', () {
      completeASession();

      expect(
        () => machine.startBreak(
          shortOffer,
          at: clock.now().add(const Duration(seconds: 1)),
        ),
        throwsArgumentError,
      );
      expect(machine.snapshot.phase, SessionPhase.completed,
          reason: 'a refused break leaves the finished session where it was');
    });

    test('anchoring does not change how the cycle moves', () {
      completeASession();
      machine.startBreak(longOffer, at: clock.now());

      expect(machine.snapshot.cyclePosition, 0,
          reason: 'a long break wraps the cycle wherever it is anchored');
    });
  });

  group('a break earns nothing', () {
    test('nothing grows while one runs', () {
      completeASession();
      machine.startBreak(shortOffer);
      clock.advance(const Duration(minutes: 3));

      expect(machine.snapshot.growing, isNull);
      expect(machine.snapshot.growthProgress, 0);
    });

    test('and a break that runs its course hands nothing back to record', () {
      completeASession();
      expect(machine.poll(), isNull, reason: 'the session already paid out');

      machine.startBreak(shortOffer);
      clock.advance(const Duration(hours: 1));

      // Polling is the only way anything gets stored or counted, and breaks
      // never come out of it.
      expect(machine.poll(), isNull);
      expect(machine.snapshot.phase, SessionPhase.breakOver);
    });

    test('a break does not move the cycle on', () {
      completeASession();
      expect(machine.snapshot.cyclePosition, 1);

      machine.startBreak(shortOffer);
      clock.advance(const Duration(hours: 1));

      expect(machine.snapshot.cyclePosition, 1,
          reason: 'sessions move the cycle; resting in one does not');
    });
  });

  group('leaving a break', () {
    test('skipping one returns cleanly to idle', () {
      completeASession();
      machine.startBreak(shortOffer);

      machine.endBreak();

      final snapshot = machine.snapshot;
      expect(snapshot.phase, SessionPhase.idle);
      expect(snapshot.breakKind, isNull);
      expect(snapshot.remaining, Duration.zero);
      expect(snapshot.dueAt, isNull);
    });

    test('ending one early returns to idle, not to breakOver', () {
      // Only a break that ran out gets the end sound.
      completeASession();
      machine.startBreak(shortOffer);
      clock.advance(const Duration(minutes: 4));

      machine.endBreak();

      expect(machine.snapshot.phase, SessionPhase.idle);
    });

    test('and the clock cannot bring it back', () {
      completeASession();
      machine.startBreak(shortOffer);
      machine.endBreak();

      clock.advance(const Duration(hours: 1));

      expect(machine.snapshot.phase, SessionPhase.idle);
    });

    test('starting the next session ends the break it was on', () {
      completeASession();
      machine.startBreak(shortOffer);
      clock.advance(const Duration(minutes: 2));

      machine.start(plannedDuration: classic);

      expect(machine.snapshot.phase, SessionPhase.running);
      expect(machine.snapshot.breakKind, isNull);
      expect(machine.snapshot.remaining, classic);
    });

    test('starting a session from breakOver runs the whole session', () {
      completeASession();
      machine.startBreak(shortOffer);
      clock.advance(const Duration(hours: 1));

      machine.start(plannedDuration: classic);

      expect(machine.snapshot.phase, SessionPhase.running);
      expect(machine.snapshot.remaining, classic);
    });

    test('a force-quit takes the break with it', () {
      completeASession();
      machine.startBreak(shortOffer);

      expect(machine.voidInFlight(), isNull,
          reason: 'a break leaves no record to close');
      expect(machine.snapshot.phase, SessionPhase.idle);
    });

    test('ending a break nobody is on is a caller bug', () {
      expect(machine.endBreak, throwsA(isA<SessionTransitionError>()));
    });
  });

  group('a break is not a session', () {
    setUp(() {
      completeASession();
      machine.startBreak(shortOffer);
    });

    test('it cannot be paused', () {
      expect(machine.pause, throwsA(isA<SessionTransitionError>()));
    });

    test('it cannot be resumed', () {
      expect(machine.resume, throwsA(isA<SessionTransitionError>()));
    });

    test('it cannot be cancelled', () {
      // Leaving a break is `endBreak` and isn't recorded anywhere.
      expect(machine.cancel, throwsA(isA<SessionTransitionError>()));
    });

    test('and the error says what the timer is actually doing', () {
      expect(
        machine.pause,
        throwsA(isA<SessionTransitionError>().having(
          (error) => error.message,
          'message',
          contains('onBreak'),
        )),
      );
    });
  });

  group('starting a break', () {
    test('cannot happen over a session that is still running', () {
      machine.start(plannedDuration: classic);

      expect(
        () => machine.startBreak(shortOffer),
        throwsA(isA<SessionTransitionError>()),
      );
    });

    test('cannot happen over a completion nobody has collected', () {
      // Same as `start`: the uncollected session would be lost.
      machine.start(plannedDuration: classic);
      clock.advance(classic);

      expect(
        () => machine.startBreak(shortOffer),
        throwsA(isA<SessionTransitionError>()),
      );

      machine.poll();
      expect(machine.startBreak(shortOffer).kind, BreakKind.short);
    });

    test('cannot happen twice over', () {
      completeASession();
      machine.startBreak(shortOffer);

      expect(
        () => machine.startBreak(shortOffer),
        throwsA(isA<SessionTransitionError>()),
      );
    });

    test('refuses a break with no time in it', () {
      completeASession();

      expect(
        () => machine.startBreak(
          const BreakOffer(kind: BreakKind.short, length: Duration.zero),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('the cycle', () {
    test('starts at zero, before anything has been finished', () {
      expect(machine.snapshot.cyclePosition, 0);
    });

    test('moves on once per completed session', () {
      for (var expected = 1; expected <= 3; expected++) {
        completeASession();
        expect(machine.snapshot.cyclePosition, expected);
      }
    });

    test('does not move for a session the user cancelled', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 10));
      machine.cancel();

      expect(machine.snapshot.cyclePosition, 0);
    });

    test('does not move for a session the app went away in the middle of', () {
      machine.start(plannedDuration: classic);
      clock.advance(const Duration(minutes: 10));
      machine.voidInFlight();

      expect(machine.snapshot.cyclePosition, 0);
    });

    test('a completion collected twice still only counts once', () {
      // The ticker and the next tap can both notice the same completion.
      machine.start(plannedDuration: classic);
      clock.advance(classic);

      machine.poll();
      machine.poll();

      expect(machine.snapshot.cyclePosition, 1);
    });

    test('wraps back to session one when a long break begins', () {
      // Default setting: three short breaks, the long one, then session one.
      const settings = GardenSettings.defaults;
      final offered = <BreakKind>[];

      for (var session = 1; session <= settings.longBreakAfter; session++) {
        completeASession();
        final offer = BreakOffer.at(
          machine.snapshot.cyclePosition,
          settings: settings,
        );
        offered.add(offer.kind);

        machine.startBreak(offer);
        clock.advance(offer.length);
        machine.start(plannedDuration: classic);
        machine.cancel();
      }

      expect(offered, [
        BreakKind.short,
        BreakKind.short,
        BreakKind.short,
        BreakKind.long,
      ]);
      expect(machine.snapshot.cyclePosition, 0,
          reason: 'the long break put the user back at session one');

      // Check it really restarts, not just reads zero.
      completeASession();
      expect(
        BreakOffer.at(machine.snapshot.cyclePosition, settings: settings).kind,
        BreakKind.short,
      );
    });

    test('a short break leaves the position where it found it', () {
      completeASession();
      completeASession();

      machine.startBreak(shortOffer);

      expect(machine.snapshot.cyclePosition, 2);
    });

    test('the long break is still owed to a user who skipped past it', () {
      // `>=`, so skipping the long break doesn't lose it.
      const settings = GardenSettings.defaults;
      for (var session = 0; session < settings.longBreakAfter + 2; session++) {
        completeASession();
      }

      expect(
        BreakOffer.at(machine.snapshot.cyclePosition, settings: settings).kind,
        BreakKind.long,
      );
    });

    test('a long break cut short still wraps the cycle', () {
      // Starting the long break wraps the cycle, even if cut short after a
      // minute.
      const settings = GardenSettings.defaults;
      for (var session = 0; session < settings.longBreakAfter; session++) {
        completeASession();
      }

      machine.startBreak(longOffer);
      clock.advance(const Duration(minutes: 1));
      machine.endBreak();

      expect(machine.snapshot.cyclePosition, 0);
    });

    test('survives everything the timer does in between', () {
      // The cycle outlives what's in flight, so it's on every phase's snapshot,
      // including idle after a skip.
      completeASession();
      machine.startBreak(shortOffer);
      machine.endBreak();
      expect(machine.snapshot.cyclePosition, 1);

      machine.start(plannedDuration: classic);
      expect(machine.snapshot.cyclePosition, 1);

      machine.pause();
      expect(machine.snapshot.cyclePosition, 1);
    });
  });

  group('what break is on offer', () {
    const settings = GardenSettings.defaults;

    test('a short one until the cycle is up', () {
      for (var position = 0; position < settings.longBreakAfter; position++) {
        expect(
          BreakOffer.at(position, settings: settings),
          const BreakOffer(kind: BreakKind.short, length: shortBreak),
        );
      }
    });

    test('a long one once it is', () {
      expect(
        BreakOffer.at(settings.longBreakAfter, settings: settings),
        const BreakOffer(kind: BreakKind.long, length: longBreak),
      );
    });

    test('and the cycle is the user\'s to set', () {
      final impatient = settings.withLongBreakAfter(2);

      expect(BreakOffer.at(1, settings: impatient).kind, BreakKind.short);
      expect(BreakOffer.at(2, settings: impatient).kind, BreakKind.long);
    });

    test('offers compare by value', () {
      expect(
        BreakOffer.at(0, settings: settings),
        BreakOffer.at(0, settings: settings),
      );
      expect(
        BreakOffer.at(0, settings: settings).hashCode,
        BreakOffer.at(0, settings: settings).hashCode,
      );
      expect(
        BreakOffer.at(0, settings: settings),
        isNot(BreakOffer.at(settings.longBreakAfter, settings: settings)),
      );
    });
  });

  group('how long a long break runs', () {
    test('three ordinary breaks, which is the fifteen minutes', () {
      // 5 min default x3 = 15, which matches the Long break preset.
      expect(GardenSettings.defaults.longBreakLength, const Duration(minutes: 15));
    });

    test('and it follows the break the user actually chose', () {
      expect(
        GardenSettings.defaults
            .withBreakLength(const Duration(minutes: 3))
            .longBreakLength,
        const Duration(minutes: 9),
      );
    });

    test('but never longer than a break is allowed to be', () {
      // Slider at 30 would otherwise give a 90 min long break.
      final generous =
          GardenSettings.defaults.withBreakLength(const Duration(minutes: 30));

      expect(generous.longBreakLength, SettingsRanges.breakLength.max);
      expect(
        SettingsRanges.breakLength.contains(generous.longBreakLength),
        isTrue,
      );
    });
  });

  group('the auto-start settings', () {
    test('are both off until the user turns them on', () {
      expect(GardenSettings.defaults.autoStartBreak, isFalse);
      expect(GardenSettings.defaults.autoStartNextSession, isFalse);
    });

    test('and each moves on its own', () {
      final onlyBreaks =
          GardenSettings.defaults.withAutoStartBreak(enabled: true);

      expect(onlyBreaks.autoStartBreak, isTrue);
      expect(onlyBreaks.autoStartNextSession, isFalse);

      final both = onlyBreaks.withAutoStartNextSession(enabled: true);
      expect(both.autoStartBreak, isTrue);
      expect(both.autoStartNextSession, isTrue);
    });

    test('and they are part of what makes two settings equal', () {
      expect(
        GardenSettings.defaults.withAutoStartBreak(enabled: true),
        isNot(GardenSettings.defaults),
      );
      expect(
        GardenSettings.defaults.withAutoStartNextSession(enabled: true),
        isNot(GardenSettings.defaults),
      );
    });
  });

  group('a machine handed the cycle a previous launch left', () {
    test('picks up where it was, so the long break still falls due', () {
      machine = SessionMachine(clock, SequentialIdSource(), cyclePosition: 3);
      expect(machine.snapshot.cyclePosition, 3);

      completeASession();

      expect(machine.snapshot.cyclePosition, 4);
      expect(
        BreakOffer.at(
          machine.snapshot.cyclePosition,
          settings: GardenSettings.defaults,
        ).kind,
        BreakKind.long,
      );
    });

    test('starts at session one when handed nothing', () {
      expect(machine.snapshot.cyclePosition, 0);
    });
  });

  group('resetting the cycle', () {
    test('puts it back at session one', () {
      completeASession();
      completeASession();
      completeASession();
      expect(machine.snapshot.cyclePosition, 3);

      machine.resetCycle();

      expect(machine.snapshot.cyclePosition, 0);
      completeASession();
      expect(machine.snapshot.cyclePosition, 1);
    });
  });
}
