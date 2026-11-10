import 'package:drift/drift.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [PlantRepository] over SQLite.
final class DriftPlantRepository implements PlantRepository {
  const DriftPlantRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> save(Plant plant) {
    return _database.into(_database.plants).insertOnConflictUpdate(
          PlantRow(
            id: plant.id,
            sessionId: plant.sessionId,
            // By name, so adding enum members can't repoint stored plants.
            type: plant.type.name,
            species: plant.species.name,
            // Stage is the exception: a fixed ordered scale, and the ordinal
            // keeps stage comparisons possible in SQL.
            growthStage: plant.stage.index,
            plantedAt: plant.plantedAt.toUtc(),
            sessionDurationSeconds: plant.sessionDuration?.inSeconds,
            milestoneSessions: plant.milestone?.sessions,
            plotX: plant.plot?.x,
            plotY: plant.plot?.y,
            // Nulls written out, so saving a plant with no plot clears it.
          ).toCompanion(false),
        );
  }

  @override
  Future<List<Plant>> plants() async {
    final query = _database.select(_database.plants)
      ..orderBy([(row) => OrderingTerm.desc(row.plantedAt)]);

    return (await query.get()).map(plantFromRow).toList();
  }

  @override
  Future<Plant?> plantForSession(String sessionId) async {
    final query = _database.select(_database.plants)
      ..where((row) => row.sessionId.equals(sessionId))
      ..limit(1);

    final row = await query.getSingleOrNull();
    return row == null ? null : plantFromRow(row);
  }

  @override
  Future<Set<Milestone>> awardedMilestones() async {
    final query = _database.selectOnly(_database.plants)
      ..addColumns([_database.plants.milestoneSessions])
      ..where(_database.plants.milestoneSessions.isNotNull());

    return {
      for (final row in await query.get())
        // Unknown counts (from a newer build) are skipped so the db still
        // opens. The unique index still prevents a duplicate award.
        ?Milestone.withSessions(row.read(_database.plants.milestoneSessions)!),
    };
  }

  @override
  Future<Set<GardenPlot>> occupiedPlots() async {
    final query = _database.selectOnly(_database.plants)
      ..addColumns([_database.plants.plotX, _database.plants.plotY])
      ..where(_database.plants.plotX.isNotNull());

    return {
      for (final row in await query.get())
        GardenPlot(
          row.read(_database.plants.plotX)!,
          row.read(_database.plants.plotY)!,
        ),
    };
  }
}

/// Row to [Plant]. Top-level so `drift_journal_repository.dart` shares it.
Plant plantFromRow(PlantRow row) => Plant(
      id: row.id,
      sessionId: row.sessionId,
      type: PlantType.values.byName(row.type),
      species: PlantSpecies.values.byName(row.species),
      // Clamped in case a newer build added stages.
      stage: GrowthStage
          .values[row.growthStage.clamp(0, GrowthStage.values.length - 1)],
      plantedAt: row.plantedAt.toUtc(),
      sessionDuration: row.sessionDurationSeconds == null
          ? null
          : Duration(seconds: row.sessionDurationSeconds!),
      // Null for an unknown count, as in [awardedMilestones].
      milestone: row.milestoneSessions == null
          ? null
          : Milestone.withSessions(row.milestoneSessions!),
      // Half a plot is treated as none, not as 0.
      plot: row.plotX == null || row.plotY == null
          ? null
          : GardenPlot(row.plotX!, row.plotY!),
    );
