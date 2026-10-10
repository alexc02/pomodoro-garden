import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pomodoro_garden/src/garden/garden_atlas.dart';
import 'package:pomodoro_garden/src/garden/plant_sprite.dart';

import '../support/decor_fixtures.dart';

/// The texture the garden is cut from.
///
/// The claim under test is ticket 07's: sprites are batched through an atlas
/// rather than drawn one at a time. Half of that is here — that there *is* one
/// texture, that every plant in the garden has a piece of it, and that the
/// piece was filled by the registry rather than by anything naming an image.
/// The other half is `garden_painter_test.dart`, which checks that the garden
/// becomes one batch.

const PlantPalette _palette = PlantPalette(
  foliage: Color(0xFF4CAF50),
  bloom: Color(0xFFFFC107),
  soil: Color(0xFF795548),
);

GardenAtlasRecipe _recipe({
  PlantSpriteRegistry registry = const PlaceholderPlantSpriteRegistry(),
  Color soil = const Color(0xFF795548),
  Color decor = const Color(0xFF9A9A92),
}) =>
    GardenAtlasRecipe(
      registry: registry,
      decorRegistry: testDecorRegistry,
      decorPalette: testDecorPalette,
      decor: decor,
      palettes: {
        for (final species in PlantSpecies.values) species: _palette,
      },
      soil: soil,
    );

/// A registry that hands out a sprite that paints a solid block, and remembers
/// what it was asked for.
final class _RecordingRegistry implements PlantSpriteRegistry {
  final List<(PlantType, GrowthStage)> asked = [];

  @override
  PlantSprite spriteFor({
    required PlantType type,
    required GrowthStage stage,
  }) {
    asked.add((type, stage));
    return const _SolidSprite();
  }
}

final class _SolidSprite implements PlantSprite {
  const _SolidSprite();

  @override
  void paint(Canvas canvas, Rect bounds, PlantPalette palette) {
    canvas.drawRect(bounds, Paint()..color = palette.foliage);
  }

  @override
  Rect footprintIn(Rect bounds) => bounds;
}

