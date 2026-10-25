import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/garden_hit_test.dart';
import 'package:pip_garden/src/garden/garden_projection.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/garden_atlas.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';

import '../support/decor_fixtures.dart';

/// Turning a tap into a plant, on its own.
///
/// Ticket 12's first criterion is that the plant the user *visually* taps is
/// the one that opens, and the case that decides it is a small plant standing
/// in front of a tall one: their boxes overlap on screen even though the plants
/// do not. Everything here is a point in and a plant out — no widget, no
/// gesture, and no screen to look at.

/// The real texture, baked from the real sprites.
///
/// Not a stand-in: what a tap lands on is decided from how much of its cell a
/// plant's picture fills, and that is the atlas's answer about the sprite it
/// actually baked. A fake here would be testing the arithmetic against pictures
/// nobody is looking at.
///
/// Lazy, which is what lets a group build a hit-test while it is being
/// declared: the first read happens after `main` has initialised the binding,
/// and baking a texture needs one.
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

/// Where the camera is in every test that does not say otherwise. Arbitrary,
/// and not the origin, so that nothing here can pass by ignoring the pan.
const GardenProjection _camera = GardenProjection(pan: Offset(200, 300));

/// A plant of [type] standing in [plot]. The species is whichever the id picks,
/// because nothing here depends on which one it is.
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
    test('finds the plant standing on the plot under the finger', () {
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

    test('finds it from the soil at its feet, not only from the plant itself',
        () {
      // A wildflower is a stem and two leaves: a hit-test that asked for the
      // stem would be asking the user to tap a line three pixels wide.
      final plant = _plant('a', PlantType.wildflower, const GardenPlot(0, 0));
      final hitTest = _hitTest(_garden([plant]));
      final centre = _camera.centreOf(plant.plot!);

      // Well out along the tile, where nothing of the plant is drawn.
      expect(hitTest.plantAt(centre.translate(30, 0)), plant);
      expect(hitTest.plantAt(centre.translate(-30, 0)), plant);
    });
  });

  group('a tap on nothing', () {
    test('on bare soil finds nothing', () {
      final garden = _garden([
        _plant('a', PlantType.flower, const GardenPlot(0, 0)),
      ]);
      final hitTest = _hitTest(garden);

      final bare =
          garden.plots.firstWhere((plot) => garden.plantIn(plot) == null);
      expect(hitTest.plantAt(_camera.centreOf(bare)), isNull);
    });

    test('on a plot the garden has not unlocked finds nothing', () {
      final garden = _garden([
        _plant('a', PlantType.flower, const GardenPlot(0, 0)),
      ]);
      final locked = GardenPlots.inPlacementOrder[80];
      expect(garden.plots, isNot(contains(locked)));

      expect(_hitTest(garden).plantAt(_camera.centreOf(locked)), isNull);
    });

    test('miles off the edge of the garden finds nothing', () {
      final garden = _garden([
        _plant('a', PlantType.largeTree, const GardenPlot(0, 0)),
      ]);

      expect(_hitTest(garden).plantAt(const Offset(-4000, -4000)), isNull);
    });

    test('in the sky over the tallest tree finds nothing', () {
      // The other end of the same rule as the overlap test below: a box that
      // reached as high as the plant *could* have grown would catch taps on
      // empty sky.
      final plant = _plant('a', PlantType.wildflower, const GardenPlot(0, 0));
      final hitTest = _hitTest(_garden([plant]));
      final base = _camera.centreOf(plant.plot!);

      // A wildflower fills under half its box; the top of the box is sky.
      expect(hitTest.plantAt(base.translate(0, -70)), isNull);
    });
  });

  group('where sprites overlap', () {
    // A large tree at the middle of the garden, and a wildflower one row in
    // front of it — the same screen column, forty-four pixels nearer. The
    // wildflower is drawn last and so is on top; its *box* covers the bottom
    // half of the tree, and its plant covers almost none of it.
    const behind = GardenPlot(0, 0);
    const inFront = GardenPlot(1, 1);

    final tree = _plant('tree', PlantType.largeTree, behind);
    final wildflower = _plant('wildflower', PlantType.wildflower, inFront);

    final hitTest = _hitTest(_garden([tree, wildflower]));
    final trunk = _camera.centreOf(behind);

    test('the tree behind is drawn over the plot the wildflower stands on', () {
      // The premise, asserted rather than assumed: without it the test below
      // would pass on a garden where nothing overlapped at all.
      expect(
        _camera.spriteBounds(inFront).contains(trunk.translate(0, -20)),
        isTrue,
      );
    });

    test('a tap on the trunk opens the tree, not the wildflower in front of it',
        () {
      expect(hitTest.plantAt(trunk.translate(0, -20)), tree);
    });

    test('a tap on the canopy opens the tree', () {
      expect(hitTest.plantAt(trunk.translate(0, -60)), tree);
    });

    test('and a tap on the wildflower still opens the wildflower', () {
      expect(hitTest.plantAt(_camera.centreOf(inFront)), wildflower);
    });

    test('the nearer plant wins where two plants really do overlap', () {
      // Two trees in the same column. The near one is drawn over the far one,
      // so where both are inked the near one is what the user can see.
      final far = _plant('far', PlantType.largeTree, behind);
      final near = _plant('near', PlantType.largeTree, inFront);
      final overlapping = _hitTest(_garden([far, near]));

      // Twenty pixels above the far tree's base: still on the far tree, and
      // the near tree — a row closer and a good deal taller than that row is
      // deep — reaches over it.
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

    test('a tap on a plant finds it, zoomed all the way out and all the way in',
        () {
      // One plant at a time, because with more than one the honest answer at
      // the far end of the zoom range is *the other plant*: zoomed out, the
      // rows are fifteen pixels apart and a tree covers three of them. That
      // case is the group below, and it is the behaviour rather than a fault
      // in it.
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

    test('and every plant in a full garden is reachable at every zoom', () {
      // Not "finds that plant" — a garden zoomed out is a garden whose plants
      // overlap, and the one in front is the right answer. What must hold is
      // that a tap on a plant opens *a* plant: no plant in the garden is
      // covered by a gap.
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

    test('and the overlap rule holds at every zoom too', () {
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

  test('an empty garden has nothing to find', () {
    final hitTest = _hitTest(_garden([]));

    expect(hitTest.plantAt(const Offset(200, 300)), isNull);
  });
}
