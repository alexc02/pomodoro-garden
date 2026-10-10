import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

/// The one source of "random-looking, but fixed once you know the seed" in the
/// domain.
///
/// Everything about a plant that wants variety — which species it is, how its
/// sway is offset from its neighbour's — is decided this way rather than from a
/// [Random], because those decisions have to survive a rebuild, a relaunch and
/// a reinstall, and a `Random` survives none of them.
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
      // Pinned because these numbers reach the screen: change the hash and
      // every existing plant's sway shifts. That is allowed, but not by
      // accident.
      expect(stableFraction('1'), closeTo(0.33251127949915826, 1e-15));
      expect(stableFraction('2'), closeTo(0.23752244538627565, 1e-15));
    });

    test('seeds that differ by one character land far apart', () {
      // Sessions are identified by UUIDs that share most of their length, and
      // tests identify them by '1', '2', '3'. A hash that mapped those to
      // neighbouring fractions would grow the same species all afternoon.
      final fractions = [
        for (var seed = 1; seed <= 20; seed++) stableFraction('$seed'),
      ];

      expect(fractions.toSet(), hasLength(fractions.length));

      // Ten buckets, twenty seeds: a hash that clustered would leave most of
      // them empty.
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
