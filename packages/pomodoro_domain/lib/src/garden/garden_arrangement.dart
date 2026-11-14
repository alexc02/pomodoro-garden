import 'garden_plot.dart';

/// Moves what's already in the garden from plot to plot, and plants between
/// the garden and the shelf. Plants and decor alike, which is why this isn't
/// on [PlantRepository] or [DecorRepository]: a plant trading places with a
/// bench is one write across both.
abstract interface class GardenArrangement {
  /// Trades the contents of [a] and [b], whatever they are, all or nothing.
  /// An empty plot trades too, so a move is an exchange with empty soil.
  ///
  /// Works from what's in the plots when it runs, not from what the caller
  /// last saw. Exchanging a plot with itself, or two empty plots, does
  /// nothing.
  Future<void> exchange(GardenPlot a, GardenPlot b);

  /// Takes the plant out of its plot and onto the shelf. The plot is left
  /// empty. Nothing else about the plant changes, and shelving one that's
  /// already there (or isn't anywhere) does nothing.
  Future<void> shelve(String plantId);

  /// Stands a shelved plant in [plot], all or nothing.
  ///
  /// Like [exchange], works from what's stored when it runs: it does nothing
  /// if the plant is already planted, or if [plot] is outside the garden or
  /// holds a plant or decor. Coming off the shelf never displaces anything.
  ///
  /// True if the plant was planted. Callers need to know: two taps on the
  /// same button are two calls, and only one of them moved a plant.
  Future<bool> replant(String plantId, GardenPlot plot);
}
