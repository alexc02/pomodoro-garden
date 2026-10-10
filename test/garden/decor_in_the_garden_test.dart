import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/garden/garden_atlas.dart';
import 'package:pomodoro_garden/src/garden/garden_hit_test.dart';
import 'package:pomodoro_garden/src/garden/garden_painter.dart';
import 'package:pomodoro_garden/src/garden/garden_projection.dart';
import 'package:pomodoro_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pomodoro_garden/src/garden/plant_sprite.dart';

import '../support/decor_fixtures.dart';

/// REQ-040's objects where they meet ticket 07's painter and ticket 12's
/// hit-test: drawn in the right order, and taking the taps that land on them.
///
/// Kept apart from `garden_painter_test.dart` and `garden_hit_test_test.dart`
/// because what is under test is the *interleaving* — a bench and a tree are
/// two kinds of thing that have to behave as one kind of thing here, and the
/// assertions that say so read better together than split across two files by
/// which class they happen to run through.

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

/// A window big enough that nothing is culled for being off screen.
const Size _window = Size(4000, 4000);

const GardenProjection _camera = GardenProjection(pan: Offset(2000, 2000));

void main() {
  late GardenAtlas atlas;

  setUp(() => atlas = _atlas());
  tearDown(() => atlas.dispose());

  group('the batch', () {
    test('a plot with an object in it is one more quad, not two', () {
      // A plot holds a plant or an object, never both. Twelve plots and two
      // lanterns is fourteen quads.
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

    test('an arranged plot is drawn on occupied ground, not on bare soil', () {
      // A plot with a bench in it is not somewhere anything else can go, and
      // has to look like it.
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

    test('an object is drawn between the plants it stands between', () {
      // The requirement, and the thing a separate pass over the furniture would
      // get wrong: the bench is nearer the viewer than the far tree and further
      // than the near one, so it belongs between them in the batch — not before
      // both and not after both.
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

    test('every quad is still one batch, however much is standing in it', () {
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
    test('a whole-garden render includes the arrangement', () {
      // Ticket 21 has not landed. What this pins is the reason it will not have
      // to think about decor at all: an export is `GardenPainter` at a
      // projection fitted to the whole garden rather than to the camera, and
      // decor is in the batch that painter produces. There is no second list of
      // things to draw for an exporter to remember.
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

      // Fitted to everything, at a size nothing on a phone would be, and with
      // no camera involved — which is what "not a screenshot of the viewport"
      // means.
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
        reason: 'everything the garden holds, and nothing twice',
      );
    });
  });

  group('tapping', () {
    GardenHitTest hitTest(GardenLayout layout) => GardenHitTest(
          layout: layout,
          projection: _camera,
          atlas: atlas,
        );

    /// The middle of [plot]'s tile, where a tap on the ground lands.
    Offset centreOf(GardenPlot plot) => _camera.centreOf(plot);

    test('an object takes the tap that lands on it', () {
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

    test('and does not pass it through to the plant behind it', () {
      // Ticket 12's rule, unchanged in shape: what is visibly on top takes the
      // tap. What is new is that taking it means *nothing opens* — a lantern
      // has no card.
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

    test('a plant is still the plant, with objects all around it', () {
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

    test('bare soil is a plot, where the sky is nothing at all', () {
      // The distinction ticket 12 had no use for and the picker cannot do
      // without: a plot the garden has is somewhere to put something, and a
      // plot it has not unlocked is not.
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
      // And neither is a plant, so ticket 12's "does nothing" is untouched.
      expect(test.plantAt(centreOf(GardenPlots.inPlacementOrder[5])), isNull);
    });

    test('the sky over an object is not the object', () {
      // The footprint is what makes this true: a lantern reaches half its box
      // and the top of that box is sky. Without it, the tap would land on the
      // lantern from three plots away.
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

  group('the pictures', () {
    test('every kind has one, and no two of them are the same', () {
      final rects = {
        for (final kind in DecorKind.values) atlas.rectForDecor(kind),
      };

      expect(rects, hasLength(DecorKind.values.length));
    });

    test('no object fills its cell the way a plant does', () {
      // The rule the shapes are written to: decor is the furniture of a garden
      // and the plants are what it is for. Nothing standing in a plot should
      // out-reach the tree the user grew.
      final tallest = DecorKind.values
          .map((kind) => atlas.footprintForDecor(kind))
          .map((box) => box.bottom - box.top)
          .reduce((a, b) => a > b ? a : b);
      final oak = atlas.footprintFor(PlantSpecies.oak);

      expect(tallest, lessThan(oak.bottom - oak.top));
    });

    test('every footprint stands on the bottom of its cell and stays inside it',
        () {
      // Inside, because the cells are two pixels apart in the texture: an
      // object that painted past its own cell would blit a neighbour's edge
      // into the garden.
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
