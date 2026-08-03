import 'garden_plot.dart';

/// Decor the user can place in an empty plot. All free, no inventory.
enum DecorKind {
  lantern(
    'Stone lantern',
    'A low lantern, the shape every one of these gardens starts from.',
  ),

  bench(
    'Bench',
    'Somewhere to sit and look at what you have grown.',
  ),

  birdbath(
    'Birdbath',
    'A shallow basin on a stem, catching whatever the sky is doing.',
  ),

  /// Fills its plot instead of standing on it.
  pond(
    'Pond',
    'A still pool set into the ground, level with the soil around it.',
  ),
  ;

  const DecorKind(this.label, this.blurb);

  /// Also the screen reader label.
  final String label;

  /// Shown under the name in the picker.
  final String blurb;

  /// Null for unknown names (no fallback, unlike `GardenTheme.named`): better
  /// to skip an item from a newer build than draw the wrong one.
  static DecorKind? named(String name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// One decor item in one plot.
///
/// Unlike [Plant], [plot] is never null: decor with no room is just gone,
/// while plants are kept.
final class Decor {
  const Decor({
    required this.id,
    required this.kind,
    required this.plot,
    required this.placedAt,
  });

  /// Stable across moves.
  final String id;

  final DecorKind kind;

  final GardenPlot plot;

  /// UTC. Not shown; gives a stable order.
  final DateTime placedAt;

  Decor movedTo(GardenPlot plot) => Decor(
        id: id,
        kind: kind,
        plot: plot,
        placedAt: placedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Decor &&
      other.id == id &&
      other.kind == kind &&
      other.plot == plot &&
      other.placedAt == placedAt;

  @override
  int get hashCode => Object.hash(id, kind, plot, placedAt);

  @override
  String toString() => 'Decor($id, ${kind.name}, $plot)';
}
