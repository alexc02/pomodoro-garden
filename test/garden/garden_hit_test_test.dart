import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/garden_hit_test.dart';
import 'package:pip_garden/src/garden/garden_projection.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/garden_atlas.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';

import '../support/decor_fixtures.dart';

// Tap point to plant. The hard case is a small plant in front of a tall
// one: their boxes overlap on screen even though the plants don't.

/// Real atlas from the real sprites, since hits depend on how much of its
/// cell each sprite fills. Lazy so the first read happens after main has set
/// up the binding.
final GardenAtlas _atlas = GardenAtlas.bake(
  GardenAtlasRecipe(
    registry: const PlaceholderPlantSpriteRegistry(),
    decorRegistry: testDecorRegistry,
    decorPalette: testDecorPalette,
    palettes: {for (final species in PlantSpecies.values) species: _palette},
    soil: _palette.soil,
    decor: _palette.soil,
  ),
);

const _palette = PlantPalette(
  foliage: Color(0xFF6B8E5A),
  bloom: Color(0xFFE89B9B),
  soil: Color(0xFF8B6F47),
);

/// Default camera. Not the origin, so ignoring the pan would fail.
const GardenProjection _camera = GardenProjection(pan: Offset(200, 300));

/// A plant of [type] in [plot]. Species doesn't matter here.
Plant _plant(String id, PlantType type, GardenPlot plot) => Plant(
      id: id,
      sessionId: id,
      type: type,
      species: PlantSpecies.chosenFor(type: type, seed: id),
      stage: GrowthStage.mature,
      plantedAt: DateTime.utc(2026, 8, 11, 9, 41),
      sessionDuration: const Duration(minutes: 25),
      plot: plot,
    );

GardenLayout _garden(List<Plant> plants) =>
    GardenLayout.of(plants: plants, completedSessions: plants.length);

