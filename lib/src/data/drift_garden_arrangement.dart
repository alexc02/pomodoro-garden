import 'package:drift/drift.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [GardenArrangement] over SQLite: one transaction across `plants` and
/// `decor`, so a swap can't land half-done.
final class DriftGardenArrangement implements GardenArrangement {
  const DriftGardenArrangement(this._database);

  final AppDatabase _database;

  @override
  Future<void> exchange(GardenPlot a, GardenPlot b) async {
    if (a == b) return;

    await _database.transaction(() async {
      // Read both sides before writing anything, or the second read sees
      // what the first write moved in.
      final plantsInA = await _plantsIn(a);
      final plantsInB = await _plantsIn(b);
      final decorInA = await _decorIn(a);
      final decorInB = await _decorIn(b);

      // `plants` has no index on the plot, so these can't collide.
      await _plant(plantsInA, b);
      await _plant(plantsInB, a);

      // `decor` has a unique index on the plot, checked row by row, so two
      // updates can't swap two items. Take one out first.
      if (decorInA != null) {
        await _database.delete(_database.gardenDecor).delete(decorInA);
      }
      if (decorInB != null) await _stand(decorInB, a);
      if (decorInA != null) {
        await _database.into(_database.gardenDecor).insert(
              decorInA.copyWith(plotX: b.x, plotY: b.y),
            );
      }
    });
  }

  @override
  Future<void> shelve(String plantId) {
    return (_database.update(_database.plants)
          ..where((row) => row.id.equals(plantId)))
        .write(
      const PlantsCompanion(plotX: Value(null), plotY: Value(null)),
    );
  }

  @override
  Future<bool> replant(String plantId, GardenPlot plot) async {
    if (GardenPlots.orderOf(plot) == null) return false;

    return _database.transaction(() async {
      final row = await (_database.select(_database.plants)
            ..where((row) => row.id.equals(plantId)))
          .getSingleOrNull();
      if (row == null) return false;

      // `Plant.isShelved`, but on the raw row, so it works for a species
      // this build doesn't know.
      final (x, y) = (row.plotX, row.plotY);
      if (x != null && y != null) {
        if (GardenPlots.orderOf(GardenPlot(x, y)) != null) return false;
      }

      if ((await _plantsIn(plot)).isNotEmpty) return false;
      if (await _decorIn(plot) != null) return false;

      await _plant([plantId], plot);
      return true;
    });
  }

  /// Ids, since only the plot changes. A list because the schema doesn't stop
  /// two plants sharing a plot, and if they do they move together.
  Future<List<String>> _plantsIn(GardenPlot plot) {
    final query = _database.select(_database.plants)
      ..where((row) => row.plotX.equals(plot.x) & row.plotY.equals(plot.y));

    return query.map((row) => row.id).get();
  }

  /// The raw row rather than a [Decor], so a kind this build doesn't know
  /// still gets moved instead of blocking the plot.
  Future<DecorRow?> _decorIn(GardenPlot plot) {
    final query = _database.select(_database.gardenDecor)
      ..where((row) => row.plotX.equals(plot.x) & row.plotY.equals(plot.y));

    return query.getSingleOrNull();
  }

  Future<void> _plant(List<String> ids, GardenPlot plot) async {
    if (ids.isEmpty) return;

    await (_database.update(_database.plants)
          ..where((row) => row.id.isIn(ids)))
        .write(PlantsCompanion(plotX: Value(plot.x), plotY: Value(plot.y)));
  }

  Future<void> _stand(DecorRow item, GardenPlot plot) {
    return (_database.update(_database.gardenDecor)
          ..where((row) => row.id.equals(item.id)))
        .write(
      GardenDecorCompanion(plotX: Value(plot.x), plotY: Value(plot.y)),
    );
  }
}
