import 'decor.dart';
import 'garden_plot.dart';
import 'plant.dart';

/// The garden as it stands: its plots and what's in each. Recomputed from
/// stored plants, decor and the session count.
///
/// The unlock schedule (4 plots per 10 sessions) falls behind one plant per
/// session after session 20, so the unlocked count is a floor: the garden
/// always grows to fit what's in it. Decor holds a plot open the
/// same way, but can't reach past what's already unlocked.
///
/// It also has a plot for every plant owned, shelved ones included, so moving
/// a plant to the shelf leaves its soil behind instead of shrinking the
/// garden. Decor can still fill that soil; the shelf doesn't reserve it.
final class GardenLayout {
  /// Positional because named params can't be private.
  const GardenLayout._(
    this._planting,
    this._decorating,
    this._plots, {
    required this.plots,
    required this.plants,
    required this.decor,
    required this.bonusPlants,
    required this.shelved,
  });

  factory GardenLayout.of({
    required List<Plant> plants,
    required int completedSessions,
    List<Decor> decor = const [],
  }) {
    final planting = <GardenPlot, Plant>{};
    final shelved = <Plant>[];
    // Furthest placement order anything actually occupies.
    var reach = 0;

    for (final plant in plants) {
      final plot = plant.plot;
      if (plot == null || plant.isShelved) {
        shelved.add(plant);
        continue;
      }
      planting[plot] = plant;
      final order = GardenPlots.orderOf(plot)!;
      if (order + 1 > reach) reach = order + 1;
    }

    final decorating = <GardenPlot, Decor>{};
    for (final item in decor) {
      final order = GardenPlots.orderOf(item.plot);
      // Drop rows the app wouldn't write: decor outside the 200, or in a plot
      // a plant already has. The plant wins.
      if (order == null || planting.containsKey(item.plot)) continue;
      decorating[item.plot] = item;
      if (order + 1 > reach) reach = order + 1;
    }

    var count = GardenPlots.unlockedAfter(completedSessions);
    if (reach > count) count = reach;
    // Every plant owned, not only the planted ones.
    if (plants.length > count) count = plants.length;
    if (count > GardenPlots.maximum) count = GardenPlots.maximum;

    final ordered = GardenPlots.inPlacementOrder.take(count).toList()
      // Back to front so nearer plants paint over farther ones. x is only a
      // tie-breaker for a stable order.
      ..sort((a, b) {
        final byDepth = a.depth.compareTo(b.depth);
        return byDepth != 0 ? byDepth : a.x.compareTo(b.x);
      });

    return GardenLayout._(
      planting,
      decorating,
      ordered.toSet(),
      plots: List.unmodifiable(ordered),
      plants: List.unmodifiable(planting.values),
      decor: List.unmodifiable(decorating.values),
      bonusPlants:
          List.unmodifiable(planting.values.where((plant) => plant.isBonus)),
      shelved: List.unmodifiable(shelved),
    );
  }

  /// Back to front (draw order).
  final List<GardenPlot> plots;

  final List<Plant> plants;

  /// Kept apart from [plants]: decor doesn't count toward anything.
  final List<Decor> decor;

  /// The milestone plants among [plants].
  final List<Plant> bonusPlants;

  /// Plants on the shelf (see [Plant.isShelved]): moved there by the user, or
  /// grown after all 200 plots were taken. Kept and counted.
  final List<Plant> shelved;

  final Map<GardenPlot, Plant> _planting;
  final Map<GardenPlot, Decor> _decorating;
  final Set<GardenPlot> _plots;

  int get plotCount => plots.length;

  /// Plots with no plant and no decor.
  int get emptyPlots => plots.length - plants.length - decor.length;

  /// No more plots to unlock.
  bool get isFull => plots.length >= GardenPlots.maximum;

  /// False for plots of the grid that aren't unlocked yet.
  bool hasPlot(GardenPlot plot) => _plots.contains(plot);

  Plant? plantIn(GardenPlot plot) => _planting[plot];

  Decor? decorIn(GardenPlot plot) => _decorating[plot];

  /// Unlocked and holding nothing. Shared by the picker and the write path.
  bool isEmpty(GardenPlot plot) =>
      hasPlot(plot) && plantIn(plot) == null && decorIn(plot) == null;
}
