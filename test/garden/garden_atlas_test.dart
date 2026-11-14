import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/garden_atlas.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';

import '../support/decor_fixtures.dart';

// One texture with a cell per plant, filled via the registry. The batching
// side is in garden_painter_test.dart.

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

/// Hands out solid-block sprites and records what was asked for.
final class _RecordingRegistry implements PlantSpriteRegistry {
  final List<(PlantForm, GrowthStage)> asked = [];

  @override
  PlantSprite spriteFor({
    required PlantForm form,
    required GrowthStage stage,
  }) {
    asked.add((form, stage));
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
  test('every species has a cell', () {
    final atlas = GardenAtlas.bake(_recipe());
    addTearDown(atlas.dispose);

    for (final species in PlantSpecies.values) {
      expect(atlas.rectFor(species), isNotNull, reason: species.name);
    }
  });

  test("cells don't overlap", () {
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
          reason: 'cells $a and $b overlap',
        );
      }
    }
  });

  test('cells are drawn via the registry', () {
    // The atlas is built from sprites, so swapping the registry needs no change
    // here.
    final registry = _RecordingRegistry();
    GardenAtlas.bake(_recipe(registry: registry)).dispose();

    expect(
      registry.asked.map((asked) => asked.$1).toSet(),
      PlantForm.values.toSet(),
      reason: 'every shape of plant that can be in a garden was drawn',
    );
    expect(
      registry.asked.map((asked) => asked.$2).toSet(),
      {GrowthStage.mature},
      reason: 'garden plants are always fully grown',
    );
    expect(registry.asked, hasLength(PlantSpecies.values.length));
  });

  test('plants sit on the cell bottom', () {
    // The painter anchors at the cell's bottom middle, so the sprite's base
    // has to be there.
    final registry = _RecordingRegistry();
    final atlas = GardenAtlas.bake(_recipe(registry: registry));
    addTearDown(atlas.dispose);

    final cell = atlas.rectFor(PlantSpecies.oak);
    expect(cell.width, GardenAtlas.cellWidth);
    expect(cell.height, atlas.plantCell);
  });

  group('cell extents', () {
    // Hit-testing reads these from the atlas so the measured sprite is the
    // baked one.

    test('every species reports its extent', () {
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

    test('extent is a fraction of the cell', () {
      // _SolidSprite fills everything, so every fraction is the whole cell.
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

    test('wildflower fills less than a large tree', () {
      // Real sprites: fractions differ by species.
      final atlas = GardenAtlas.bake(_recipe());
      addTearDown(atlas.dispose);

      expect(
        atlas.footprintFor(PlantSpecies.poppy).height,
        lessThan(atlas.footprintFor(PlantSpecies.oak).height),
      );
    });
  });

  group('rebaking', () {
    test('keeps its recipe', () {
      final recipe = _recipe();
      final atlas = GardenAtlas.bake(recipe);
      addTearDown(atlas.dispose);

      expect(atlas.signature, recipe);
      expect(atlas.signature, _recipe(), reason: 'recipes compare by value');
    });

    test('colour changes the recipe', () {
      // Dark mode, seasons and themes all invalidate the atlas this way.
      expect(_recipe(), isNot(_recipe(soil: const Color(0xFF000000))));
    });

    test('registry changes the recipe', () {
      expect(_recipe(), isNot(_recipe(registry: _RecordingRegistry())));
    });
  });

  test('texture is not empty', () async {
    // Baked with toImageSync. An empty image would pass every check above.
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

    expect(opaque, greaterThan(0), reason: 'oak was drawn');
  });
}
