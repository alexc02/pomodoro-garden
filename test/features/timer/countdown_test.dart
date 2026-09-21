import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/features/timer/countdown.dart';

void main() {
  test('whole minutes read MM:00', () {
    expect(formatCountdown(const Duration(minutes: 25)), '25:00');
    expect(formatCountdown(const Duration(minutes: 5)), '05:00');
  });

  test('rounds partial seconds up', () {
    // 0.1s in still shows the full first second.
    expect(
      formatCountdown(const Duration(minutes: 24, seconds: 59, milliseconds: 900)),
      '25:00',
    );
    expect(formatCountdown(const Duration(milliseconds: 1)), '00:01');
  });

  test('only zero reads 00:00', () {
    expect(formatCountdown(Duration.zero), '00:00');
    expect(formatCountdown(const Duration(seconds: 1)), '00:01');
  });

  test('long sessions keep counting in minutes', () {
    expect(formatCountdown(const Duration(minutes: 120)), '120:00');
    expect(formatCountdown(const Duration(minutes: 99, seconds: 59)), '99:59');
  });

  test('negative duration clamps to 00:00', () {
    expect(formatCountdown(const Duration(seconds: -5)), '00:00');
  });
}
