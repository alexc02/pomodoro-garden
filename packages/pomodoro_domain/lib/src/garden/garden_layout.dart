import 'decor.dart';
import 'garden_plot.dart';
import 'plant.dart';

/// The garden as it stands: which plots it has, and what is in each.
///
/// Computed from the plants and the decor on disk and the count of completed
/// sessions, all of which are already stored — nothing here is a second copy of
/// any of them. Every launch recomputes it, and every launch gets the same
/// answer, because a plant and a decor item each carry the plot they stand in.
///
/// This is where REQ-018's unlock schedule and the things actually in the
/// ground are reconciled. The schedule unlocks four plots per ten sessions and
/// sessions earn a plant apiece, so from the twenty-first completed session on
/// there are more plants than unlocked plots. The unlock count is therefore a
/// floor and not a ceiling: it is how much *empty* soil the garden shows, and
/// the garden is never smaller than what is standing in it. See
/// `docs/adr/0006-the-garden-has-a-plot-for-every-plant-it-can-hold.md`.
///
/// **Decor expands the garden the same way a plant does**, and that is REQ-040's
/// "expanding capacity" in one line: an item placed in the outermost plot the
/// garden had keeps that plot in the garden for good, whatever the schedule
/// says. It cannot be used to reach *past* the schedule — the picker only ever
/// offers plots the garden already has — but it can hold open one it has
/// already unlocked, which is what stops an arrangement from disappearing.
final class GardenLayout {
  /// Positional, because a named parameter cannot be private and the two
  /// indexes are lookups rather than part of this type's shape.
  const GardenLayout._(
    this._planting,
    this._decorating,
    this._plots, {
    required this.plots,
    required this.plants,
    required this.decor,
    required this.bonusPlants,
    required this.unplaced,
  });

  /// The garden that [plants], [decor] and [completedSessions] describe.
  factory GardenLayout.of({
    required List<Plant> plants,
    required int completedSessions,
    List<Decor> decor = const [],
  }) {
    final planting = <GardenPlot, Plant>{};
    final unplaced = <Plant>[];
    // How far out into the placement order the things in the ground actually
    // reach. The garden is never smaller than this, whatever the unlock
    // schedule says.
    var reach = 0;

    for (final plant in plants) {
      final plot = plant.plot;
      final order = plot == null ? null : GardenPlots.orderOf(plot);
      if (plot == null || order == null) {
        unplaced.add(plant);
        continue;
      }
      planting[plot] = plant;
      if (order + 1 > reach) reach = order + 1;
    }

    final decorating = <GardenPlot, Decor>{};
    for (final item in decor) {
      final order = GardenPlots.orderOf(item.plot);
      // Two rows this app could not have written, dropped rather than drawn:
      // an item outside the two hundred, and an item in a plot a plant is
      // standing in. Placement checks both before writing, and `sow` moves an
      // item out of a plant's way rather than under it — so reaching here means
      // a row from somewhere else. The plant wins, because a plant is a session
      // somebody sat through and an item is a decision that can be made again.
      if (order == null || planting.containsKey(item.plot)) continue;
      decorating[item.plot] = item;
      if (order + 1 > reach) reach = order + 1;
    }

    var count = GardenPlots.unlockedAfter(completedSessions);
    if (reach > count) count = reach;
    if (count > GardenPlots.maximum) count = GardenPlots.maximum;

    final ordered = GardenPlots.inPlacementOrder.take(count).toList()
      // Back to front. The painter walks this list in order and the last thing
      // drawn is the nearest one, which is what makes a tree in the front row
      // overlap the one behind it rather than the other way round. Ties are
      // broken by x only to keep the list identical between two runs; plots at
      // the same depth sit in the same row on screen and cannot overlap.
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
      unplaced: List.unmodifiable(unplaced),
    );
  }

  /// Every plot the garden has, furthest from the viewer first — the order they
  /// are drawn in.
  final List<GardenPlot> plots;

  /// Every plant standing in one of those plots.
  final List<Plant> plants;

  /// Every decor item standing in one of them: REQ-040.
  ///
  /// A list of its own rather than folded into [plants], because nothing that
  /// counts a garden counts these. An item is not a session anybody sat
  /// through, it earns no card, and the sentence the garden says about itself
  /// is about what was *grown* — so the two are kept apart here for the same
  /// reason [bonusPlants] is kept apart from the sessions.
  final List<Decor> decor;

  /// The subset of [plants] a milestone awarded rather than a session grew:
  /// REQ-021.
  ///
  /// Kept apart because the two are counted for different reasons. A garden
  /// says how much is growing in it; a *statistic* says how much work was done,
  /// and a bonus plant is not any. Everything that counts sessions in this app
  /// counts the `sessions` table, so nothing has to subtract these — this list
  /// exists so the garden can name them, not so a count can exclude them.
  final List<Plant> bonusPlants;

  /// The plants the garden has no plot for.
  ///
  /// Empty until a user has two hundred plants, and never emptied afterwards: a
  /// plant past the cap is still a session somebody sat through, so it is kept
  /// and counted rather than dropped. ADR 0006 says what the garden does with
  /// them, and ADR 0017 says why decor can never add to this list.
  final List<Plant> unplaced;

  final Map<GardenPlot, Plant> _planting;
  final Map<GardenPlot, Decor> _decorating;
  final Set<GardenPlot> _plots;

  /// How many plots the garden has.
  int get plotCount => plots.length;

  /// How many of them are bare soil: no plant, and nothing standing on them.
  ///
  /// Decor is subtracted because the number is only ever asked as *where could
  /// something go* — the picker's empty plots, and the room the garden has
  /// left. A plot with a bench in it is not somewhere anything can be put.
  int get emptyPlots => plots.length - plants.length - decor.length;

  /// Whether the garden has run out of plots to unlock.
  bool get isFull => plots.length >= GardenPlots.maximum;

  /// Whether the garden has [plot] at all, as opposed to it being a plot of the
  /// infinite grid the garden has not unlocked.
  ///
  /// What separates ticket 12's two "does nothing" cases — bare soil the garden
  /// has, and ground it does not — now that one of them is somewhere a user can
  /// put a lantern and the other is not.
  bool hasPlot(GardenPlot plot) => _plots.contains(plot);

  /// What is growing in [plot], or null if nothing is.
  Plant? plantIn(GardenPlot plot) => _planting[plot];

  /// What is standing in [plot], or null if nothing is.
  Decor? decorIn(GardenPlot plot) => _decorating[plot];

  /// Whether [plot] is a plot of this garden with nothing in it at all.
  ///
  /// The picker's question, asked in one place so that "empty" means the same
  /// thing to the screen offering a plot and to the rule writing into it.
  bool isEmpty(GardenPlot plot) =>
      hasPlot(plot) && plantIn(plot) == null && decorIn(plot) == null;
}
