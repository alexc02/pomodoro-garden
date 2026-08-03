import 'decor.dart';
import 'garden_plot.dart';

/// Stores decor. Separate from [PlantRepository] since decor moves and plants
/// don't.
abstract interface class DecorRepository {
  /// In placement order.
  Future<List<Decor>> decor();

  /// Upsert by id, so moving is the same write with a new plot. Should refuse
  /// a second item in an occupied plot.
  Future<void> save(Decor item);

  /// No-op for an unknown id.
  Future<void> remove(String id);

  /// Removes whatever is in [plot]; no-op if empty. Used by [GardenPlots.sow]
  /// when a session displaces decor and only knows the plot.
  Future<void> removeIn(GardenPlot plot);

  Future<Set<GardenPlot>> occupiedPlots();
}
