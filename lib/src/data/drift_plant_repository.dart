import 'package:drift/drift.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [PlantRepository] over SQLite.
///
/// All the translation between the domain's [Plant] and the stored row lives
/// here, so the domain never sees a column and the database never sees an enum.
final class DriftPlantRepository implements PlantRepository {
  const DriftPlantRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> save(Plant plant) {
    return _database.into(_database.plants).insertOnConflictUpdate(
          PlantRow(
            id: plant.id,
            sessionId: plant.sessionId,
            // Type and species go in by name — PRD §4.3's "stored as text and
            // mapped at the repository boundary". An ordinal would silently
            // repoint every stored plant the day a member is inserted into the
            // middle of one of those enums, and both are open lists that ticket
            // 13 and ticket 23 will add to.
            type: plant.type.name,
            species: plant.species.name,
            // The stage is the exception, and §4.3 asks for it as `int (0–4)`:
            // the five stages are a closed, ordered scale that nothing will
            // insert into the middle of, and storing the ordinal keeps
            // "further along than" answerable in SQL for ticket 15's journal.
            growthStage: plant.stage.index,
            plantedAt: plant.plantedAt.toUtc(),
            sessionDurationSeconds: plant.sessionDuration?.inSeconds,
            // REQ-021: the count, which is the milestone's stored identity.
            // Null for every plant a session grew, and the column's unique
            // index is what makes a second award of the same milestone a write
            // the database refuses rather than a duplicate in the garden.
            milestoneSessions: plant.milestone?.sessions,
            // The two go in together or not at all: half a plot is not a
            // position, and [plantFromRow] reads them back the same way.
            plotX: plant.plot?.x,
            plotY: plant.plot?.y,
          ),
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
        // A stored count this build has no milestone for is dropped rather than
        // thrown on, so a database written by a later version still opens. What
        // it costs is that this build would award its own milestone at that
        // count — and the unique index is what stops the write, so the garden
        // is still never doubled.
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

/// One stored row, as the plant it records.
///
/// A function rather than a method on [DriftPlantRepository], because the
/// journal reads the plants a week grew out of the same table
/// (`drift_journal_repository.dart`) and a second copy of this mapping is a
/// second answer to "what is a plant from the future". There is one reader of a
/// plant row in this app, and this is it.
Plant plantFromRow(PlantRow row) => Plant(
      id: row.id,
      sessionId: row.sessionId,
      type: PlantType.values.byName(row.type),
      species: PlantSpecies.values.byName(row.species),
      // Clamped rather than indexed blindly: a row written by a build with
      // more stages than this one has is a row from the future, and the
      // nearest stage this build knows about is a better answer than a range
      // error that takes the whole garden down.
      stage: GrowthStage
          .values[row.growthStage.clamp(0, GrowthStage.values.length - 1)],
      plantedAt: row.plantedAt.toUtc(),
      sessionDuration: row.sessionDurationSeconds == null
          ? null
          : Duration(seconds: row.sessionDurationSeconds!),
      // Null when the count is one this build does not recognise, on the same
      // terms [awardedMilestones] drops it: a plant that cannot say what
      // earned it still draws, and a garden that would not open does not.
      milestone: row.milestoneSessions == null
          ? null
          : Milestone.withSessions(row.milestoneSessions!),
      // A row with only one of the two written is a row nothing in this app
      // could have produced; read as no plot rather than as a plot at zero,
      // which would stack it on top of whatever is in the middle.
      plot: row.plotX == null || row.plotY == null
          ? null
          : GardenPlot(row.plotX!, row.plotY!),
    );
