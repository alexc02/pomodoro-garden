import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../design/garden_colors.dart';
import 'plant_sprite.dart';

/// The colours one [PlantSpecies] is drawn in.
///
/// Species of the same form share a drawing, so colour is what tells them
/// apart: a species with a [_Tone] takes that hue for its flowers or leaves,
/// and the rest nudge the theme's colour a few degrees round the wheel. A
/// tone only names a hue and how far to lean from the theme, so the season
/// and theme still set how bright everything is, and no hex codes leave
/// `design/palette.dart`.
PlantPalette plantPaletteFor(BuildContext context, PlantSpecies species) =>
    plantPaletteIn(GardenColors.of(context), species);

/// Same as [plantPaletteFor] but from colours already in hand. The export
/// draws with no widget tree, so it needs this form.
PlantPalette plantPaletteIn(GardenColors garden, PlantSpecies species) {
  final foliage =
      evergreens.contains(species) ? garden.evergreenFoliage : garden.foliage;

  return PlantPalette(
    foliage: switch (_foliage[species]) {
      final tone? => tone.of(foliage),
      null => _shifted(foliage, species.name),
    },
    bloom: switch (_blooms[species]) {
      final tone? => tone.of(garden.bloom),
      null => _shifted(garden.bloom, '${species.name}-bloom'),
    },
    soil: garden.soil,
  );
}

/// Species that keep their leaves in winter. Everything else goes bare.
///
/// Lives here rather than on [PlantSpecies] because it only affects drawing.
/// The winter-only species are here too: they're in leaf when they grow.
const Set<PlantSpecies> evergreens = {
  PlantSpecies.rosemary,
  PlantSpecies.thyme,
  PlantSpecies.boxwood,
  PlantSpecies.lavender,
  PlantSpecies.heather,
  PlantSpecies.holly,
  PlantSpecies.olive,
  PlantSpecies.pine,
  PlantSpecies.spruce,
  PlantSpecies.sequoia,
  PlantSpecies.snowdrop,
  PlantSpecies.hellebore,
  // The first milestone plant is a bonsai, which is usually a conifer.
  PlantSpecies.bonsai,
};

/// A species' own colour, described against the theme's.
final class _Tone {
  const _Tone(this.hue, {this.vivid = 1, this.lift = 0});

  /// Degrees round the colour wheel.
  final double hue;

  /// Multiplies the theme colour's saturation. Near zero is white or grey.
  final double vivid;

  /// Added to the theme colour's lightness.
  final double lift;

  Color of(Color theme) {
    final hsl = HSLColor.fromColor(theme);
    return hsl
        .withHue(hue % 360)
        .withSaturation((hsl.saturation * vivid).clamp(0.0, 1.0))
        // Short of the ends, so the drawing's own shading still shows.
        .withLightness((hsl.lightness + lift).clamp(0.1, 0.92))
        .toColor();
  }
}

const _Tone _white = _Tone(55, vivid: 0.14, lift: 0.3);

/// What each species flowers in. A species missing here either has a form
/// with no flowers, or is a milestone plant, which keeps the theme's bloom.
const Map<PlantSpecies, _Tone> _blooms = {
  PlantSpecies.poppy: _Tone(4),
  PlantSpecies.cornflower: _Tone(222),
  PlantSpecies.buttercup: _Tone(50),
  PlantSpecies.foxglove: _Tone(318),
  PlantSpecies.bluebell: _Tone(238),
  PlantSpecies.lupin: _Tone(268),
  PlantSpecies.aster: _Tone(285, lift: 0.06),
  PlantSpecies.snowdrop: _white,
  PlantSpecies.edelweiss: _Tone(70, vivid: 0.2, lift: 0.26),

  PlantSpecies.basil: _white,
  PlantSpecies.mint: _Tone(290, vivid: 0.5, lift: 0.14),
  PlantSpecies.rosemary: _Tone(225, vivid: 0.65, lift: 0.1),
  PlantSpecies.thyme: _Tone(312, vivid: 0.7, lift: 0.1),
  PlantSpecies.sage: _Tone(262),
  PlantSpecies.chives: _Tone(300, lift: 0.05),
  PlantSpecies.fourLeafClover: _Tone(138, vivid: 0.8, lift: 0.1),

  PlantSpecies.sunflower: _Tone(46),
  PlantSpecies.tulip: _Tone(352),
  PlantSpecies.daisy: _white,
  PlantSpecies.peony: _Tone(335, lift: 0.1),
  PlantSpecies.crocus: _Tone(272),
  PlantSpecies.rose: _Tone(348, lift: -0.06),
  PlantSpecies.chrysanthemum: _Tone(28),
  PlantSpecies.hellebore: _Tone(322, vivid: 0.45, lift: 0.14),
  PlantSpecies.blackTulip: _Tone(300, vivid: 0.5, lift: -0.34),

  PlantSpecies.lavender: _Tone(262),
  PlantSpecies.boxwood: _Tone(82, vivid: 0.5, lift: 0.08),
  PlantSpecies.hydrangea: _Tone(215),
  PlantSpecies.azalea: _Tone(330),
  PlantSpecies.heather: _Tone(305, vivid: 0.8),
  PlantSpecies.holly: _Tone(2),
  PlantSpecies.burningBush: _Tone(14),

  PlantSpecies.cherryBlossom: _Tone(345, vivid: 0.9, lift: 0.04),
  PlantSpecies.magnolia: _Tone(328, vivid: 0.5, lift: 0.12),
  PlantSpecies.rowan: _Tone(12),
};

/// The few species known by their leaves rather than their flowers.
const Map<PlantSpecies, _Tone> _foliage = {
  PlantSpecies.burningBush: _Tone(6),
  PlantSpecies.olive: _Tone(96, vivid: 0.45, lift: 0.1),
  PlantSpecies.ginkgo: _Tone(50, lift: 0.08),
  PlantSpecies.birch: _Tone(84, lift: 0.08),
  PlantSpecies.beech: _Tone(26),
  PlantSpecies.sequoia: _Tone(152, lift: -0.05),
};

/// Colours for an empty plot: soil only.
PlantPalette bareSoilPalette(BuildContext context) {
  final garden = GardenColors.of(context);

  return PlantPalette(
    foliage: garden.soil,
    bloom: garden.soil,
    soil: garden.soil,
  );
}

/// [colour] shifted slightly in hue and lightness by an amount [seed] fixes.
/// Kept small so species read as variations, not different colours.
Color _shifted(Color colour, String seed) {
  final hsl = HSLColor.fromColor(colour);
  final hue = (stableFraction(seed) - 0.5) * 24;
  final lightness = (stableFraction('$seed-lightness') - 0.5) * 0.12;

  return hsl
      .withHue((hsl.hue + hue) % 360)
      .withLightness((hsl.lightness + lightness).clamp(0.0, 1.0))
      .toColor();
}
