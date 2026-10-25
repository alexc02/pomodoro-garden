import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';

final DateTime _anchor = DateTime.utc(2026, 8, 11, 9, 41);

Plant _plant({
  String id = 'plant-1',
  String? sessionId = 'session-1',
  PlantType type = PlantType.flower,
  PlantSpecies species = PlantSpecies.sunflower,
  DateTime? plantedAt,
  Duration sessionDuration = const Duration(minutes: 25),
  GardenPlot? plot = const GardenPlot(0, 0),
}) =>
    Plant(
      id: id,
      sessionId: sessionId,
      type: type,
      species: species,
      stage: GrowthStage.mature,
      plantedAt: plantedAt ?? _anchor,
      sessionDuration: sessionDuration,
      plot: plot,
    );

void main() {
  late AppDatabase database;
  late DriftPlantRepository repository;

  setUp(() {
    database = AppDatabase.forTesting();
    repository = DriftPlantRepository(database);
  });

  tearDown(() => database.close());

  test('a saved plant comes back whole', () async {
    await repository.save(_plant());

    final stored = (await repository.plants()).single;
    expect(stored, _plant(), reason: 'every field round-trips');
  });

  test('the enums survive the round trip as themselves', () async {
    // PRD §4.3: stored as text, mapped at the boundary. The point of the test
    // is that no raw string reaches the domain.
    for (final species in PlantSpecies.values) {
      await repository.save(
        _plant(
          id: species.name,
          sessionId: 'session-${species.name}',
          type: species.type,
          species: species,
        ),
      );
    }

    final stored = await repository.plants();
    expect(
      stored.map((plant) => plant.species).toSet(),
      PlantSpecies.values.toSet(),
    );
    expect(
      stored.every((plant) => plant.species.type == plant.type),
      isTrue,
    );
  });

  test('plants come back most recently planted first', () async {
    await repository.save(_plant(id: 'older', sessionId: 'a'));
    await repository.save(
      _plant(
        id: 'newer',
        sessionId: 'b',
        plantedAt: _anchor.add(const Duration(days: 1)),
      ),
    );

    expect(
      (await repository.plants()).map((plant) => plant.id),
      ['newer', 'older'],
    );
  });

  test('saving the same plant twice leaves one plant', () async {
    await repository.save(_plant());
    await repository.save(_plant(species: PlantSpecies.tulip));

    final stored = await repository.plants();
    expect(stored, hasLength(1));
    expect(stored.single.species, PlantSpecies.tulip);
  });

  test('a session can be asked whether it has already been planted', () async {
    expect(await repository.plantForSession('session-1'), isNull);

    await repository.save(_plant());

    expect((await repository.plantForSession('session-1'))!.id, 'plant-1');
    expect(await repository.plantForSession('session-2'), isNull);
  });

  test('a plant with no session is still a plant', () async {
    // Ticket 13's milestone plants are earned by a count of sessions rather
    // than by any one of them.
    await repository.save(_plant(sessionId: null));

    expect((await repository.plants()).single.sessionId, isNull);
  });

  test('planted dates come back in UTC', () async {
    // Drift stores instants as zone-free Unix seconds. A local DateTime going
    // in has to come back as the same moment, in UTC.
    final local = DateTime(2026, 3, 29, 1, 30);
    await repository.save(_plant(plantedAt: local));

    final stored = (await repository.plants()).single.plantedAt;
    expect(stored.isUtc, isTrue);
    expect(stored, local.toUtc());
  });

  group('plots', () {
    test('a plant comes back standing where it was planted', () async {
      await repository.save(_plant(plot: const GardenPlot(-3, 5)));

      expect((await repository.plants()).single.plot, const GardenPlot(-3, 5));
    });

    test('a plant the garden had no room for comes back without one', () async {
      // The 201st plant: recorded, and recorded as unplaced rather than as
      // standing at the origin on top of the first plant the user ever grew.
      await repository.save(_plant(plot: null));

      expect((await repository.plants()).single.plot, isNull);
    });

    test('the occupied plots are the plots with something in them', () async {
      await repository.save(
        _plant(id: 'a', sessionId: 'a', plot: const GardenPlot(0, 0)),
      );
      await repository.save(
        _plant(id: 'b', sessionId: 'b', plot: const GardenPlot(2, -1)),
      );
      await repository.save(_plant(id: 'c', sessionId: 'c', plot: null));

      expect(
        await repository.occupiedPlots(),
        {const GardenPlot(0, 0), const GardenPlot(2, -1)},
      );
    });

    test('an empty garden has nothing occupied', () async {
      expect(await repository.occupiedPlots(), isEmpty);
    });
  });

  test('a session length that is not whole minutes survives', () async {
    await repository.save(
      _plant(sessionDuration: const Duration(minutes: 12, seconds: 30)),
    );

    expect(
      (await repository.plants()).single.sessionDuration,
      const Duration(minutes: 12, seconds: 30),
    );
  });
}
