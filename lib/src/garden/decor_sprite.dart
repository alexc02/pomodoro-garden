import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

/// One decor image: the picture of a [DecorKind] standing in a plot.
///
/// The same seam [PlantSprite] is, for the same reason and with the same
/// contract. Every lantern, bench, birdbath and pond that reaches the screen —
/// in the garden and in the picker alike — is drawn through a
/// sprite obtained from a [DecorSpriteRegistry], never from an image a widget
/// names for itself. That indirection is what keeps ticket 23's "decor art
/// replaced" an asset swap rather than a hunt through the widget tree, and it
/// is enforced by `test/garden/sprites_are_the_only_art_test.dart`.
///
/// Keyed by kind alone, where a plant is keyed by type *and* stage: a bench does
/// not grow.
abstract interface class DecorSprite {
  /// Paints this object into [bounds], standing on its bottom edge and centred
  /// horizontally, in the colours [palette] supplies.
  ///
  /// The sprite owns its shape; the caller owns its size, position and
  /// colouring — the same division of labour [PlantSprite.paint] works to, so
  /// that the atlas can bake both the same way.
  void paint(Canvas canvas, Rect bounds, DecorPalette palette);

  /// The part of [bounds] this object actually covers when painted into it.
  ///
  /// A box, not a silhouette, and it decides the same thing a plant's footprint
  /// does: which thing a finger landed on. A pond is a wide flat oval on the
  /// ground and a lantern is a narrow upright — a hit-test against the whole
  /// square would give the lantern's empty sky to the plant standing behind it.
  Rect footprintIn(Rect bounds);
}

/// The colours one decor object is drawn in.
///
/// **Three of the four move with the season and one does not**, which is the
/// whole of REQ-040's "themed consistently with the active garden theme and
/// season" as a value:
///
/// - [material] is the biome's own — Zen's stone, the greenhouse's teak, the
///   meadow's silvered fence wood — and is the one garden colour a season
///   leaves alone. Ticket 19 made that decision and ADR 0016 says why: by
///   January the seasons have pulled every other colour towards the same cold
///   grey, and without a constant the winter meadow and the winter Zen garden
///   are nearly the same picture.
/// - [water], [shade] and [glow] are today's sky, soil and bloom. What a season
///   reaches, then, is what an object *holds* rather than what it is made of: a
///   pond is the colour of the sky above it in every month of the year, and a
///   lantern's light is the same warm the garden's flowers are.
///
/// Passed at paint time rather than held by the sprite, for the reason
/// [PlantPalette] is: the registry stays a pure `kind -> sprite` lookup with no
/// dependency on the theme or the calendar.
final class DecorPalette {
  const DecorPalette({
    required this.material,
    required this.water,
    required this.shade,
    required this.glow,
  });

  /// What the object is made of: the biome's material, season-proof.
  final Color material;

  /// What standing water reads as: today's sky.
  final Color water;

  /// The ground an object sits on, and the shadow it casts on it: today's soil.
  final Color shade;

  /// The warm an object gives off: today's bloom, spent on a lantern's window
  /// and nowhere else.
  final Color glow;

  @override
  bool operator ==(Object other) =>
      other is DecorPalette &&
      other.material == material &&
      other.water == water &&
      other.shade == shade &&
      other.glow == glow;

  @override
  int get hashCode => Object.hash(material, water, shade, glow);
}

/// Where a [DecorSprite] is found: keyed by kind, and by nothing else.
///
/// Ticket 23's real art arrives as a different implementation of this and
/// changes no placement, layout or hit-testing logic — the same contract ticket
/// 04 wrote for plants, kept for the objects standing among them.
abstract interface class DecorSpriteRegistry {
  /// The sprite for [kind]. Total: every one of the four resolves, so no object
  /// in the garden can fail to draw.
  DecorSprite spriteFor(DecorKind kind);
}
