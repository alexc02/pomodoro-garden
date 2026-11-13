import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

final DateTime _anchor = DateTime.utc(2026, 8, 11, 9, 41);

var _next = 0;

/// A plant of [species]. In the garden unless [shelved].
Plant _plant(
  PlantSpecies species, {
  bool shelved = false,
  int day = 0,
  String? id,
}) {
  final n = _next++;
  return Plant(
    id: id ?? 'plant-$n',
    sessionId: 'session-$n',
    type: species.type,
    species: species,
    stage: GrowthStage.mature,
    plantedAt: _anchor.add(Duration(days: day)),
    sessionDuration: const Duration(minutes: 25),
    plot: shelved ? null : GardenPlots.inPlacementOrder[n % 200],
  );
}

List<Plant> _grown(PlantSpecies species, int count) =>
    [for (var n = 0; n < count; n++) _plant(species)];

void main() {
  group('mastery marks', () {
    test('are earned at 1, 5, 25 and 100 grown', () {
      expect(MasteryMark.values.map((mark) => mark.grown), [1, 5, 25, 100]);
    });

    test('are all still ahead before the first plant', () {
      expect(MasteryMark.reachedBy(0), isEmpty);
      expect(MasteryMark.nextAfter(0), MasteryMark.first);
    });

    test('are earned on the count, not one past it', () {
      expect(MasteryMark.reachedBy(4), [MasteryMark.first]);
      expect(MasteryMark.reachedBy(5), [MasteryMark.first, MasteryMark.fifth]);
      expect(MasteryMark.nextAfter(4), MasteryMark.fifth);
      expect(MasteryMark.nextAfter(5), MasteryMark.twentyFifth);
    });

    test('run out after the hundredth', () {
      expect(MasteryMark.reachedBy(100), MasteryMark.values);
      expect(MasteryMark.nextAfter(100), isNull);
      expect(MasteryMark.reachedBy(5000), MasteryMark.values);
    });
  });

  group('an empty shelf', () {
    final shelf = Shelf.of(const []);

    test('still has a spot for every species', () {
      expect(shelf.species, PlantSpecies.values.length);
      expect(
        [
          for (final row in shelf.rows)
            for (final spot in row.spots) spot.species,
        ],
        unorderedEquals(PlantSpecies.values),
      );
    });

    test('has found nothing and holds nothing', () {
      expect(shelf.discovered, 0);
      expect(shelf.stored, 0);
      for (final species in PlantSpecies.values) {
        final spot = shelf.spotFor(species);
        expect(spot.isDiscovered, isFalse);
        expect(spot.isBare, isFalse);
        expect(spot.marks, isEmpty);
      }
    });
  });

  group('rows', () {
    final shelf = Shelf.of(const []);

    test('run from the shortest sessions to the longest, awards last', () {
      expect(shelf.rows.map((row) => row.type), PlantType.values);
      expect(shelf.rows.last.type, PlantType.bonus);
    });

    test('hold only their own type, in declaration order', () {
      for (final row in shelf.rows) {
        expect(
          row.spots.map((spot) => spot.species),
          PlantSpecies.of(row.type),
        );
      }
    });

    test('put the awards in the order they are earned', () {
      expect(
        shelf.rows.last.spots.map((spot) => spot.milestone),
        Milestone.values,
      );
    });

    test('count what has been found in them', () {
      final rows = Shelf.of([
        _plant(PlantSpecies.tulip),
        _plant(PlantSpecies.tulip),
        _plant(PlantSpecies.daisy, shelved: true),
      ]).rows;

      final flowers = rows.singleWhere((row) => row.type == PlantType.flower);
      expect(flowers.discovered, 2);
      expect(
        rows.where((row) => row != flowers).map((row) => row.discovered),
        everyElement(0),
      );
    });
  });

  group('a spot', () {
    test('counts every plant of its species, wherever it stands', () {
      final shelf = Shelf.of([
        ..._grown(PlantSpecies.poppy, 3),
        _plant(PlantSpecies.poppy, shelved: true),
        _plant(PlantSpecies.poppy, shelved: true),
        _plant(PlantSpecies.mint),
      ]);

      final poppy = shelf.spotFor(PlantSpecies.poppy);
      expect(poppy.grown, 5);
      expect(poppy.stored, hasLength(2));
      expect(shelf.spotFor(PlantSpecies.mint).grown, 1);
    });

    test('earns its marks from plants still in the garden', () {
      // Nothing shelved: mastery mustn't depend on stripping the garden.
      final spot =
          Shelf.of(_grown(PlantSpecies.oak, 25)).spotFor(PlantSpecies.oak);

      expect(spot.stored, isEmpty);
      expect(spot.isBare, isTrue);
      expect(spot.marks.last, MasteryMark.twentyFifth);
      expect(spot.nextMark, MasteryMark.hundredth);
    });

    test('keeps its marks when its plants move to the shelf', () {
      final inGarden = Shelf.of(_grown(PlantSpecies.basil, 5));
      final onShelf = Shelf.of([
        for (var n = 0; n < 5; n++) _plant(PlantSpecies.basil, shelved: true),
      ]);

      expect(
        onShelf.spotFor(PlantSpecies.basil).marks,
        inGarden.spotFor(PlantSpecies.basil).marks,
      );
      expect(onShelf.spotFor(PlantSpecies.basil).isBare, isFalse);
    });

    test('lists what it stores newest first, whatever order they came in',
        () {
      final shelf = Shelf.of([
        _plant(PlantSpecies.pine, shelved: true, day: 2, id: 'middle'),
        _plant(PlantSpecies.pine, shelved: true, day: 9, id: 'newest'),
        _plant(PlantSpecies.pine, shelved: true, day: 1, id: 'oldest'),
      ]);

      expect(
        shelf.spotFor(PlantSpecies.pine).stored.map((plant) => plant.id),
        ['newest', 'middle', 'oldest'],
      );
    });

    test('orders plants from the same moment the same way every time', () {
      final a = _plant(PlantSpecies.pine, shelved: true, id: 'a');
      final b = _plant(PlantSpecies.pine, shelved: true, id: 'b');

      List<String> ids(List<Plant> plants) => [
            for (final plant
                in Shelf.of(plants).spotFor(PlantSpecies.pine).stored)
              plant.id,
          ];

      expect(ids([a, b]), ids([b, a]));
    });

    test('stores a plant whose plot is outside the garden', () {
      // A row from another version. The garden can't draw it, so the shelf
      // has it, same as `GardenLayout.shelved`.
      final stray = _plant(PlantSpecies.mint).inPlot(const GardenPlot(50, 50));

      expect(stray.isShelved, isTrue);
      expect(Shelf.of([stray]).spotFor(PlantSpecies.mint).stored, [stray]);
    });
  });

  group('a milestone plant', () {
    Plant award(Milestone milestone, {GardenPlot? plot}) => Plant.forMilestone(
          milestone,
          id: 'bonus-${milestone.sessions}',
          plantedAt: _anchor,
          plot: plot,
        );

    test('knows the milestone that awards it', () {
      final shelf = Shelf.of(const []);

      expect(
        shelf.spotFor(PlantSpecies.cherryBlossomGrove).milestone,
        Milestone.twoHundredAndFifty,
      );
      expect(shelf.spotFor(PlantSpecies.cherryBlossom).milestone, isNull);
    });

    test('is found once awarded, and has no marks to earn', () {
      final spot = Shelf.of([
        award(Milestone.ten, plot: const GardenPlot(0, 0)),
      ]).spotFor(PlantSpecies.bonsai);

      expect(spot.isDiscovered, isTrue);
      expect(spot.marks, isEmpty);
      expect(spot.nextMark, isNull);
    });

    test('can be stored like any other', () {
      final shelf = Shelf.of([award(Milestone.ten)]);

      expect(shelf.spotFor(PlantSpecies.bonsai).stored, hasLength(1));
      expect(shelf.stored, 1);
    });
  });

  test('the shelf and the garden split the plants between them', () {
    final plants = [
      ..._grown(PlantSpecies.tulip, 7),
      for (var n = 0; n < 4; n++) _plant(PlantSpecies.willow, shelved: true),
    ];

    final shelf = Shelf.of(plants);
    final garden = GardenLayout.of(plants: plants, completedSessions: 11);

    expect(shelf.stored, garden.shelved.length);
    expect(shelf.stored + garden.plants.length, plants.length);
    expect(shelf.discovered, 2);
  });
}
