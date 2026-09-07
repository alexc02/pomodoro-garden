import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

/// The picture of a [DecorKind] standing in a plot.
///
/// Same contract as [PlantSprite]: all decor on screen, garden and picker
/// alike, is drawn through a [DecorSpriteRegistry] (enforced by
/// `test/garden/sprites_are_the_only_art_test.dart`). Keyed by kind only,
/// since decor doesn't grow.
abstract interface class DecorSprite {
  /// Paints into [bounds], standing on the bottom edge and centred
  /// horizontally. Caller owns size, position and colour.
  void paint(Canvas canvas, Rect bounds, DecorPalette palette);

  /// The box this object actually covers inside [bounds], for hit-testing.
  /// A lantern is narrow and tall, a pond wide and flat, so the full square
  /// would steal taps from plants behind.
  Rect footprintIn(Rect bounds);
}

/// The colours one decor object is drawn in.
///
/// [material] is the biome's (stone, teak, fence wood) and ignores the season,
/// so the three themes stay distinct in winter. [water], [shade] and [glow] are today's sky, soil and
/// bloom, so they follow the season.
final class DecorPalette {
  const DecorPalette({
    required this.material,
    required this.water,
    required this.shade,
    required this.glow,
  });

  /// What the object is made of. Season-proof.
  final Color material;

  /// Standing water: today's sky.
  final Color water;

  /// Ground and cast shadow: today's soil.
  final Color shade;

  /// Lantern window light: today's bloom.
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

/// Where a [DecorSprite] is found, keyed by kind.
abstract interface class DecorSpriteRegistry {
  /// Total: every kind resolves, so no decor can fail to draw.
  DecorSprite spriteFor(DecorKind kind);
}
