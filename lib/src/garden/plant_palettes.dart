import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../design/garden_colors.dart';
import 'plant_sprite.dart';

/// The colours one [PlantSpecies] is drawn in.
///
/// Species of the same type share a shape, so each one nudges the theme's
/// foliage and bloom a few degrees round the wheel. The nudge comes from
/// [stableFraction], so it's identical across launches and platforms, and no
/// hex codes leave `design/palette.dart`.
PlantPalette plantPaletteFor(BuildContext context, PlantSpecies species) =>
    plantPaletteIn(GardenColors.of(context), species);

/// Same as [plantPaletteFor] but from colours already in hand. The export
/// draws with no widget tree, so it needs this form.
PlantPalette plantPaletteIn(GardenColors garden, PlantSpecies species) {
  return PlantPalette(
    foliage: _shifted(
      evergreens.contains(species) ? garden.evergreenFoliage : garden.foliage,
      species.name,
    ),
    bloom: _shifted(garden.bloom, '${species.name}-bloom'),
    soil: garden.soil,
  );
}

/// Species that keep their leaves in winter. Everything else goes bare.
///
/// Lives here rather than on [PlantSpecies] because it only affects drawing.
const Set<PlantSpecies> evergreens = {
  PlantSpecies.rosemary,
  PlantSpecies.boxwood,
  PlantSpecies.lavender,
  PlantSpecies.pine,
  // The first milestone plant is a bonsai, which is usually a conifer.
  PlantSpecies.bonsai,
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
