import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('SystemClock', () {
    test('reports the current instant in UTC', () {
      final now = const SystemClock().now();

      expect(now.isUtc, isTrue);
      expect(
        now.difference(DateTime.now().toUtc()).abs(),
        lessThan(const Duration(seconds: 5)),
      );
    });
  });

  group('FixedClock', () {
    test('stands still across reads', () {
      final clock = FixedClock(DateTime.utc(2026, 8, 11, 9));

      expect(clock.now(), clock.now());
      expect(clock.now(), DateTime.utc(2026, 8, 11, 9));
    });

    test('normalises a local instant to UTC', () {
      final clock = FixedClock(DateTime(2026, 8, 11, 9));

      expect(clock.now().isUtc, isTrue);
      expect(clock.now(), DateTime(2026, 8, 11, 9).toUtc());
    });

    test('advances by the requested delta', () {
      final clock = FixedClock(DateTime.utc(2026, 8, 11, 9));

      clock.advance(const Duration(minutes: 25));

      expect(clock.now(), DateTime.utc(2026, 8, 11, 9, 25));
    });

    test('refuses to rewind', () {
      final clock = FixedClock(DateTime.utc(2026, 8, 11, 9));

      expect(
        () => clock.advance(const Duration(seconds: -1)),
        throwsArgumentError,
      );
      expect(clock.now(), DateTime.utc(2026, 8, 11, 9));
    });
  });
}
