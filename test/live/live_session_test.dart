import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/live/live_session.dart';

/// What the platform is handed, worked out from what the timer says.
///
/// The whole of the live surface's logic that is not a platform's: everything
/// below this line is Swift or Kotlin, so this is the last place a rule about
/// *when* something is shown, and *what it says*, can be asserted at all.
void main() {
  final now = DateTime.utc(2026, 8, 14, 10);
  late FixedClock clock;
  late IdSource ids;

  setUp(() {
    clock = FixedClock(now);
    ids = SequentialIdSource();
  });

  /// A machine with a session [elapsed] into a [planned]-long run.
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
      // Absolute, and 15 minutes out — which is what lets the surface count
      // down for the next quarter of an hour with none of this app running.
      expect(live.endsAt, now.add(const Duration(minutes: 25)));
      expect(live.progress, closeTo(0.4, 1e-9));
    });

    test('a held session, with its countdown standing still', () {
      final machine = running(elapsed: const Duration(minutes: 10))..pause();
      clock.advance(const Duration(minutes: 5));

      final live = LiveSession.of(machine.snapshot)!;

      expect(live.paused, isTrue);
      // The countdown did not move while it was held, and the end moved out by
      // exactly as long as the hold has lasted.
      expect(live.remaining, const Duration(minutes: 15));
      expect(live.endsAt, now.add(const Duration(minutes: 30)));
    });

    test('nothing, once the session is complete', () {
      // Ticket 06's rule, held to at the surface: one completion is announced
      // once, by the notification. A live surface still standing there would be
      // the second thing saying it — and a countdown at zero for however long
      // it took the user to look.
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
      // REQ-010's expanded state: a progress ring, the time remaining, and the
      // growth stage. The first two are numbers; this is the third.
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
      // REQ-009 reaches the lock screen too: a paused plant keeps growing at
      // half rate, so what the surface shows is the growth stage and not a
      // second rendering of the progress ring.
      final machine = running(elapsed: const Duration(minutes: 5))..pause();
      clock.advance(const Duration(minutes: 20));

      final live = LiveSession.of(machine.snapshot)!;

      // 5 minutes focused plus half of 20 paused is 15 of 25 — young, where the
      // countdown alone would still say sprout.
      expect(live.growing.stage, GrowthStage.young);
      expect(live.progress, closeTo(0.2, 1e-9));
    });
  });

  group('when a push is worth making', () {
    test('a second later is the same surface', () {
      // The platform is counting down from `endsAt` on its own. Pushing every
      // second would be sixty channel crossings a minute to redraw a countdown
      // that is already right.
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

      // The session would now end three minutes later than it would have — but
      // nothing on a held surface is drawn from that. What it shows is the
      // remaining time, which has not moved, and a push here would be a push
      // every second for the whole of the pause.
      expect(stillHeld.endsAt, isNot(held.endsAt));
      expect(held.showsTheSameAs(stillHeld), isTrue);
    });

    test('resuming is, and carries the end instant the hold moved', () {
      final machine = running()..pause();
      final held = LiveSession.of(machine.snapshot)!;
      clock.advance(const Duration(minutes: 3));
      machine.resume();

      final running_ = LiveSession.of(machine.snapshot)!;

      // The half of the rule that keeps the other half safe: the moving end
      // instant is never lost, it is delivered at the moment it starts being
      // what the platform counts down to.
      expect(held.showsTheSameAs(running_), isFalse);
      expect(running_.endsAt, held.endsAt.add(const Duration(minutes: 3)));
    });

    test('a hold that has grown the plant a stage is', () {
      // REQ-009: a held plant keeps growing at half rate, so a long enough
      // pause does change what the surface shows.
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
