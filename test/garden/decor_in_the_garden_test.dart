import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/garden_atlas.dart';
import 'package:pip_garden/src/garden/garden_hit_test.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/garden_projection.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';

import '../support/decor_fixtures.dart';

// Decor in the painter and hit-test: drawn in the right order between plants
// and taking the taps that land on it.

final DateTime _anchor = DateTime.utc(2026, 8, 11, 9, 41);

const PlantPalette _palette = PlantPalette(
  foliage: Color(0xFF4CAF50),
  bloom: Color(0xFFFFC107),
  soil: Color(0xFF795548),
);

GardenAtlas _atlas() => GardenAtlas.bake(
      GardenAtlasRecipe(
        registry: const PlaceholderPlantSpriteRegistry(),
        palettes: {
          for (final species in PlantSpecies.values) species: _palette,
        },
        decorRegistry: testDecorRegistry,
        decorPalette: testDecorPalette,
        soil: const Color(0xFF795548),
        decor: const Color(0xFF9A9A92),
      ),
    );

Plant _plant(GardenPlot plot, {String id = 'plant'}) => Plant(
      id: id,
      sessionId: 'session-$id',
      type: PlantType.largeTree,
      species: PlantSpecies.oak,
      stage: GrowthStage.mature,
      plantedAt: _anchor,
      sessionDuration: const Duration(minutes: 90),
      plot: plot,
    );

/// Big enough that nothing is culled.
const Size _window = Size(4000, 4000);

const GardenProjection _camera = GardenProjection(pan: Offset(2000, 2000));

