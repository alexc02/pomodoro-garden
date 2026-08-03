import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('the six bands', () {
    test('a session of each length grows the right plant', () {
      expect(PlantType.forSessionLength(const Duration(minutes: 5)),
          PlantType.wildflower);
      expect(PlantType.forSessionLength(const Duration(minutes: 15)),
          PlantType.herb);
      expect(PlantType.forSessionLength(const Duration(minutes: 25)),
          PlantType.flower);
      expect(PlantType.forSessionLength(const Duration(minutes: 35)),
          PlantType.bush);
      expect(PlantType.forSessionLength(const Duration(minutes: 50)),
          PlantType.smallTree);
      expect(PlantType.forSessionLength(const Duration(minutes: 75)),
          PlantType.largeTree);
    });

    test('every allowed length falls in a band', () {
      for (var minutes = 5; minutes <= 120; minutes++) {
        final type = PlantType.forSessionLength(Duration(minutes: minutes));
        final expected = switch (minutes) {
          < 15 => PlantType.wildflower,
          < 25 => PlantType.herb,
          < 35 => PlantType.flower,
          < 50 => PlantType.bush,
          < 75 => PlantType.smallTree,
          _ => PlantType.largeTree,
        };
        expect(type, expected, reason: '$minutes minutes');
      }
    });
  });

  group('boundaries', () {
    // Each boundary checked at the last minute below and the first above.
    test('14 minutes is a wildflower, 15 is a herb', () {
      expect(PlantType.forSessionLength(const Duration(minutes: 14)),
          PlantType.wildflower);
      expect(PlantType.forSessionLength(const Duration(minutes: 15)),
          PlantType.herb);
    });

    test('24 minutes is a herb, 25 is a flower', () {
      expect(PlantType.forSessionLength(const Duration(minutes: 24)),
          PlantType.herb);
      expect(PlantType.forSessionLength(const Duration(minutes: 25)),
          PlantType.flower);
    });

    test('34 minutes is a flower, 35 is a bush', () {
      expect(PlantType.forSessionLength(const Duration(minutes: 34)),
          PlantType.flower);
      expect(PlantType.forSessionLength(const Duration(minutes: 35)),
          PlantType.bush);
    });

    test('49 minutes is a bush, 50 is a small tree', () {
      expect(PlantType.forSessionLength(const Duration(minutes: 49)),
          PlantType.bush);
      expect(PlantType.forSessionLength(const Duration(minutes: 50)),
          PlantType.smallTree);
    });

    test('74 minutes is a small tree, 75 is a large tree', () {
      expect(PlantType.forSessionLength(const Duration(minutes: 74)),
          PlantType.smallTree);
      expect(PlantType.forSessionLength(const Duration(minutes: 75)),
          PlantType.largeTree);
    });

    test('a band holds up to the last instant before the next one starts', () {
      // Lengths needn't be whole minutes: 14:59 is still a wildflower.
      expect(
        PlantType.forSessionLength(const Duration(minutes: 14, seconds: 59)),
        PlantType.wildflower,
      );
      expect(
        PlantType.forSessionLength(
          const Duration(minutes: 14, seconds: 59, milliseconds: 999),
        ),
        PlantType.wildflower,
      );
      expect(
        PlantType.forSessionLength(const Duration(minutes: 15)),
        PlantType.herb,
      );
    });
  });

  group('outside the allowed range', () {
    // Settings can't produce these but old rows or bad callers can. Map to the
    // nearest band instead of throwing.
    test('shorter than the shortest band grows the smallest plant', () {
      expect(PlantType.forSessionLength(const Duration(minutes: 1)),
          PlantType.wildflower);
      expect(PlantType.forSessionLength(Duration.zero), PlantType.wildflower);
      expect(PlantType.forSessionLength(const Duration(minutes: -30)),
          PlantType.wildflower);
    });

    test('longer than the longest band grows the largest plant', () {
      expect(PlantType.forSessionLength(const Duration(minutes: 120)),
          PlantType.largeTree);
      expect(PlantType.forSessionLength(const Duration(minutes: 500)),
          PlantType.largeTree);
    });
  });

  group('the bands themselves', () {
    test('start at the expected lengths', () {
      expect(PlantType.wildflower.shortestSession, const Duration(minutes: 5));
      expect(PlantType.herb.shortestSession, const Duration(minutes: 15));
      expect(PlantType.flower.shortestSession, const Duration(minutes: 25));
      expect(PlantType.bush.shortestSession, const Duration(minutes: 35));
      expect(PlantType.smallTree.shortestSession, const Duration(minutes: 50));
      expect(PlantType.largeTree.shortestSession, const Duration(minutes: 75));
    });

    test('are declared in ascending order', () {
      final minimums = PlantType.grownBySessions
          .map((type) => type.shortestSession!)
          .toList();

      expect(minimums, orderedEquals(List.of(minimums)..sort()));
    });

    test('are the six session types, not the bonus plant', () {
      // `bonus` is in the enum but isn't a band. Walking `values` would give a
      // milestone plant to anyone with a long enough timer.
      expect(PlantType.grownBySessions, [
        PlantType.wildflower,
        PlantType.herb,
        PlantType.flower,
        PlantType.bush,
        PlantType.smallTree,
        PlantType.largeTree,
      ]);
      expect(PlantType.bonus.shortestSession, isNull);

      for (var minutes = -100; minutes <= 1000; minutes++) {
        expect(
          PlantType.forSessionLength(Duration(minutes: minutes)),
          isNot(PlantType.bonus),
          reason: '$minutes minutes',
        );
      }
    });

    test('each has a label to show the user', () {
      for (final type in PlantType.values) {
        expect(type.label, isNotEmpty);
      }
      expect(PlantType.smallTree.label, 'Small tree');
    });
  });
}
