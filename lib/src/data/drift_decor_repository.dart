import 'package:drift/drift.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [DecorRepository] over SQLite.
final class DriftDecorRepository implements DecorRepository {
  const DriftDecorRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> save(Decor item) {
    return _database.into(_database.gardenDecor).insertOnConflictUpdate(
          DecorRow(
            id: item.id,
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
      // id as tiebreaker so the order is stable.
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

/// Null for a kind this build doesn't know (written by a newer one). The row
/// stays in the table; we just skip it rather than draw a substitute.
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
