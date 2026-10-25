import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';

/// REQ-040's arrangement, over a real table.
///
/// What is under test is the round trip and the two rules the table itself
/// enforces: one thing to a plot, and a row this build cannot read is a row it
/// leaves alone rather than one it guesses at.
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

  testWidgets('an item goes in and comes back the same item', (tester) async {
    await arrangement.save(item(DecorKind.birdbath, const GardenPlot(1, -2)));

    final standing = await arrangement.decor();
    expect(standing.single.id, 'item');
    expect(standing.single.kind, DecorKind.birdbath);
    expect(standing.single.plot, const GardenPlot(1, -2));
    expect(standing.single.placedAt, placed);
    expect(standing.single.placedAt.isUtc, isTrue);
  });

  testWidgets('an arrangement comes back in the order it was arranged',
      (tester) async {
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

  testWidgets('moving an item is the same item somewhere else', (tester) async {
    final bench = item(DecorKind.bench, const GardenPlot(0, 0));
    await arrangement.save(bench);
    await arrangement.save(bench.movedTo(const GardenPlot(3, 1)));

    final standing = await arrangement.decor();
    expect(standing, hasLength(1), reason: 'a move is not a second bench');
    expect(standing.single.plot, const GardenPlot(3, 1));
    expect(standing.single.placedAt, placed);
  });

  testWidgets('removing one takes it out and leaves the rest', (tester) async {
    await arrangement
        .save(item(DecorKind.lantern, const GardenPlot(0, 0), id: 'a'));
    await arrangement
        .save(item(DecorKind.pond, const GardenPlot(1, 0), id: 'b'));

    await arrangement.remove('a');

    expect((await arrangement.decor()).map((i) => i.id), ['b']);
  });

  testWidgets('removing something that is not there is not an error',
      (tester) async {
    await arrangement.remove('never-placed');
    expect(await arrangement.decor(), isEmpty);
  });

  testWidgets('a plot can be cleared without knowing what is in it',
      (tester) async {
    // What a completed session displacing an object has: the plot it is taking,
    // and no id. See ADR 0017.
    await arrangement
        .save(item(DecorKind.lantern, const GardenPlot(2, 2), id: 'a'));
    await arrangement
        .save(item(DecorKind.pond, const GardenPlot(0, 0), id: 'b'));

    await arrangement.removeIn(const GardenPlot(2, 2));

    expect((await arrangement.decor()).map((i) => i.id), ['b']);
  });

  testWidgets('the plots it is standing in are the plots it reports',
      (tester) async {
    await arrangement
        .save(item(DecorKind.lantern, const GardenPlot(2, 2), id: 'a'));
    await arrangement
        .save(item(DecorKind.bench, const GardenPlot(-1, 0), id: 'b'));

    expect(
      await arrangement.occupiedPlots(),
      {const GardenPlot(2, 2), const GardenPlot(-1, 0)},
    );
  });

  testWidgets('two things cannot stand in one plot', (tester) async {
    // The database's rule rather than the caller's. Two taps racing each other
    // would both read the same empty plot, and only the table is in a position
    // to refuse the second write.
    await arrangement
        .save(item(DecorKind.lantern, const GardenPlot(0, 0), id: 'a'));

    await expectLater(
      arrangement.save(item(DecorKind.pond, const GardenPlot(0, 0), id: 'b')),
      throwsA(anything),
    );
    expect((await arrangement.decor()).single.id, 'a');
  });

  testWidgets('a kind written by a later build is left standing in the table '
      'and not drawn', (tester) async {
    // Written as a raw row, because no build of this app could produce one. The
    // garden opens, the objects it understands are all there, and the row it
    // cannot read is neither guessed at nor deleted — the build that knows what
    // a gazebo is will find it.
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
      reason: 'the row is still there for the build that can read it',
    );
    // And its plot is still spoken for, so nothing this build places lands on
    // top of it.
    expect(await arrangement.occupiedPlots(), contains(const GardenPlot(4, 4)));
  });

  testWidgets('an instant goes in local and comes back UTC', (tester) async {
    // Drift keeps a `DateTime` column as Unix seconds, which carry no zone, so
    // the mapping is the only thing that guarantees the two ends agree. The
    // same claim `drift_session_repository.dart` makes about an anchor.
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
