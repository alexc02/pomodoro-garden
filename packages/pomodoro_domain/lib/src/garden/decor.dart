import 'garden_plot.dart';

/// REQ-040's four objects: what the user can stand in an empty plot.
///
/// A closed list, in the domain rather than beside the drawings, because what
/// hangs off it is not a picture: which plots are free for a plant, and what the
/// picker offers. The art is `lib/src/garden/decor_sprite.dart`'s business and
/// arrives through the same registry seam a plant's does.
///
/// **Nothing here is bought, and nothing is spent.** A user may place any
/// number of any of these: there is no inventory to keep and no count to run
/// down, which is why a [Decor] carries no price, no owner and no quantity.
enum DecorKind {
  /// Stone, and the one that reads as a garden from furthest away.
  lantern(
    'Stone lantern',
    'A low lantern, the shape every one of these gardens starts from.',
  ),

  /// The only one a person is implied to use, which is why it is first among
  /// the things a user reaches for when they are arranging rather than filling.
  bench(
    'Bench',
    'Somewhere to sit and look at what you have grown.',
  ),

  /// Water, held up.
  birdbath(
    'Birdbath',
    'A shallow basin on a stem, catching whatever the sky is doing.',
  ),

  /// Water, let into the ground — the widest of the four, and the only one that
  /// fills its plot rather than standing on it.
  pond(
    'Pond',
    'A still pool set into the ground, level with the soil around it.',
  ),
  ;

  const DecorKind(this.label, this.blurb);

  /// What the picker calls this, and what a screen reader reads out.
  final String label;

  /// The line under the name in the picker.
  ///
  /// Carried here for the reason `GardenTheme.blurb` is: nothing describing an
  /// object should have to write its own sentence about it.
  final String blurb;

  /// The kind called [name], or null if this build has never heard of it.
  ///
  /// Null rather than a fallback, and that is the difference between this and
  /// `GardenTheme.named`: a theme is a thing the whole garden is dressed in and
  /// something has to be chosen, whereas an unrecognised decor row is one
  /// object, written by a later build, that this one simply does not draw. A
  /// fallback would put a lantern where the user placed something else.
  static DecorKind? named(String name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// One object standing in one plot: REQ-040.
///
/// **A decor item is a decision, not a record.** A plant is what a session left
/// behind and is kept whatever happens to the garden around it; a lantern is
/// something the user put down and can put somewhere else in two taps. That
/// difference is why this has a [plot] that cannot be null where a [Plant]'s
/// can: a plant the garden has no room for is kept and counted (ADR 0006),
/// where a decor item the garden has no room for is simply not there any more.
/// See `docs/adr/0017-…`.
final class Decor {
  const Decor({
    required this.id,
    required this.kind,
    required this.plot,
    required this.placedAt,
  });

  /// This item's own identity, so that moving it is a move rather than a
  /// removal and a replacement.
  final String id;

  /// Which of the four it is.
  final DecorKind kind;

  /// Where it stands. Never null — see the class comment.
  final GardenPlot plot;

  /// When the user put it down, in UTC.
  ///
  /// Not shown anywhere. It is here because two items have to have an order
  /// that does not change between two reads of the table, and the one honest
  /// order for a set of things somebody arranged is the order they arranged
  /// them in.
  final DateTime placedAt;

  /// This item, standing in [plot] instead.
  ///
  /// The whole of "decor can be moved": the same object with a different plot,
  /// so what the user moved is what is still there afterwards.
  Decor movedTo(GardenPlot plot) => Decor(
        id: id,
        kind: kind,
        plot: plot,
        placedAt: placedAt,
      );

  /// Decor compares by value: two reads of the same row are the same item.
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
