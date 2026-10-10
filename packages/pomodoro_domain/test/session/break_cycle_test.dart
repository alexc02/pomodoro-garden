import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

/// An arbitrary instant. Nothing here reads the calendar, so which one it is
/// never matters — only that it is fixed.
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

  /// Runs a whole session, from START to the completion being collected.
  ///
  /// The cycle is moved by sessions the user *finished*, so almost every test
  /// here needs one or more of them behind it, and none of them is about how a
  /// session runs.
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
      // The same promise a session's `dueAt` makes, and for the same two
      // reasons: it is what gets handed to the scheduler that announces the end
      // of a break in the background, and `now + remaining` would slide by
      // however long the caller took to ask.
      completeASession();
      machine.startBreak(shortOffer);

      final due = machine.snapshot.dueAt;
      expect(due, clock.now().add(shortBreak));

      clock.advance(const Duration(minutes: 1));
      expect(machine.snapshot.dueAt, due);
    });

    test('an hour in the background finds the break over, not overrun', () {
      // Nothing of this app runs while it is away, so a break is noticed to
      // have ended the same way a session is: by being asked. The reading an
      // hour late is the same reading a second late.
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

  group('a break anchored where its session ended (ADR 0022)', () {
    test('counts from that instant, not from when it was started', () {
      machine.start(plannedDuration: classic);
      final ended = anchor.add(classic);
      // The session ran out, and nobody looked for another three minutes.
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
      // The requirement, where every reader of the timer will see it. A screen
      // draws bare soil, the live surface declines to show anything, and no
      // growth stage can change, because there is no plant to change it.
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

      // Polling is how a session is noticed to have completed, and it is the
      // only route by which anything reaches storage or the garden. A break
      // never comes back from it, so no count of sessions, no streak and no
      // milestone can see one.
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
      // The difference the end sound hangs off: a break that ran out is news,
      // and a break the user walked away from is not something to chime about.
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
      // Cancelling is what a user does to a session they are abandoning, and it
      // is recorded as an outcome. Walking out of a break is `endBreak`, and it
      // is recorded nowhere.
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
      // The same rule `start` follows, and the same reason: the session is over
      // by the clock but its record and its plant have not been written down,
      // and a break started over it would throw both away.
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
      // Completion can be noticed by the ticker and again by the tap that
      // starts the next thing. The second notice must not move the cycle.
      machine.start(plannedDuration: classic);
      clock.advance(classic);

      machine.poll();
      machine.poll();

      expect(machine.snapshot.cyclePosition, 1);
    });

    test('wraps back to session one when a long break begins', () {
      // The whole of the long-break rule, walked end to end at the default
      // setting: three short breaks, then the long one, then session one again.
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

      // And the cycle really does start again rather than merely reading zero.
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
      // Greater-than-or-equal rather than equal. Somebody who ignored the long
      // break they were offered and did another session has not thereby lost
      // it — the cycle does not forget a break by overshooting it.
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
      // Taking the long break is what wraps it, not sitting through the whole
      // thing. A user who rests for one minute of fifteen has had their long
      // break, and being offered it again for the rest of the day would be the
      // app arguing with them.
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
      // The cycle is the one thing on the snapshot that outlives what is in
      // flight, so it has to be there in every phase — including the idle the
      // user is left in by skipping a break.
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
    test('three ordinary breaks, which is REQ-007\'s fifteen minutes', () {
      // The default break is five minutes and REQ-007 names fifteen as its Long
      // preset. The multiple is chosen so that those two agree.
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
      // A user who drags the break slider to its far end does not thereby
      // invent a ninety-minute break the settings themselves would refuse.
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
      // REQ-032, and the ticket's default. An app that starts counting
      // something nobody asked for has taken a decision away from the user.
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
}
