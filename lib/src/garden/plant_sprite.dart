import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

/// One plant image: a [PlantType] at a [GrowthStage].
///
/// Every plant on screen (timer and garden) goes through a
/// [PlantSpriteRegistry], never an image a widget names itself, so the art set
/// can be swapped without touching growth, layout or timer logic. It paints
/// rather than returning an image because placeholders are `Canvas` drawing
/// and real art is blitted from an atlas.
abstract interface class PlantSprite {
  /// Paints into [bounds], standing on the bottom edge and centred
  /// horizontally. Caller owns size, position, colour and any sway transform.
  void paint(Canvas canvas, Rect bounds, PlantPalette palette);

  /// The box this plant actually covers inside [bounds], for hit-testing.
  ///
  /// Plants grow up over the plots behind them, so testing the full box would
  /// steal taps meant for a taller plant behind. In [bounds]'s coordinates;
  /// may extend past them if the sprite overhangs.
  Rect footprintIn(Rect bounds);
}

/// The colours one plant is drawn in. Passed at paint time so the registry
/// doesn't depend on theme, season or species.
final class PlantPalette {
  const PlantPalette({
    required this.foliage,
    required this.bloom,
    required this.soil,
  });

  /// Stems, leaves and canopies.
  final Color foliage;

  /// Flowers and fruit; only used on what has bloomed.
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

/// Where a [PlantSprite] is found, keyed by type and growth stage.
///
/// No species key: the art is one drawing per type and stage, and species only
/// changes colour via [PlantPalette]. Milestone plants are extra [PlantType]
/// members, so a registry built from `PlantType.values` picks them up.
abstract interface class PlantSpriteRegistry {
  /// Total: every type/stage combination resolves, so no plant can fail to
  /// draw.
  PlantSprite spriteFor({
    required PlantType type,
    required GrowthStage stage,
  });
}
