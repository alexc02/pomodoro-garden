import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

/// The line a plant's card says about growth or patience.
///
/// The requirement that has teeth is the stability one: a user who opens the
/// same plant twice has to be told the same thing, months apart and across
/// relaunches. Everything else here is about the set being worth drawing from.
void main() {
  group('the bundled set', () {
    test('has enough lines that a garden does not repeat itself', () {
      // Twelve plots is what a new user has, and the first dozen plants are
      // the ones they will open one after another.
      expect(PlantQuotes.all.length, greaterThanOrEqualTo(12));
    });

    test('says each line once', () {
      expect(PlantQuotes.all.toSet(), hasLength(PlantQuotes.all.length));
    });

    test('is made of sentences, not fragments', () {
      for (final quote in PlantQuotes.all) {
        expect(quote.trim(), quote, reason: '"$quote" has loose whitespace');
        expect(quote, isNotEmpty);
        expect(
          quote.length,
          lessThanOrEqualTo(120),
          reason: '"$quote" is a paragraph, not a gentle line',
        );
      }
    });
  });

  group('the line a plant gets', () {
    test('is the same every time it is asked for', () {
      // Not a nicety: a plant is opened, closed and opened again months later,
      // and a line that reshuffled would make the card feel generated rather
      // than remembered.
      for (final seed in const ['plant-1', 'plant-2', 'a', '']) {
        expect(PlantQuotes.forPlant(seed), PlantQuotes.forPlant(seed));
      }
    });

    test('is one of the bundled ones', () {
      for (var n = 0; n < 200; n++) {
        expect(PlantQuotes.all, contains(PlantQuotes.forPlant('plant-$n')));
      }
    });

    test('is not the same line for every plant', () {
      final said = {
        for (var n = 0; n < 200; n++) PlantQuotes.forPlant('plant-$n'),
      };

      // Not every line, necessarily — the hash decides — but a garden that
      // said one thing over and over would be worse than saying nothing.
      expect(said.length, greaterThan(PlantQuotes.all.length ~/ 2));
    });

    test('spreads across the whole set rather than favouring the front', () {
      // The failure this guards is the one `stableChoice` was built to avoid:
      // a hash whose high bits barely move would put every plant on the first
      // line or two.
      final said = {
        for (var n = 0; n < 2000; n++) PlantQuotes.forPlant('seeded-plant-$n'),
      };

      expect(said, hasLength(PlantQuotes.all.length));
    });
  });
}
