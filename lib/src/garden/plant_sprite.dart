import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

/// One plant image: a particular [PlantType] at a particular [GrowthStage].
///
/// The seam this ticket exists to deliver. Every plant that reaches the screen
/// — on the timer while a session runs, and in ticket 07's garden — is drawn
/// through a sprite obtained from a [PlantSpriteRegistry], never from an image
/// a widget names for itself. That indirection is what lets ticket 23 replace
/// every placeholder shape below with the real watercolour art by supplying a
/// different registry, changing no growth, layout or timer logic.
///
/// Painting rather than returning an image: a placeholder is drawn with
/// `Canvas` operations and real art will be blitted from a texture atlas, and
/// only one of those can be expressed as an `ImageProvider`. Both can paint.
abstract interface class PlantSprite {
  /// Paints this plant into [bounds], standing on its bottom edge and centred
  /// horizontally, in the colours [palette] supplies.
  ///
  /// The sprite owns its shape; the caller owns its size, position and
  /// colouring. A caller that wants the plant bigger passes a bigger [bounds]
  /// rather than asking the sprite to scale, and one that wants it to sway
  /// transforms the canvas rather than asking the sprite to lean.
  void paint(Canvas canvas, Rect bounds, PlantPalette palette);

  /// The part of [bounds] this plant actually covers when painted into it.
  ///
  /// A box, not a silhouette: what it is for is deciding which plant a finger
  /// landed on, and a finger is wider than the gap between two petals.
  ///
  /// Ticket 12 is why this exists. A plant is drawn standing on its plot and
  /// growing upwards, so its box reaches over the two plots behind it — and a
  /// hit-test against the *box* would give a wildflower's empty sky the tap
  /// meant for the tree standing behind it. Only the sprite knows how much of
  /// the box it fills, so only the sprite can answer this; a real drawing
  /// answers with the tight bounds of its own ink.
  ///
  /// Returned in [bounds]'s own coordinates, and permitted to reach outside
  /// them — a sprite that overhangs its box in paint should say so here.
  Rect footprintIn(Rect bounds);
}

/// The colours one plant is drawn in.
///
/// Passed at paint time rather than held by the sprite, so the registry stays a
/// pure `(type, stage) -> sprite` lookup with no dependency on the theme, the
/// season or which species this particular plant is. Ticket 14 changes these
/// with the season and ticket 19 with the theme; neither touches the registry.
final class PlantPalette {
  const PlantPalette({
    required this.foliage,
    required this.bloom,
    required this.soil,
  });

  /// Stems, leaves and canopies.
  final Color foliage;

  /// Flowers and fruit — the reward colour, spent only on what has bloomed.
  final Color bloom;

  /// The seed, and the earth it goes into.
  final Color soil;

  @override
  bool operator ==(Object other) =>
      other is PlantPalette &&
      other.foliage == foliage &&
      other.bloom == bloom &&
      other.soil == soil;

  @override
  int get hashCode => Object.hash(foliage, bloom, soil);
}

/// Where a [PlantSprite] is found: keyed by type and growth stage, and by
/// nothing else.
///
/// Two keys rather than three — species does not appear — because thirty images
/// is what the product actually has: ticket 23 delivers "all 6 plant types × 5
/// stages", not one drawing per species. Species varies the *colour* a plant is
/// drawn in, through [PlantPalette], which is how one basil differs from the
/// next without the registry needing to know what basil is.
///
/// Ticket 13's milestone plants arrive as new [PlantType] members rather than
/// as a third key, and a registry built from `PlantType.values` picks them up
/// without a change here.
abstract interface class PlantSpriteRegistry {
  /// The sprite for a plant of [type] at [stage]. Total: every one of the
  /// thirty combinations resolves, so no caller has a null to handle and no
  /// plant can fail to draw.
  PlantSprite spriteFor({
    required PlantType type,
    required GrowthStage stage,
  });
}