void main() {
  test('every plant in the garden has a piece of the texture', () {
    final atlas = GardenAtlas.bake(_recipe());
    addTearDown(atlas.dispose);

    for (final species in PlantSpecies.values) {
      expect(atlas.rectFor(species), isNotNull, reason: species.name);
    }
  });

  test('no two species share a piece of it', () {
    final atlas = GardenAtlas.bake(_recipe());
    addTearDown(atlas.dispose);

    final cells = [
      for (final species in PlantSpecies.values) atlas.rectFor(species),
      atlas.emptySoil,
      atlas.plantedSoil,
    ];

    expect(cells.toSet(), hasLength(cells.length));
    for (var a = 0; a < cells.length; a++) {
      for (var b = a + 1; b < cells.length; b++) {
        expect(
          cells[a].overlaps(cells[b]),
          isFalse,
          reason: 'cells $a and $b overlap, so one plant would bleed into '
              'another',
        );
      }
    }
  });

  test('the cells are filled by the registry, not by naming an image', () {
    // Ticket 04's contract, kept through ticket 07: the atlas is *built out of*
    // sprites. Ticket 23 supplies a different registry and this file does not
    // change.
    final registry = _RecordingRegistry();
    GardenAtlas.bake(_recipe(registry: registry)).dispose();

    expect(
      registry.asked.map((asked) => asked.$1).toSet(),
      PlantType.values.toSet(),
      reason: 'every type of plant that can be in a garden was drawn',
    );
    expect(
      registry.asked.map((asked) => asked.$2).toSet(),
      {GrowthStage.mature},
      reason: 'only a completed session earns a plant, and a plant that '
          'reached the garden is finished growing',
    );
    expect(registry.asked, hasLength(PlantSpecies.values.length));
  });

  test('a plant is baked standing on the bottom of its cell', () {
    // The whole of how the garden hangs a plant off a plot: the painter anchors
    // at the bottom middle of the cell, which has to be where the sprite put
    // the plant's base.
    final registry = _RecordingRegistry();
    final atlas = GardenAtlas.bake(_recipe(registry: registry));
    addTearDown(atlas.dispose);

    final cell = atlas.rectFor(PlantSpecies.oak);
    expect(cell.width, GardenAtlas.cellWidth);
    expect(cell.height, atlas.plantCell);
  });

  group('what a cell is filled with', () {
    // Ticket 12 hit-tests against these numbers, and it asks the atlas for them
    // rather than the registry precisely so that the sprite whose extent is
    // measured is the sprite that was baked. These are the assertions that keep
    // the two the same sprite.

    test('every plant says how much of its cell it fills', () {
      final atlas = GardenAtlas.bake(_recipe());
      addTearDown(atlas.dispose);

      for (final species in PlantSpecies.values) {
        final fills = atlas.footprintFor(species);
        expect(fills.left, greaterThanOrEqualTo(-0.001), reason: species.name);
        expect(fills.right, lessThanOrEqualTo(1.001), reason: species.name);
        expect(fills.width, greaterThan(0), reason: species.name);
        expect(fills.height, greaterThan(0), reason: species.name);
      }
    });

    test('and the answer is the baked sprite\'s own, as a fraction of the cell',
        () {
      // `_SolidSprite` fills everything it is given, so every fraction is the
      // whole of the cell — which is also what proves these are fractions and
      // not the texture pixels they were measured in.
      final atlas = GardenAtlas.bake(_recipe(registry: _RecordingRegistry()));
      addTearDown(atlas.dispose);

      for (final species in PlantSpecies.values) {
        expect(
          atlas.footprintFor(species),
          const Rect.fromLTRB(0, 0, 1, 1),
          reason: species.name,
        );
      }
    });

    test('a wildflower fills less of its cell than a large tree', () {
      // Against the real sprites this time: the fractions differ by species
      // because the pictures do.
      final atlas = GardenAtlas.bake(_recipe());
      addTearDown(atlas.dispose);

      expect(
        atlas.footprintFor(PlantSpecies.poppy).height,
        lessThan(atlas.footprintFor(PlantSpecies.oak).height),
      );
    });
  });

  group('rebaking', () {
    test('an atlas knows the recipe it came from', () {
      final recipe = _recipe();
      final atlas = GardenAtlas.bake(recipe);
      addTearDown(atlas.dispose);

      expect(atlas.signature, recipe);
      expect(atlas.signature, _recipe(), reason: 'recipes compare by value');
    });

    test('a different colour is a different recipe', () {
      // How a phone going dark, ticket 14's seasons and ticket 19's themes all
      // reach the texture: as a recipe that no longer matches.
      expect(_recipe(), isNot(_recipe(soil: const Color(0xFF000000))));
    });

    test('a different registry is a different recipe', () {
      expect(_recipe(), isNot(_recipe(registry: _RecordingRegistry())));
    });
  });

  test('the texture really has pixels in it', () async {
    // The atlas is baked through `toImageSync`, and a bake that silently
    // produced an empty image would leave a garden of invisible plants that
    // every structural test above would still pass.
    final atlas = GardenAtlas.bake(_recipe());
    addTearDown(atlas.dispose);

    final recorder = PictureRecorder();
    atlas.drawInto(
      Canvas(recorder),
      transforms: [
        RSTransform.fromComponents(
          rotation: 0,
          scale: 1,
          anchorX: 0,
          anchorY: 0,
          translateX: 0,
          translateY: 0,
        ),
      ],
      rects: [atlas.rectFor(PlantSpecies.oak)],
    );

    final picture = recorder.endRecording();
    addTearDown(picture.dispose);
    final drawn = await picture.toImage(
      GardenAtlas.cellWidth,
      GardenAtlas.cellWidth,
    );
    addTearDown(drawn.dispose);

    final pixels = (await drawn.toByteData())!;
    var opaque = 0;
    for (var byte = 3; byte < pixels.lengthInBytes; byte += 4) {
      if (pixels.getUint8(byte) > 0) opaque++;
    }

    expect(opaque, greaterThan(0), reason: 'an oak was drawn, not nothing');
  });
}
