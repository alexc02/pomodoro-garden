import 'package:flutter/foundation.dart';

import '../design/garden_colors.dart';
import '../design/garden_skin.dart';

/// The garden partway between one way of being dressed and another.
///
/// Neither a theme nor a season arrives; both turn. Everything the garden draws
/// while it is turning — the sky behind it, the soil under it, the colour of
/// its leaves, and what is in the air — is asked of this rather than of a
/// [GardenSkin], so there is one place that knows how far through the change
/// the garden is and no two of them can disagree about it.
///
/// **One value for both changes, and that is ticket 19's doing.** Ticket 14
/// built this to cross-fade a season; REQ-034 adds a theme the user can change
/// at any moment, including in the three seconds a season is taking to turn.
/// Two transitions with a clock each would let the sky finish arriving in
/// January while the soil was still on its way to the greenhouse — so there is
/// one clock and one pair of endpoints, and a change of either kind is the same
/// kind of change to everything downstream of here.
///
/// Here rather than beside [GardenSkin] in `design/`, which holds the §5.1
/// tokens: a palette is a table of colours and this is a value that moves sixty
/// times a second.
@immutable
final class GardenTransition {
  const GardenTransition({
    required this.from,
    required this.to,
    required this.progress,
  });

  /// A garden that is simply dressed as [skin], with nothing turning.
  const GardenTransition.settled(GardenSkin skin)
      : from = skin,
        to = skin,
        progress = 1;

  /// How the garden was dressed.
  final GardenSkin from;

  /// How it is being dressed.
  final GardenSkin to;

  /// How far through, 0 for wholly [from] and 1 for wholly [to].
  final double progress;

  /// Whether anything is moving at all.
  bool get settled => from == to;

  /// [base] with the colours of this moment in it.
  GardenColors applyTo(GardenColors base) {
    final departing = from.applyTo(base);
    if (settled) return departing;

    return departing.lerp(to.applyTo(base), progress);
  }

  @override
  bool operator ==(Object other) =>
      other is GardenTransition &&
      other.from == from &&
      other.to == to &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(from, to, progress);

  @override
  String toString() => 'GardenTransition($from → $to, $progress)';
}
