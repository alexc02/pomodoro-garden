import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('the seven milestones', () {
    test('are REQ-021\'s counts, and only those', () {
      expect(
        Milestone.values.map((milestone) => milestone.sessions),
        [10, 25, 50, 100, 250, 500, 1000],
      );
    });

    test('award REQ-021\'s plants, in order', () {
      expect(
        {
          for (final milestone in Milestone.values)
            milestone.sessions: milestone.species,
        },
        {
          10: PlantSpecies.bonsai,
          25: PlantSpecies.wisteriaArch,
          50: PlantSpecies.japaneseMaple,
          100: PlantSpecies.ancientOak,
          250: PlantSpecies.cherryBlossomGrove,
          500: PlantSpecies.enchantedWillow,
          1000: PlantSpecies.goldenGarden,
        },
      );
    });

    test('all award a bonus plant, which no session length can grow', () {
      for (final milestone in Milestone.values) {
        expect(milestone.species.type, PlantType.bonus);
      }
      expect(PlantType.grownBySessions, isNot(contains(PlantType.bonus)));
    });

    test('award seven different plants — no milestone repeats another', () {
      final species = Milestone.values.map((m) => m.species).toSet();
      expect(species, hasLength(Milestone.values.length));
    });

    test('are declared in ascending order, which is what lets the lookup stop '
        'early', () {
      final counts = Milestone.values.map((m) => m.sessions).toList();
      expect(counts, orderedEquals(List.of(counts)..sort()));
    });

    test('each says which count earned it', () {
      expect(Milestone.ten.label, '10 sessions');
      expect(Milestone.oneThousand.label, '1000 sessions');
    });
  });

  group('reachedBy', () {
    test('is empty before the first one', () {
      expect(Milestone.reachedBy(0), isEmpty);
      expect(Milestone.reachedBy(9), isEmpty);
    });

    test('includes a milestone on the session that reaches it', () {
      expect(Milestone.reachedBy(10), [Milestone.ten]);
    });

    test('is the whole count, not the last step of it', () {
      // The requirement in one line: a user who arrives at this build with
      // thirty sessions behind them has reached two milestones, and nothing in
      // this package was watching when either went past.
      expect(Milestone.reachedBy(30), [Milestone.ten, Milestone.twentyFive]);
    });

    test('holds every one of them once the count is past the last', () {
      expect(Milestone.reachedBy(1000), Milestone.values);
      expect(Milestone.reachedBy(5000), Milestone.values);
    });

    test('answers for a nonsense count rather than throwing', () {
      expect(Milestone.reachedBy(-1), isEmpty);
    });
  });

  group('dueFrom', () {
    test('hands over everything reached when nothing has been awarded', () {
      expect(
        Milestone.dueFrom(completedSessions: 30, awarded: const {}),
        [Milestone.ten, Milestone.twentyFive],
      );
    });

    test('hands over nothing the second time — awarding is idempotent', () {
      const awarded = {Milestone.ten, Milestone.twentyFive};
      expect(
        Milestone.dueFrom(completedSessions: 30, awarded: awarded),
        isEmpty,
      );
    });

    test('hands over only the gap when some have already been given', () {
      expect(
        Milestone.dueFrom(
          completedSessions: 100,
          awarded: const {Milestone.ten, Milestone.fifty},
        ),
        [Milestone.twentyFive, Milestone.oneHundred],
      );
    });

    test('is not fooled by an award the count no longer justifies', () {
      // Nothing produces this today — sessions are never deleted — but ticket
      // 22's reset will. A milestone already awarded is not re-awarded, and one
      // the user has fallen back below is not taken away either: this answers
      // what is *due*, and nothing is.
      expect(
        Milestone.dueFrom(
          completedSessions: 0,
          awarded: const {Milestone.ten},
        ),
        isEmpty,
      );
    });

    test('runs in ascending order, so a backlog is celebrated in the order it '
        'was earned', () {
      expect(
        Milestone.dueFrom(completedSessions: 1000, awarded: const {}),
        orderedEquals(Milestone.values),
      );
    });
  });

  group('withSessions', () {
    test('reads back every milestone from the integer it is stored as', () {
      for (final milestone in Milestone.values) {
        expect(Milestone.withSessions(milestone.sessions), milestone);
      }
    });

    test('answers null for a count no milestone has', () {
      // A row written by a build whose milestones differed. Better a plant that
      // cannot say what earned it than a garden that will not open.
      expect(Milestone.withSessions(42), isNull);
      expect(Milestone.withSessions(0), isNull);
    });
  });
}
