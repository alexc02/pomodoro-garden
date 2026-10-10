import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../design/garden_colors.dart';
import 'decor_sprite.dart';
import 'garden_atlas.dart';
import 'plant_palettes.dart';
import 'plant_sprite.dart';

/// How a set of garden colours becomes a texture: the one place that decides
/// it.
///
/// **Here rather than in the view, because there are two callers now.** The
/// garden screen bakes an atlas to draw with and ticket 21's export bakes one
/// to render into an image, and the whole worth of the export is that it shows
/// the user what they were looking at. Two copies of this recipe would be two
/// gardens that agree until somebody edits one of them — a season the export
/// missed, a decor palette that went stale — and the failure would be invisible
/// until a user shared a picture of a garden they do not have.
///
/// So the two bake from the same call, and the assertion that they do is in
/// `test/features/garden/export_flow_test.dart` — *because it bakes the texture
/// the screen is drawn from*, which compares the signature of the atlas on the
/// garden tab with the recipe an export computes from settings, where there is
/// no skin over the subtree at all.
///
/// The registries are handed in rather than read from providers, because this
/// is a pure function of its arguments and ticket 23 swaps them at the root of
/// the app.
GardenAtlasRecipe gardenAtlasRecipe({
  required GardenColors colours,
  required PlantSpriteRegistry registry,
  required DecorSpriteRegistry decorRegistry,
}) =>
    GardenAtlasRecipe(
      registry: registry,
      palettes: {
        for (final species in PlantSpecies.values)
          species: plantPaletteIn(colours, species),
      },
      decorRegistry: decorRegistry,
      // REQ-040's objects, dressed by the same skin as everything else: the
      // material is the biome's and holds still through the year, and the
      // water, the ground shadow and a lantern's light are today's sky, soil
      // and bloom. A change of season or of theme arrives as a different recipe
      // and a rebake, exactly as it does for a plant — there is no second
      // mechanism keeping the furniture in step.
      decorPalette: DecorPalette(
        material: colours.decor,
        water: colours.skyDay,
        shade: colours.soil,
        glow: colours.bloom,
      ),
      soil: colours.soil,
      decor: colours.decor,
    );
