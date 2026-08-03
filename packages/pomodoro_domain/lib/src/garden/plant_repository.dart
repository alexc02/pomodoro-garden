import 'garden_plot.dart';
import 'milestone.dart';
import 'plant.dart';

/// Stores plants. The app implements it with SQLite.
abstract interface class PlantRepository {
  /// Upsert by plant id. Doesn't stop two plants for one session by itself;
  /// callers check [plantForSession] and the implementation should refuse a
  /// duplicate.
  Future<void> save(Plant plant);

  /// Most recent first.
  Future<List<Plant>> plants();

  /// Null if the session hasn't been planted. Used to record a completion
  /// only once.
  Future<Plant?> plantForSession(String sessionId);

  /// Milestones that already have a plant. The garden is the record, which
  /// keeps awarding idempotent (see [Milestone.dueFrom]). Unknown stored
  /// milestones are skipped rather than throwing.
  Future<Set<Milestone>> awardedMilestones();

  /// For [GardenPlots.nextFree], without loading every plant.
  Future<Set<GardenPlot>> occupiedPlots();
}
