import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('the bundled set', () {
    test('has enough lines that a garden does not repeat itself', () {
      // A new garden has 12 plots.
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

      // Not necessarily every line, but more than one.
      expect(said.length, greaterThan(PlantQuotes.all.length ~/ 2));
    });

    test('spreads across the whole set rather than favouring the front', () {
      // A weak hash would put every plant on the first line or two.
      final said = {
        for (var n = 0; n < 2000; n++) PlantQuotes.forPlant('seeded-plant-$n'),
      };

      expect(said, hasLength(PlantQuotes.all.length));
    });
  });
}