void main() {
  late GardenAtlas atlas;

  setUp(() => atlas = _atlas());
  tearDown(() => atlas.dispose());

  group('the batch', () {
    test('decor plot adds one quad', () {
      // A plot holds a plant or decor, never both. 12 plots + 2 lanterns = 14.
      final layout = GardenLayout.of(
        plants: const [],
        decor: [
          testDecor(DecorKind.lantern, GardenPlots.inPlacementOrder[3],
              id: 'a'),
          testDecor(DecorKind.pond, GardenPlots.inPlacementOrder[4], id: 'b'),
        ],
        completedSessions: 0,
      );

      final batch =
          GardenPainter(layout: layout, projection: _camera, atlas: atlas)
              .batchFor(_window);

      expect(batch.rects, hasLength(12 + 2));
      expect(batch.rects, contains(atlas.rectForDecor(DecorKind.lantern)));
      expect(batch.rects, contains(atlas.rectForDecor(DecorKind.pond)));
    });

    test('decor plot uses occupied ground', () {
      final layout = GardenLayout.of(
        plants: const [],
        decor: [testDecor(DecorKind.bench, GardenPlots.inPlacementOrder[0])],
        completedSessions: 0,
      );

      final batch =
          GardenPainter(layout: layout, projection: _camera, atlas: atlas)
              .batchFor(_window);

      expect(batch.rects.where((r) => r == atlas.plantedSoil), hasLength(1));
      expect(batch.rects.where((r) => r == atlas.emptySoil), hasLength(11));
    });

    test('decor is depth-sorted with plants', () {
      // Depth order: the bench is between the far and near trees, so it goes
      // between them in the batch.
      const far = GardenPlot(0, 0);
      const middle = GardenPlot(1, 0);
      const near = GardenPlot(1, 1);

      final layout = GardenLayout.of(
        plants: [_plant(far, id: 'far'), _plant(near, id: 'near')],
        decor: [testDecor(DecorKind.bench, middle)],
        completedSessions: 3,
      );

      final batch =
          GardenPainter(layout: layout, projection: _camera, atlas: atlas)
              .batchFor(_window);

      final bench = batch.rects.indexOf(atlas.rectForDecor(DecorKind.bench));
      final trees = <int>[
        for (var i = 0; i < batch.rects.length; i++)
          if (batch.rects[i] == atlas.rectFor(PlantSpecies.oak)) i,
      ];

      expect(trees, hasLength(2));
      expect(bench, greaterThan(trees.first));
      expect(bench, lessThan(trees.last));
    });

    test('still one batch', () {
      final layout = GardenLayout.of(
        plants: [
          for (var n = 0; n < 100; n++)
            _plant(GardenPlots.inPlacementOrder[n], id: 'plant-$n'),
        ],
        decor: [
          for (var n = 100; n < 150; n++)
            testDecor(
              DecorKind.values[n % DecorKind.values.length],
              GardenPlots.inPlacementOrder[n],
              id: 'decor-$n',
            ),
        ],
        completedSessions: 500,
      );

      final batch =
          GardenPainter(layout: layout, projection: _camera, atlas: atlas)
              .batchFor(_window);

      expect(batch.transforms, hasLength(batch.rects.length));
      expect(batch.rects, hasLength(200 + 100 + 50));
    });
  });

  group('the export', () {
    test('includes decor', () {
      // Export is GardenPainter with a projection fitted to the whole garden,
      // and decor is already in its batch, so nothing extra to draw.
      final layout = GardenLayout.of(
        plants: [_plant(GardenPlots.inPlacementOrder[0])],
        decor: [
          testDecor(DecorKind.pond, GardenPlots.inPlacementOrder[8], id: 'a'),
          testDecor(
            DecorKind.lantern,
            GardenPlots.inPlacementOrder[11],
            id: 'b',
          ),
        ],
        completedSessions: 1,
      );

      // Fitted to everything, no camera.
      const sheet = Size(2000, 2000);
      final whole = GardenProjection.fitting(sheet, layout.plots);
      final batch =
          GardenPainter(layout: layout, projection: whole, atlas: atlas)
              .batchFor(sheet);

      expect(batch.rects, contains(atlas.rectForDecor(DecorKind.pond)));
      expect(batch.rects, contains(atlas.rectForDecor(DecorKind.lantern)));
      expect(batch.rects, contains(atlas.rectFor(PlantSpecies.oak)));
      expect(
        batch.rects,
        hasLength(layout.plotCount + layout.plants.length + layout.decor.length),
        reason: 'everything once',
      );
    });
  });

  group('tapping', () {
    GardenHitTest hitTest(GardenLayout layout) => GardenHitTest(
          layout: layout,
          projection: _camera,
          atlas: atlas,
        );

    Offset centreOf(GardenPlot plot) => _camera.centreOf(plot);

    test('decor takes its tap', () {
      const plot = GardenPlot(0, 0);
      final layout = GardenLayout.of(
        plants: const [],
        decor: [testDecor(DecorKind.pond, plot)],
        completedSessions: 0,
      );

      final target = hitTest(layout).at(centreOf(plot));

      expect(target, isA<DecorTarget>());
      expect((target! as DecorTarget).decor.kind, DecorKind.pond);
      expect(target.plot, plot);
    });

    test('decor blocks the plant behind', () {
      // Topmost takes the tap; for decor that means nothing opens.
      const behind = GardenPlot(0, 0);
      const front = GardenPlot(1, 1);
      final layout = GardenLayout.of(
        plants: [_plant(behind)],
        decor: [testDecor(DecorKind.lantern, front)],
        completedSessions: 3,
      );

      expect(hitTest(layout).plantAt(centreOf(front)), isNull);
      expect(hitTest(layout).at(centreOf(front)), isA<DecorTarget>());
    });

    test('plant still hit among decor', () {
      const plot = GardenPlot(0, 0);
      final layout = GardenLayout.of(
        plants: [_plant(plot)],
        decor: [
          testDecor(DecorKind.pond, const GardenPlot(1, 0), id: 'a'),
          testDecor(DecorKind.bench, const GardenPlot(0, 1), id: 'b'),
        ],
        completedSessions: 3,
      );

      expect(hitTest(layout).plantAt(centreOf(plot))!.id, 'plant');
    });

    test('soil is a plot, sky is nothing', () {
      // An unlocked plot can take decor; a locked one can't.
      final layout = GardenLayout.of(plants: const [], completedSessions: 0);
      final test = hitTest(layout);

      final bare = test.at(centreOf(GardenPlots.inPlacementOrder[5]));
      expect(bare, isA<SoilTarget>());
      expect(bare!.plot, GardenPlots.inPlacementOrder[5]);

      expect(
        test.at(centreOf(GardenPlots.inPlacementOrder[50])),
        isNull,
        reason: 'a plot the garden has not unlocked is not soil to arrange',
      );
      expect(test.plantAt(centreOf(GardenPlots.inPlacementOrder[5])), isNull);
    });

    test('sky above decor misses it', () {
      // The footprint makes this work: a lantern fills half its box and the top
      // is sky.
      const plot = GardenPlot(0, 0);
      final layout = GardenLayout.of(
        plants: const [],
        decor: [testDecor(DecorKind.lantern, plot)],
        completedSessions: 0,
      );

      final box = _camera.spriteBounds(plot);
      expect(
        hitTest(layout).at(Offset(box.center.dx, box.top + 2)),
        isNot(isA<DecorTarget>()),
      );
    });
  });

  group('sprites', () {
    test('every kind has a distinct sprite', () {
      final rects = {
        for (final kind in DecorKind.values) atlas.rectForDecor(kind),
      };

      expect(rects, hasLength(DecorKind.values.length));
    });

    test('decor is shorter than plants', () {
      // Decor should never be taller than a full-grown plant.
      final tallest = DecorKind.values
          .map((kind) => atlas.footprintForDecor(kind))
          .map((box) => box.bottom - box.top)
          .reduce((a, b) => a > b ? a : b);
      final oak = atlas.footprintFor(PlantSpecies.oak);

      expect(tallest, lessThan(oak.bottom - oak.top));
    });

    test('footprints sit on the bottom, inside the cell', () {
      // Cells are 2px apart in the texture, so painting outside one would bleed
      // into a neighbour.
      for (final kind in DecorKind.values) {
        final box = atlas.footprintForDecor(kind);
        expect(box.left, greaterThanOrEqualTo(0), reason: kind.name);
        expect(box.right, lessThanOrEqualTo(1), reason: kind.name);
        expect(box.top, greaterThanOrEqualTo(0), reason: kind.name);
        expect(box.bottom, closeTo(1, 0.001), reason: kind.name);
      }
    });
  });
}
