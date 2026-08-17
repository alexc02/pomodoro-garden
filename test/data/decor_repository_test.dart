import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';

void main() {
  late AppDatabase database;
  late DriftDecorRepository arrangement;

  final DateTime placed = DateTime.utc(2026, 8, 26, 12, 30);

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
    arrangement = DriftDecorRepository(database);
  });

  Decor item(
    DecorKind kind,
    GardenPlot plot, {
    String id = 'item',
    Duration after = Duration.zero,
  }) =>
      Decor(id: id, kind: kind, plot: plot, placedAt: placed.add(after));

  testWidgets('round-trips an item', (tester) async {
    await arrangement.save(item(DecorKind.birdbath, const GardenPlot(1, -2)));

    final standing = await arrangement.decor();
    expect(standing.single.id, 'item');
    expect(standing.single.kind, DecorKind.birdbath);
    expect(standing.single.plot, const GardenPlot(1, -2));
    expect(standing.single.placedAt, placed);
    expect(standing.single.placedAt.isUtc, isTrue);
  });

  testWidgets('keeps arrangement order', (tester) async {
    await arrangement.save(item(
      DecorKind.pond,
      const GardenPlot(0, 0),
      id: 'second',
      after: const Duration(minutes: 5),
    ));
    await arrangement.save(
      item(DecorKind.bench, const GardenPlot(1, 0), id: 'first'),
    );

    expect(
      (await arrangement.decor()).map((i) => i.id),
      ['first', 'second'],
    );
  });

  testWidgets('moving an item updates its plot', (tester) async {
    final bench = item(DecorKind.bench, const GardenPlot(0, 0));
    await arrangement.save(bench);
    await arrangement.save(bench.movedTo(const GardenPlot(3, 1)));

    final standing = await arrangement.decor();
    expect(standing, hasLength(1), reason: 'move should not add a row');
    expect(standing.single.plot, const GardenPlot(3, 1));
    expect(standing.single.placedAt, placed);
  });

  testWidgets('remove deletes only that item', (tester) async {
    await arrangement
        .save(item(DecorKind.lantern, const GardenPlot(0, 0), id: 'a'));
    await arrangement
        .save(item(DecorKind.pond, const GardenPlot(1, 0), id: 'b'));

    await arrangement.remove('a');

    expect((await arrangement.decor()).map((i) => i.id), ['b']);
  });

  testWidgets('removing a missing item is a no-op', (tester) async {
    await arrangement.remove('never-placed');
    expect(await arrangement.decor(), isEmpty);
  });

  testWidgets('clears a plot by position', (tester) async {
    // What a session displacing decor has: the plot, no id.
    await arrangement
        .save(item(DecorKind.lantern, const GardenPlot(2, 2), id: 'a'));
    await arrangement
        .save(item(DecorKind.pond, const GardenPlot(0, 0), id: 'b'));

    await arrangement.removeIn(const GardenPlot(2, 2));

    expect((await arrangement.decor()).map((i) => i.id), ['b']);
  });

  testWidgets('reports occupied plots', (tester) async {
    await arrangement
        .save(item(DecorKind.lantern, const GardenPlot(2, 2), id: 'a'));
    await arrangement
        .save(item(DecorKind.bench, const GardenPlot(-1, 0), id: 'b'));

    expect(
      await arrangement.occupiedPlots(),
      {const GardenPlot(2, 2), const GardenPlot(-1, 0)},
    );
  });

  testWidgets('one item per plot', (tester) async {
    // Enforced by the table: two racing taps would both see the plot empty.
    await arrangement
        .save(item(DecorKind.lantern, const GardenPlot(0, 0), id: 'a'));

    await expectLater(
      arrangement.save(item(DecorKind.pond, const GardenPlot(0, 0), id: 'b')),
      throwsA(anything),
    );
    expect((await arrangement.decor()).single.id, 'a');
  });

  testWidgets('unknown kind is kept in the table but not loaded',
      (tester) async {
    // Raw row, since no build can produce one. It must be neither drawn nor
    // deleted.
    await database.into(database.gardenDecor).insert(
          GardenDecorCompanion.insert(
            id: 'from-the-future',
            kind: 'gazebo',
            plotX: 4,
            plotY: 4,
            placedAt: placed,
          ),
        );
    await arrangement
        .save(item(DecorKind.bench, const GardenPlot(0, 0), id: 'mine'));

    expect((await arrangement.decor()).map((i) => i.id), ['mine']);
    expect(
      await database.select(database.gardenDecor).get(),
      hasLength(2),
      reason: 'unknown row should not be deleted',
    );
    // Its plot stays occupied.
    expect(await arrangement.occupiedPlots(), contains(const GardenPlot(4, 4)));
  });

  testWidgets('local instant comes back as UTC', (tester) async {
    // Drift stores DateTime as zone-free Unix seconds.
    await arrangement.save(Decor(
      id: 'local',
      kind: DecorKind.pond,
      plot: const GardenPlot(0, 0),
      placedAt: placed.toLocal(),
    ));

    final read = (await arrangement.decor()).single;
    expect(read.placedAt.isUtc, isTrue);
    expect(read.placedAt, placed);
  });
}
