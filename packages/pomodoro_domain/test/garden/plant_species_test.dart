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

    test('different seeds spread across the species that grow all year', () {
      final chosen = {
        for (var seed = 0; seed < 400; seed++)
          PlantSpecies.chosenFor(type: PlantType.flower, seed: '$seed'),
      };

      expect(
        chosen,
        unorderedEquals(
          PlantSpecies.of(PlantType.flower)
              .where((species) => species.season == null),
        ),
      );
    });
  });

  group('forms', () {
    test('every type has a form, and every form a species', () {
      for (final type in PlantType.values) {
        expect(PlantForm.of(type), isNotEmpty, reason: type.name);
      }
      for (final form in PlantForm.values) {
        expect(
          PlantSpecies.values.where((species) => species.form == form),
          isNotEmpty,
          reason: form.name,
        );
      }
    });

    test('every session type comes in more than one shape', () {
      for (final type in PlantType.grownBySessions) {
        expect(PlantForm.of(type).length, greaterThan(1), reason: type.name);
      }
    });

    test('a species takes its type from its form', () {
      expect(PlantSpecies.pine.form, PlantForm.conifer);
      expect(PlantSpecies.pine.type, PlantType.largeTree);
      expect(PlantSpecies.tulip.form, isNot(PlantSpecies.sunflower.form));
    });

    test('every form of a type can be grown at any time of year', () {
      for (final type in PlantType.grownBySessions) {
        final yearRound = {
          for (final species in PlantSpecies.growingIn(type, null))
            if (!species.isRare) species.form,
        };
        expect(yearRound, PlantForm.of(type).toSet(), reason: type.name);
      }
    });
  });

  group('seasonal species', () {
    Set<PlantSpecies> grownIn(PlantType type, Season? season) => {
          for (var seed = 0; seed < 600; seed++)
            PlantSpecies.chosenFor(type: type, seed: '$seed', season: season),
        };

    test('only grow in their own season', () {
      for (final type in PlantType.grownBySessions) {
        for (final season in Season.values) {
          for (final species in grownIn(type, season)) {
            expect(
              species.season,
              anyOf(isNull, season),
              reason: '${species.name} in ${season.name}',
            );
          }
        }
      }
    });

    test('do grow in their own season', () {
      for (final species in PlantSpecies.values) {
        final season = species.season;
        if (season == null) continue;

        expect(
          grownIn(species.type, season),
          contains(species),
          reason: species.name,
        );
      }
    });

    test('never grow when the season is unknown', () {
      for (final type in PlantType.grownBySessions) {
        expect(
          grownIn(type, null).where((species) => species.season != null),
          isEmpty,
          reason: type.name,
        );
      }
    });

    test('every season has something of its own', () {
      for (final season in Season.values) {
        expect(
          PlantSpecies.values.where((species) => species.season == season),
          isNotEmpty,
          reason: season.name,
        );
      }
    });

    test('every type still grows in every season', () {
      for (final type in PlantType.values) {
        for (final season in [null, ...Season.values]) {
          expect(
            PlantSpecies.growingIn(type, season).where((it) => !it.isRare),
            isNotEmpty,
            reason: '${type.name} in ${season?.name}',
          );
        }
      }
    });

    test('milestone plants are neither seasonal nor rare', () {
      for (final species in PlantSpecies.of(PlantType.bonus)) {
        expect(species.season, isNull, reason: species.name);
        expect(species.isRare, isFalse, reason: species.name);
      }
    });
  });

  group('rare species', () {
    test('every session type has one', () {
      for (final type in PlantType.grownBySessions) {
        expect(
          PlantSpecies.of(type).where((species) => species.isRare),
          isNotEmpty,
          reason: type.name,
        );
      }
    });

    test('turn up about one session in ten', () {
      const sessions = 5000;
      var rare = 0;
      for (var seed = 0; seed < sessions; seed++) {
        final species = PlantSpecies.chosenFor(
          type: PlantType.largeTree,
          seed: 'session-$seed',
          season: Season.summer,
        );
        if (species.isRare) rare++;
      }

      expect(
        rare / sessions,
        closeTo(1 / PlantSpecies.oneInThisManyIsRare, 0.02),
      );
    });

    test('are rare in the same sessions whatever the season', () {
      for (var seed = 0; seed < 300; seed++) {
        final rare = {
          for (final season in Season.values)
            PlantSpecies.chosenFor(
              type: PlantType.bush,
              seed: '$seed',
              season: season,
            ).isRare,
        };
        expect(rare, hasLength(1), reason: 'seed $seed');
      }
    });
  });
}
