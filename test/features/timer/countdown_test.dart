import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_garden/src/features/timer/countdown.dart';

void main() {
  test('a whole number of minutes reads as MM:00', () {
    expect(formatCountdown(const Duration(minutes: 25)), '25:00');
    expect(formatCountdown(const Duration(minutes: 5)), '05:00');
  });

  test('part of a second still counts as that second', () {
    // A tenth of a second into the session, the user has not yet lost the
    // second they are living through.
    expect(
      formatCountdown(const Duration(minutes: 24, seconds: 59, milliseconds: 900)),
      '25:00',
    );
    expect(formatCountdown(const Duration(milliseconds: 1)), '00:01');
  });

  test('only a session that ran out reads 00:00', () {
    expect(formatCountdown(Duration.zero), '00:00');
    expect(formatCountdown(const Duration(seconds: 1)), '00:01');
  });

  test('long sessions keep counting in minutes', () {
    expect(formatCountdown(const Duration(minutes: 120)), '120:00');
    expect(formatCountdown(const Duration(minutes: 99, seconds: 59)), '99:59');
  });

  test('a negative duration cannot show a negative countdown', () {
    expect(formatCountdown(const Duration(seconds: -5)), '00:00');
  });
}
