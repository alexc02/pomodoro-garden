import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('stableFraction', () {
    test('is between zero and one', () {
      for (final seed in ['', 'a', 'plant-1', '${DateTime(2026)}', 'z' * 200]) {
        final fraction = stableFraction(seed);
        expect(fraction, greaterThanOrEqualTo(0.0), reason: seed);
        expect(fraction, lessThan(1.0), reason: seed);
      }
    });

    test('is the same every time for the same seed', () {
      expect(stableFraction('plant-1'), stableFraction('plant-1'));
      expect(stableFraction(''), stableFraction(''));
    });

    test('is written down, so a change to it is a deliberate one', () {
      // Pinned: changing the hash shifts every existing plant's sway.
      expect(stableFraction('1'), closeTo(0.33251127949915826, 1e-15));
      expect(stableFraction('2'), closeTo(0.23752244538627565, 1e-15));
    });

    test('seeds that differ by one character land far apart', () {
      // UUIDs share most of their length and test ids are '1', '2', '3'.
      final fractions = [
        for (var seed = 1; seed <= 20; seed++) stableFraction('$seed'),
      ];

      expect(fractions.toSet(), hasLength(fractions.length));

      // 10 buckets, 20 seeds. Clustering would leave most empty.
      final buckets = fractions.map((f) => (f * 10).floor()).toSet();
      expect(buckets.length, greaterThanOrEqualTo(6));
    });
  });

  group('stableChoice', () {
    const options = ['a', 'b', 'c', 'd'];

    test('picks one of the options', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(options, contains(stableChoice(options, '$seed')));
      }
    });

    test('picks the same one every time for the same seed', () {
      expect(stableChoice(options, 'plant-7'), stableChoice(options, 'plant-7'));
    });

    test('reaches every option', () {
      final chosen = {
        for (var seed = 0; seed < 100; seed++) stableChoice(options, '$seed'),
      };

      expect(chosen, unorderedEquals(options));
    });

    test('a single option is always the answer', () {
      expect(stableChoice(const ['only'], 'anything'), 'only');
    });

    test('refuses to choose from nothing', () {
      expect(
        () => stableChoice(const <String>[], 'seed'),
        throwsArgumentError,
      );
    });
  });
}
