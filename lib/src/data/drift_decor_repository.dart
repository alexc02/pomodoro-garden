import 'package:drift/drift.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [DecorRepository] over SQLite.
///
/// All the translation between the domain's [Decor] and the stored row lives
/// here, so the domain never sees a column and the database never sees an enum.
final class DriftDecorRepository implements DecorRepository {
  const DriftDecorRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> save(Decor item) {
    return _database.into(_database.gardenDecor).insertOnConflictUpdate(
          DecorRow(
            id: item.id,
            // By name — the same decision [Plants.type] is stored with. An
            // ordinal would silently repoint every item in the garden the day a
            // kind is inserted into the middle of the enum, and ticket 23 may
            // well add one.
            kind: item.kind.name,
            plotX: item.plot.x,
            plotY: item.plot.y,
            placedAt: item.placedAt.toUtc(),
          ),
        );
  }

  @override
  Future<void> remove(String id) {
    return (_database.delete(_database.gardenDecor)
          ..where((row) => row.id.equals(id)))
        .go();
  }

  @override
  Future<void> removeIn(GardenPlot plot) {
    return (_database.delete(_database.gardenDecor)
          ..where((row) =>
              row.plotX.equals(plot.x) & row.plotY.equals(plot.y)))
        .go();
  }

  @override
  Future<List<Decor>> decor() async {
    final query = _database.select(_database.gardenDecor)
      // The order the user arranged them in, and the id under it so that two
      // items placed in the same millisecond still come back the same way
      // round on every read.
      ..orderBy([
        (row) => OrderingTerm.asc(row.placedAt),
        (row) => OrderingTerm.asc(row.id),
      ]);

    return [for (final row in await query.get()) ?_decorFromRow(row)];
  }

  @override
  Future<Set<GardenPlot>> occupiedPlots() async {
    final query = _database.selectOnly(_database.gardenDecor)
      ..addColumns([_database.gardenDecor.plotX, _database.gardenDecor.plotY]);

    return {
      for (final row in await query.get())
        GardenPlot(
          row.read(_database.gardenDecor.plotX)!,
          row.read(_database.gardenDecor.plotY)!,
        ),
    };
  }
}

/// One stored row, as the item it records — or null for a row this build cannot
/// read.
///
/// The only such row is one naming a kind this version has never heard of,
/// written by a later one. Left out rather than thrown on, the same way
/// `awardedMilestones` drops a count it does not recognise: a garden written by
/// a newer build still opens, and the object it cannot draw is still in the
/// table for the build that can.
///
/// Note what this does *not* do: it does not substitute a lantern. A wrong
/// object standing where the user put something else is worse than an empty
/// plot, and unlike a plant, nothing here is a record of work that would be
/// lost by not drawing it.
Decor? _decorFromRow(DecorRow row) {
  final kind = DecorKind.named(row.kind);
  if (kind == null) return null;

  return Decor(
    id: row.id,
    kind: kind,
    plot: GardenPlot(row.plotX, row.plotY),
    placedAt: row.placedAt.toUtc(),
  );
}
