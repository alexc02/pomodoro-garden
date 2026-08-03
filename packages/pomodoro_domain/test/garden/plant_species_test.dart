import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('the catalogue', () {
    test('every plant type has species to choose between', () {
      for (final type in PlantType.values) {
        expect(PlantSpecies.of(type), isNotEmpty, reason: type.name);
      }
    });

    test('every species belongs to exactly one type', () {
      final grouped = [
        for (final type in PlantType.values) ...PlantSpecies.of(type),
      ];

      expect(grouped, hasLength(PlantSpecies.values.length));
      expect(grouped.toSet(), hasLength(PlantSpecies.values.length));
    });

    test('has the expected species', () {
      expect(
        PlantSpecies.of(PlantType.herb),
        containsAll(<PlantSpecies>[
          PlantSpecies.basil,
          PlantSpecies.mint,
          PlantSpecies.rosemary,
        ]),
      );
      expect(
        PlantSpecies.of(PlantType.flower),
        containsAll(<PlantSpecies>[
          PlantSpecies.sunflower,
          PlantSpecies.tulip,
          PlantSpecies.daisy,
        ]),
      );
      expect(
        PlantSpecies.of(PlantType.smallTree),
        containsAll(<PlantSpecies>[
          PlantSpecies.cherryBlossom,
          PlantSpecies.maple,
        ]),
      );
      expect(
        PlantSpecies.of(PlantType.largeTree),
        containsAll(<PlantSpecies>[
          PlantSpecies.oak,
          PlantSpecies.willow,
          PlantSpecies.pine,
        ]),
      );
    });

    test('every species has a label for the botanical card', () {
      expect(PlantSpecies.cherryBlossom.label, 'Cherry blossom');
      for (final species in PlantSpecies.values) {
        expect(species.label, isNotEmpty);
      }
    });
  });

  group('choosing one', () {
    test('picks a species of the type asked for', () {
      for (final type in PlantType.values) {
        for (var seed = 0; seed < 30; seed++) {
          final species = PlantSpecies.chosenFor(type: type, seed: '$seed');
          expect(species.type, type);
        }
      }
    });

    test('the same seed always chooses the same species', () {
      final first =
          PlantSpecies.chosenFor(type: PlantType.flower, seed: 'session-9');
      final again =
          PlantSpecies.chosenFor(type: PlantType.flower, seed: 'session-9');

      expect(again, first);
    });

    test('different seeds spread across the species available', () {
      final chosen = {
        for (var seed = 0; seed < 100; seed++)
          PlantSpecies.chosenFor(type: PlantType.flower, seed: '$seed'),
      };

      expect(chosen, unorderedEquals(PlantSpecies.of(PlantType.flower)));
    });
  });
}
