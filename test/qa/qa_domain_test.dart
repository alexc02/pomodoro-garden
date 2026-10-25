// Exploratory QA suite: domain rules checked against PRD §3.3.
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

void main() {
  test('TC-21 plant tiers follow REQ-015 boundaries', () {
    PlantType at(int m, [int s = 0]) =>
        PlantType.forSessionLength(Duration(minutes: m, seconds: s));
    expect(at(5), PlantType.wildflower);
    expect(at(14, 59), PlantType.wildflower);
    expect(at(15), PlantType.herb);
    expect(at(24), PlantType.herb);
    expect(at(25), PlantType.flower);
    expect(at(34), PlantType.flower);
    expect(at(35), PlantType.bush);
    expect(at(49), PlantType.bush);
    expect(at(50), PlantType.smallTree);
    expect(at(74), PlantType.smallTree);
    expect(at(75), PlantType.largeTree);
    expect(at(120), PlantType.largeTree);
  });

  test('TC-22 growth stages follow REQ-016 thresholds while running', () {
    final clock = FixedClock(DateTime.utc(2026, 8, 11, 9));
    final machine = SessionMachine(clock, SequentialIdSource())
      ..start(plannedDuration: const Duration(minutes: 10));
    GrowthStage stage() => machine.snapshot.growing!.stage;
    expect(stage(), GrowthStage.seed);
    clock.advance(const Duration(minutes: 2));
    expect(stage(), GrowthStage.sprout);
    clock.advance(const Duration(minutes: 3));
    expect(stage(), GrowthStage.young);
    clock.advance(const Duration(minutes: 3));
    expect(stage(), GrowthStage.maturing);
    clock.advance(const Duration(minutes: 2));
    expect(stage(), GrowthStage.mature);
  });

  test('TC-23 a paused session does not reach Mature before it completes '
      '(REQ-016: Mature = "Session complete")', () {
    final clock = FixedClock(DateTime.utc(2026, 8, 11, 9));
    final machine = SessionMachine(clock, SequentialIdSource())
      ..start(plannedDuration: const Duration(minutes: 10));
    clock.advance(const Duration(minutes: 8));
    machine.pause();
    clock.advance(const Duration(minutes: 4)); // 8 + 4 * 0.5 = 10 min of growth
    expect(machine.snapshot.phase, SessionPhase.paused);
    expect(machine.snapshot.growing!.stage, isNot(GrowthStage.mature));
  });
}
