import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../design/garden_colors.dart';
import 'plant_sprite.dart';

/// The colours one [PlantSpecies] is drawn in, from the theme's own greens and
/// blooms.
///
/// Two plants of the same type are the same shape until ticket 23's art arrives
/// — so until then, species is what separates a basil from a mint, by nudging
/// the theme's foliage and bloom a few degrees around the colour wheel. The
/// nudge is derived from the species' name through [stableFraction], so it is
/// the same shade on every launch and on both platforms, and it is a shift of a
/// design token rather than a new colour: no hex codes live outside
/// `design/palette.dart`.
///
/// Ticket 14 reseasons the garden and ticket 19 rethemes it by changing
/// [GardenColors]; both arrive here for free.
PlantPalette plantPaletteFor(BuildContext context, PlantSpecies species) =>
    plantPaletteIn(GardenColors.of(context), species);

/// The same answer, from colours already in hand rather than from a theme.
///
/// The form the export needs: REQ-035's image is drawn with no widget below it,
/// so there is no context to look a colour up through — and the garden the user
/// is looking at must not be dressed by a different rule from the picture they
/// share of it. So the rule is here, once, and [plantPaletteFor] is the reading
/// of it that a widget can reach.
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

/// The species that keep their leaves: REQ-019's "evergreens retain color".
///
/// A list of plants rather than a rule, because there is no rule — whether a
/// plant is evergreen is a fact about that plant, and four of the app's
/// seventeen ordinary species are, along with one of REQ-021's seven awards.
/// Everything not named here goes bare in winter, which is the other half of
/// the same requirement.
///
/// It lives beside the colouring rather than on [PlantSpecies] because it is a
/// fact about how a plant is *drawn*: nothing in the domain — not what a
/// session grows, not where it stands, not what its card says — is any
/// different for a pine than for a maple.
const Set<PlantSpecies> evergreens = {
  PlantSpecies.rosemary,
  PlantSpecies.boxwood,
  PlantSpecies.lavender,
  PlantSpecies.pine,
  // REQ-021's first milestone plant is a bonsai, and a bonsai is a conifer far
  // more often than not.
  PlantSpecies.bonsai,
};

/// The colours an empty plot is drawn in: soil, and nothing that would be used.
PlantPalette bareSoilPalette(BuildContext context) {
  final garden = GardenColors.of(context);

  return PlantPalette(
    foliage: garden.soil,
    bloom: garden.soil,
    soil: garden.soil,
  );
}

/// [colour], moved a little way around the wheel and a little up or down in
/// lightness, by an amount [seed] fixes.
///
/// Small on purpose. The palette is one garden's worth of greens; a species
/// that shifted far enough to read as a different colour would be a different
/// design, not a different plant.
Color _shifted(Color colour, String seed) {
  final hsl = HSLColor.fromColor(colour);
  final hue = (stableFraction(seed) - 0.5) * 24;
  final lightness = (stableFraction('$seed-lightness') - 0.5) * 0.12;

  return hsl
      .withHue((hsl.hue + hue) % 360)
      .withLightness((hsl.lightness + lightness).clamp(0.0, 1.0))
      .toColor();
}
