import 'decor.dart';
import 'garden_plot.dart';

/// Where the user's arrangement is kept.
///
/// A port beside [PlantRepository] rather than a method on it, because the two
/// tables answer to different rules: a plant is written once and never moved,
/// and a decor item exists to be moved and removed.
abstract interface class DecorRepository {
  /// Every item in the garden, in the order it was placed.
  Future<List<Decor>> decor();

  /// Writes [item], replacing any earlier version of *that* item.
  ///
  /// An upsert on the item's own id, so placing is a write and moving is the
  /// same write with a different plot. An implementation is expected to refuse
  /// a second item in a plot that already holds one — a plot holds one thing.
  Future<void> save(Decor item);

  /// Takes the item with this id out of the garden.
  ///
  /// Silent about an id that is not there: removing something twice is the same
  /// request twice, and the second one has nothing to fail at.
  Future<void> remove(String id);

  /// Takes whatever is standing in [plot] out of the garden.
  ///
  /// By plot rather than by id because the one caller that needs it does not
  /// have an id: a completed session displacing an object knows only which plot
  /// it is taking — see [GardenPlots.sow] — and reading the whole arrangement
  /// back to find out what was standing there would be a query to answer a
  /// question the delete can answer itself.
  ///
  /// Silent about a plot with nothing in it, on the same terms [remove] is.
  Future<void> removeIn(GardenPlot plot);

  /// Every plot an item is standing in.
  ///
  /// What [GardenPlots.sow] needs, and the same shape [PlantRepository]'s own
  /// `occupiedPlots` has: sowing a seed must not have to read the whole
  /// arrangement to find out which plots are spoken for.
  Future<Set<GardenPlot>> occupiedPlots();
}
