import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

/// REQ-015's table, as a test. Every boundary in it is a place a session one
/// minute either side grows a different plant, and every one of them is
/// asserted from both directions.
void main() {
  group('the six bands', () {
    test('a session of each length grows the plant REQ-015 names', () {
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

    test('every length REQ-030 allows falls in a band', () {
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
    // The five places the table changes plant. Each is asserted at the last
    // minute of the band below and the first of the band above, because an
    // off-by-one here is invisible until a user's 25-minute session grows a
    // herb.
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
      // REQ-030 allows a length that is not a whole number of minutes, so the
      // bands cannot be read as sets of whole minutes: 14:59 is still short of
      // the fifteen minutes a herb asks for.
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

  group('outside REQ-030', () {
    // The settings cannot produce these, but a mis-wired caller or a row
    // written by a build with different bounds can. The mapping is total: the
    // nearest band, never an exception, because refusing here would leave a
    // session with no plant at all.
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
    test('start where REQ-015 says they start', () {
      expect(PlantType.wildflower.shortestSession, const Duration(minutes: 5));
      expect(PlantType.herb.shortestSession, const Duration(minutes: 15));
      expect(PlantType.flower.shortestSession, const Duration(minutes: 25));
      expect(PlantType.bush.shortestSession, const Duration(minutes: 35));
      expect(PlantType.smallTree.shortestSession, const Duration(minutes: 50));
      expect(PlantType.largeTree.shortestSession, const Duration(minutes: 75));
    });

    test('are declared in ascending order, which is what makes the lookup '
        'work', () {
      final minimums = PlantType.grownBySessions
          .map((type) => type.shortestSession!)
          .toList();

      expect(minimums, orderedEquals(List.of(minimums)..sort()));
    });

    test('are the six a session length can grow, and not REQ-021\'s bonus '
        'plant', () {
      // The bonus type is a member of this enum because a plant's type is one
      // stored column (PRD §4.3) — but it is not a band, and no duration
      // reaches it. A `forSessionLength` that walked `values` would hand a
      // milestone plant to anybody who set a long enough timer.
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
