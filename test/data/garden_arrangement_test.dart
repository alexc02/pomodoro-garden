import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';
import 'package:pip_garden/src/data/drift_garden_arrangement.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';

// Every pairing of plant, decor and empty soil, against real SQLite: the
// decor table's unique plot index is half of what this has to get right.

void main() {
  late AppDatabase database;
  late DriftGardenArrangement arrangement;
  late DriftPlantRepository plants;
  late DriftDecorRepository decor;

  final DateTime anchor = DateTime.utc(2026, 8, 26, 12, 30);

  const here = GardenPlot(0, 0);
  const there = GardenPlot(2, -1);
  const elsewhere = GardenPlot(-3, 1);

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
    arrangement = DriftGardenArrangement(database);
    plants = DriftPlantRepository(database);
    decor = DriftDecorRepository(database);
  });

  Future<Plant> plant(String id, GardenPlot? plot) async {
    final planted = Plant(
      id: id,
      sessionId: 'session-$id',
      type: PlantType.largeTree,
      species: PlantSpecies.oak,
      stage: GrowthStage.mature,
      plantedAt: anchor,
      sessionDuration: const Duration(minutes: 90),
      plot: plot,
    );
    await plants.save(planted);
    return planted;
  }

  Future<Decor> stand(String id, DecorKind kind, GardenPlot plot) async {
    final item = Decor(id: id, kind: kind, plot: plot, placedAt: anchor);
    await decor.save(item);
    return item;
  }

  Future<Map<String, GardenPlot?>> plantPlots() async =>
      {for (final plant in await plants.plants()) plant.id: plant.plot};

  Future<Map<String, GardenPlot>> decorPlots() async =>
      {for (final item in await decor.decor()) item.id: item.plot};

  group('moving to empty soil', () {
    testWidgets('a plant', (tester) async {
      final oak = await plant('oak', here);

      await arrangement.exchange(here, there);

      // Everything but the plot is untouched.
      expect(await plants.plants(), [oak.inPlot(there)]);
    });

    testWidgets('decor', (tester) async {
      final bench = await stand('bench', DecorKind.bench, here);

      await arrangement.exchange(here, there);

      expect(await decor.decor(), [bench.movedTo(there)]);
    });

    testWidgets('works from either end', (tester) async {
      await plant('oak', here);

      // The empty plot named first.
      await arrangement.exchange(there, here);

      expect(await plantPlots(), {'oak': there});
    });
  });

  group('swapping', () {
    testWidgets('two plants', (tester) async {
      await plant('oak', here);
      await plant('elm', there);

      await arrangement.exchange(here, there);

      expect(await plantPlots(), {'oak': there, 'elm': here});
    });

    testWidgets('two decor items, despite the unique plot', (tester) async {
      final bench = await stand('bench', DecorKind.bench, here);
      final pond = await stand('pond', DecorKind.pond, there);

      await arrangement.exchange(here, there);

      expect(
        await decor.decor(),
        unorderedEquals([bench.movedTo(there), pond.movedTo(here)]),
      );
    });

    testWidgets('a plant with decor', (tester) async {
      await plant('oak', here);
      await stand('bench', DecorKind.bench, there);

      await arrangement.exchange(here, there);

      expect(await plantPlots(), {'oak': there});
      expect(await decorPlots(), {'bench': here});
    });

    testWidgets('decor with a plant', (tester) async {
      await stand('bench', DecorKind.bench, here);
      await plant('oak', there);

      await arrangement.exchange(here, there);

      expect(await plantPlots(), {'oak': here});
      expect(await decorPlots(), {'bench': there});
    });

    testWidgets('twice puts everything back', (tester) async {
      await plant('oak', here);
      await stand('bench', DecorKind.bench, there);

      await arrangement.exchange(here, there);
      await arrangement.exchange(here, there);

      expect(await plantPlots(), {'oak': here});
      expect(await decorPlots(), {'bench': there});
    });
  });

  group('leaves alone', () {
    testWidgets('everything in other plots', (tester) async {
      await plant('oak', here);
      await plant('elm', there);
      await plant('ash', elsewhere);
      await plant('unplaced', null);
      await stand('lantern', DecorKind.lantern, const GardenPlot(4, 4));

      await arrangement.exchange(here, there);

      expect(await plantPlots(), {
        'oak': there,
        'elm': here,
        'ash': elsewhere,
        'unplaced': null,
      });
      expect(await decorPlots(), {'lantern': const GardenPlot(4, 4)});
    });

    testWidgets('a plot exchanged with itself', (tester) async {
      await plant('oak', here);
      await stand('bench', DecorKind.bench, there);

      await arrangement.exchange(here, here);
      await arrangement.exchange(there, there);

      expect(await plantPlots(), {'oak': here});
      expect(await decorPlots(), {'bench': there});
    });

    testWidgets('two empty plots', (tester) async {
      await plant('oak', elsewhere);

      await arrangement.exchange(here, there);

      expect(await plantPlots(), {'oak': elsewhere});
      expect(await decor.decor(), isEmpty);
    });
  });

  group('shelving', () {
    testWidgets('takes a plant out of its plot and keeps the plant',
        (tester) async {
      final oak = await plant('oak', here);

      await arrangement.shelve('oak');

      expect(await plantPlots(), {'oak': null});
      expect((await plants.plants()).single, oak.inPlot(null));
      expect(await plants.occupiedPlots(), isEmpty);
    });

    testWidgets('leaves every other plant where it stands', (tester) async {
      await plant('oak', here);
      await plant('other', there);
      await stand('bench', DecorKind.bench, elsewhere);

      await arrangement.shelve('oak');

      expect(await plantPlots(), {'oak': null, 'other': there});
      expect(await decorPlots(), {'bench': elsewhere});
    });

    testWidgets('twice, or of a plant that is not there, does nothing',
        (tester) async {
      await plant('oak', here);

      await arrangement.shelve('oak');
      await arrangement.shelve('oak');
      await arrangement.shelve('nobody');

      expect(await plantPlots(), {'oak': null});
    });
  });

  group('replanting', () {
    testWidgets('stands a shelved plant in an empty plot', (tester) async {
      await plant('oak', null);

      expect(await arrangement.replant('oak', there), isTrue);

      expect(await plantPlots(), {'oak': there});
    });

    testWidgets('says so when asked twice, and moves nothing the second time',
        (tester) async {
      await plant('oak', null);

      expect(await arrangement.replant('oak', there), isTrue);
      expect(await arrangement.replant('oak', elsewhere), isFalse);

      expect(await plantPlots(), {'oak': there});
    });

    testWidgets('undoes a shelving exactly', (tester) async {
      final oak = await plant('oak', here);

      await arrangement.shelve('oak');
      await arrangement.replant('oak', here);

      expect((await plants.plants()).single, oak);
    });

    testWidgets('never lands on another plant', (tester) async {
      await plant('oak', null);
      await plant('other', there);

      expect(await arrangement.replant('oak', there), isFalse);

      expect(await plantPlots(), {'oak': null, 'other': there});
    });

    testWidgets('never lands on decor', (tester) async {
      await plant('oak', null);
      await stand('bench', DecorKind.bench, there);

      await arrangement.replant('oak', there);

      expect(await plantPlots(), {'oak': null});
      expect(await decorPlots(), {'bench': there});
    });

    testWidgets('does not move a plant that is already planted',
        (tester) async {
      await plant('oak', here);

      await arrangement.replant('oak', there);

      expect(await plantPlots(), {'oak': here});
    });

    testWidgets('rescues a plant stored outside the garden', (tester) async {
      // A plot from another version: shelved as far as the garden knows.
      await plant('oak', const GardenPlot(50, 50));

      await arrangement.replant('oak', there);

      expect(await plantPlots(), {'oak': there});
    });

    testWidgets('refuses a plot outside the garden', (tester) async {
      await plant('oak', null);

      await arrangement.replant('oak', const GardenPlot(50, 50));
      await arrangement.replant('nobody', there);

      expect(await plantPlots(), {'oak': null});
    });
  });

  testWidgets('moves decor of a kind this build does not know',
      (tester) async {
    // Written by a newer build. `decor()` skips it, but it still holds its
    // plot, so a swap has to carry it rather than collide with it.
    await database.customStatement(
      'INSERT INTO decor (id, kind, plot_x, plot_y, placed_at) '
      "VALUES ('future', 'gazebo', ?, ?, ?)",
      [there.x, there.y, anchor.millisecondsSinceEpoch ~/ 1000],
    );
    await stand('bench', DecorKind.bench, here);

    await arrangement.exchange(here, there);

    expect(await decor.occupiedPlots(), {here, there});
    expect(await decorPlots(), {'bench': there});
    final row = await database
        .customSelect(
          "SELECT kind, plot_x, plot_y FROM decor WHERE id = 'future'",
        )
        .getSingle();
    expect(row.read<String>('kind'), 'gazebo');
    expect(GardenPlot(row.read<int>('plot_x'), row.read<int>('plot_y')), here);
  });
}
