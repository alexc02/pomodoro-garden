import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/live/live_session.dart';

/// What the live surface is handed, derived from the timer. Everything past
/// this is Swift or Kotlin, so this is the last place to assert when it shows
/// and what it says.
void main() {
  final now = DateTime.utc(2026, 8, 14, 10);
  late FixedClock clock;
  late IdSource ids;

  setUp(() {
    clock = FixedClock(now);
    ids = SequentialIdSource();
  });

  SessionMachine running({
    Duration planned = const Duration(minutes: 25),
    Duration elapsed = Duration.zero,
  }) {
    final machine = SessionMachine(clock, ids)..start(plannedDuration: planned);
    clock.advance(elapsed);
    return machine;
  }

  group('what is shown', () {
    test('nothing, before a session has ever run', () {
      final idle = SessionMachine(clock, ids).snapshot;

      expect(LiveSession.of(idle), isNull);
    });

    test('a running session, ending at the instant it is due', () {
      final machine = running(elapsed: const Duration(minutes: 10));

      final live = LiveSession.of(machine.snapshot)!;

      expect(live.paused, isFalse);
      expect(live.remaining, const Duration(minutes: 15));
      // Absolute and 15 minutes out, so the surface can count down on its own.
      expect(live.endsAt, now.add(const Duration(minutes: 25)));
      expect(live.progress, closeTo(0.4, 1e-9));
    });

    test('a held session, with its countdown standing still', () {
      final machine = running(elapsed: const Duration(minutes: 10))..pause();
      clock.advance(const Duration(minutes: 5));

      final live = LiveSession.of(machine.snapshot)!;

      expect(live.paused, isTrue);
      // The countdown froze and the end moved out by the length of the hold.
      expect(live.remaining, const Duration(minutes: 15));
      expect(live.endsAt, now.add(const Duration(minutes: 30)));
    });

    test('nothing, once the session is complete', () {
      // The notification announces completion; the surface shouldn't linger at
      // zero.
      final machine = running(elapsed: const Duration(minutes: 25));

      expect(LiveSession.of(machine.snapshot), isNull);
    });

    test('nothing, once the session is cancelled', () {
      final machine = running(elapsed: const Duration(minutes: 10))..cancel();

      expect(LiveSession.of(machine.snapshot), isNull);
    });
  });

  group('the plant', () {
    test('is named and staged, so the surface can show both', () {
      // The expanded view shows ring, remaining time and growth stage.
      final machine = running(elapsed: const Duration(minutes: 10));

      final live = LiveSession.of(machine.snapshot)!;

      expect(live.growing.stage, GrowthStage.sprout);
      expect(live.growing.type, PlantType.flower);
      expect(live.sessionId, live.growing.sessionId);
    });

    test('advances a stage as the session runs', () {
      final machine = running();

      final seed = LiveSession.of(machine.snapshot)!;
      clock.advance(const Duration(minutes: 21));
      final maturing = LiveSession.of(machine.snapshot)!;

      expect(seed.growing.stage, GrowthStage.seed);
      expect(maturing.growing.stage, GrowthStage.maturing);
    });

    test('runs ahead of the countdown while the session is held', () {
      // A paused plant keeps growing at half rate, so the surface shows the
      // stage separately from the ring.
      final machine = running(elapsed: const Duration(minutes: 5))..pause();
      clock.advance(const Duration(minutes: 20));

      final live = LiveSession.of(machine.snapshot)!;

      // 5 focused plus half of 20 paused is 15 of 25: young, where the
      // countdown alone would say sprout.
      expect(live.growing.stage, GrowthStage.young);
      expect(live.progress, closeTo(0.2, 1e-9));
    });
  });

  group('when a push is worth making', () {
    test('a second later is the same surface', () {
      // The platform counts down from `endsAt` itself; pushing every second
      // would be pointless channel traffic.
      final machine = running();
      final first = LiveSession.of(machine.snapshot)!;

      clock.advance(const Duration(seconds: 1));
      final second = LiveSession.of(machine.snapshot)!;

      expect(second, isNot(first), reason: 'the remaining time did move');
      expect(first.showsTheSameAs(second), isTrue);
    });

    test('a new growth stage is not', () {
      final machine = running();
      final seed = LiveSession.of(machine.snapshot)!;

      clock.advance(const Duration(minutes: 5));
      final sprout = LiveSession.of(machine.snapshot)!;

      expect(seed.showsTheSameAs(sprout), isFalse);
    });

    test('being held is not', () {
      final machine = running();
      final before = LiveSession.of(machine.snapshot)!;

      machine.pause();
      final held = LiveSession.of(machine.snapshot)!;

      expect(before.showsTheSameAs(held), isFalse);
    });

    test('a minute further into a hold is the same surface', () {
      final machine = running()..pause();
      final held = LiveSession.of(machine.snapshot)!;

      clock.advance(const Duration(minutes: 3));
      final stillHeld = LiveSession.of(machine.snapshot)!;

      // The end instant moved, but a held surface only shows remaining time,
      // which hasn't. Pushing here would mean pushing every second of the
      // pause.
      expect(stillHeld.endsAt, isNot(held.endsAt));
      expect(held.showsTheSameAs(stillHeld), isTrue);
    });

    test('resuming is, and carries the end instant the hold moved', () {
      final machine = running()..pause();
      final held = LiveSession.of(machine.snapshot)!;
      clock.advance(const Duration(minutes: 3));
      machine.resume();

      final running_ = LiveSession.of(machine.snapshot)!;

      // The moved end instant is delivered when it starts to matter.
      expect(held.showsTheSameAs(running_), isFalse);
      expect(running_.endsAt, held.endsAt.add(const Duration(minutes: 3)));
    });

    test('a hold that has grown the plant a stage is', () {
      // Held plants grow at half rate, so a long pause can change the stage.
      final machine = running(elapsed: const Duration(minutes: 4))..pause();
      final held = LiveSession.of(machine.snapshot)!;

      clock.advance(const Duration(minutes: 20));
      final grown = LiveSession.of(machine.snapshot)!;

      expect(grown.growing.stage, isNot(held.growing.stage));
      expect(held.showsTheSameAs(grown), isFalse);
    });

    test('the next session is not, even at the same instant', () {
      final first = LiveSession.of(running().snapshot)!;
      final second = LiveSession.of(running().snapshot)!;

      expect(first.showsTheSameAs(second), isFalse);
    });
  });
}