GardenHitTest _hitTest(
  GardenLayout garden, {
  GardenProjection projection = _camera,
}) =>
    GardenHitTest(layout: garden, projection: projection, atlas: _atlas);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(() => _atlas.dispose());

  group('a tap on a plant', () {
    test('finds the plant under the finger', () {
      final plants = [
        _plant('a', PlantType.flower, const GardenPlot(0, 0)),
        _plant('b', PlantType.herb, const GardenPlot(1, 0)),
        _plant('c', PlantType.largeTree, const GardenPlot(0, 1)),
      ];
      final hitTest = _hitTest(_garden(plants));

      for (final plant in plants) {
        expect(
          hitTest.plantAt(_camera.centreOf(plant.plot!)),
          plant,
          reason: '${plant.id} in ${plant.plot}',
        );
      }
    });

    test('finds it from the soil at its base', () {
      // A wildflower is a thin stem; nobody can hit that.
      final plant = _plant('a', PlantType.wildflower, const GardenPlot(0, 0));
      final hitTest = _hitTest(_garden([plant]));
      final centre = _camera.centreOf(plant.plot!);

      // Out on the tile, away from the plant itself.
      expect(hitTest.plantAt(centre.translate(30, 0)), plant);
      expect(hitTest.plantAt(centre.translate(-30, 0)), plant);
    });
  });

  group('a tap on nothing', () {
    test('bare soil', () {
      final garden = _garden([
        _plant('a', PlantType.flower, const GardenPlot(0, 0)),
      ]);
      final hitTest = _hitTest(garden);

      final bare =
          garden.plots.firstWhere((plot) => garden.plantIn(plot) == null);
      expect(hitTest.plantAt(_camera.centreOf(bare)), isNull);
    });

    test('locked plot', () {
      final garden = _garden([
        _plant('a', PlantType.flower, const GardenPlot(0, 0)),
      ]);
      final locked = GardenPlots.inPlacementOrder[80];
      expect(garden.plots, isNot(contains(locked)));

      expect(_hitTest(garden).plantAt(_camera.centreOf(locked)), isNull);
    });

    test('far off the edge', () {
      final garden = _garden([
        _plant('a', PlantType.largeTree, const GardenPlot(0, 0)),
      ]);

      expect(_hitTest(garden).plantAt(const Offset(-4000, -4000)), isNull);
    });

    test('sky above a plant', () {
      // A box as tall as the plant could grow would catch taps on sky.
      final plant = _plant('a', PlantType.wildflower, const GardenPlot(0, 0));
      final hitTest = _hitTest(_garden([plant]));
      final base = _camera.centreOf(plant.plot!);

      // A wildflower fills under half its box; the top is sky.
      expect(hitTest.plantAt(base.translate(0, -70)), isNull);
    });
  });

  group('where sprites overlap', () {
    // Large tree in the middle, wildflower one row in front in the same column.
    // The wildflower is on top; its box covers the tree's lower half but its
    // ink barely does.
    const behind = GardenPlot(0, 0);
    const inFront = GardenPlot(1, 1);

    final tree = _plant('tree', PlantType.largeTree, behind);
    final wildflower = _plant('wildflower', PlantType.wildflower, inFront);

    final hitTest = _hitTest(_garden([tree, wildflower]));
    final trunk = _camera.centreOf(behind);

    test('tree overlaps the wildflower plot', () {
      // Check the premise, otherwise the next test proves nothing.
      expect(
        _camera.spriteBounds(inFront).contains(trunk.translate(0, -20)),
        isTrue,
      );
    });

    test('trunk opens the tree', () {
      expect(hitTest.plantAt(trunk.translate(0, -20)), tree);
    });

    test('canopy opens the tree', () {
      expect(hitTest.plantAt(trunk.translate(0, -60)), tree);
    });

    test('wildflower opens the wildflower', () {
      expect(hitTest.plantAt(_camera.centreOf(inFront)), wildflower);
    });

    test('nearer plant wins a real overlap', () {
      // Two trees in one column; where both are inked the near one is visible.
      final far = _plant('far', PlantType.largeTree, behind);
      final near = _plant('near', PlantType.largeTree, inFront);
      final overlapping = _hitTest(_garden([far, near]));

      // 20px above the far tree's base, where the near tree reaches over it.
      final point = trunk.translate(0, -20);
      expect(_camera.spriteBounds(behind).contains(point), isTrue);
      expect(_camera.spriteBounds(inFront).contains(point), isTrue);
      expect(overlapping.plantAt(point), near);
    });
  });

  group('at every zoom', () {
    const zooms = [
      GardenProjection.minimumScale,
      0.73,
      1.0,
      1.6,
      GardenProjection.maximumScale,
    ];

    test('finds a single plant at min and max zoom', () {
      // One plant at a time: zoomed out, rows are 15px apart and a tree covers
      // three, so with several plants the other one is the right answer. That's
      // the next test.
      for (final type in PlantType.values) {
        final plant = _plant(type.name, type, const GardenPlot(0, 0));
        final garden = _garden([plant]);

        for (final scale in zooms) {
          final projection =
              GardenProjection(scale: scale, pan: const Offset(200, 300));

          expect(
            _hitTest(garden, projection: projection)
                .plantAt(projection.centreOf(plant.plot!)),
            plant,
            reason: '${type.name} at scale $scale',
          );
        }
      }
    });

    test('every plant reachable at every zoom', () {
      // Zoomed out, plants overlap and the front one wins. What must hold is
      // that no plant is unreachable.
      final plants = [
        for (var n = 0; n < 24; n++)
          _plant(
            'plant-$n',
            PlantType.values[n % PlantType.values.length],
            GardenPlots.inPlacementOrder[n],
          ),
      ];
      final garden = _garden(plants);

      for (final scale in zooms) {
        final projection =
            GardenProjection(scale: scale, pan: const Offset(400, 600));
        final hitTest = _hitTest(garden, projection: projection);

        for (final plant in plants) {
          expect(
            hitTest.plantAt(projection.centreOf(plant.plot!)),
            isNotNull,
            reason: '${plant.id} in ${plant.plot} at scale $scale',
          );
        }
      }
    });

    test('overlap rule holds at every zoom', () {
      final overlapping = _garden([
        _plant('tree', PlantType.largeTree, const GardenPlot(0, 0)),
        _plant('wildflower', PlantType.wildflower, const GardenPlot(1, 1)),
      ]);

      for (final scale in [
        GardenProjection.minimumScale,
        1.0,
        GardenProjection.maximumScale,
      ]) {
        final projection =
            GardenProjection(scale: scale, pan: const Offset(400, 500));
        final trunk = projection.centreOf(const GardenPlot(0, 0));

        expect(
          _hitTest(overlapping, projection: projection)
              .plantAt(trunk.translate(0, -20 * scale))
              ?.id,
          'tree',
          reason: 'at scale $scale',
        );
      }
    });
  });

  test('empty garden', () {
    final hitTest = _hitTest(_garden([]));

    expect(hitTest.plantAt(const Offset(200, 300)), isNull);
  });

  group('while arranging', () {
    // Trees on the three plots in front of (0, 0).
    const behind = GardenPlot(0, 0);
    final trees = [
      _plant('t1', PlantType.largeTree, const GardenPlot(1, 0)),
      _plant('t2', PlantType.largeTree, const GardenPlot(0, 1)),
      _plant('t3', PlantType.largeTree, const GardenPlot(1, 1)),
    ];
    final tap = _camera.centreOf(behind);

    GardenLayout garden({List<Decor> decor = const []}) => GardenLayout.of(
          plants: trees,
          decor: decor,
          completedSessions: 12,
        );

    for (final kind in DecorKind.values) {
      test('${kind.name} behind a tree can be picked up', () {
        final item = testDecor(kind, behind);
        final hitTest = _hitTest(garden(decor: [item]));

        // Normally the tree gets it.
        expect(hitTest.at(tap), isA<PlantTarget>());

        final target = hitTest.at(tap, arranging: true);
        expect(target, isA<DecorTarget>());
        expect((target! as DecorTarget).decor, item);
      });
    }

    test('soil behind a tree can be tapped', () {
      final target = _hitTest(garden()).at(tap, arranging: true);

      expect(target, isA<SoilTarget>());
      expect(target!.plot, behind);
    });

    test('a plant is still hit in its own plot', () {
      final tree = trees.last;
      final target = _hitTest(garden())
          .at(_camera.centreOf(tree.plot!), arranging: true);

      expect((target! as PlantTarget).plant, tree);
    });

    test('between plants the one on top is picked up', () {
      // Two trees in one column, as in 'nearer plant wins a real overlap'.
      final far = _plant('far', PlantType.largeTree, behind);
      final near = _plant('near', PlantType.largeTree, const GardenPlot(1, 1));
      final overlapping = _hitTest(_garden([far, near]));

      // In the far tree's plot, but under the near tree's picture.
      final point = tap.translate(0, -20);
      expect(_camera.plotUnder(point), behind);

      final target = overlapping.at(point, arranging: true);
      expect((target! as PlantTarget).plant, near);
      expect(target.plot, near.plot);
    });

    test('a canopy is picked up where it hangs over nothing', () {
      // Above the tree's own tile, off every unlocked plot.
      final tree =
          _plant('tree', PlantType.largeTree, const GardenPlot(-1, -1));
      final alone = _hitTest(_garden([tree]));
      final canopy = _camera.centreOf(tree.plot!).translate(0, -60);
      expect(alone.at(canopy), isA<PlantTarget>());

      final target = alone.at(canopy, arranging: true);

      expect((target! as PlantTarget).plant, tree);
    });
  });
}
