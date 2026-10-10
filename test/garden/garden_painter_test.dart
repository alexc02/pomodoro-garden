import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/garden/garden_painter.dart';
import 'package:pomodoro_garden/src/garden/garden_projection.dart';
import 'package:pomodoro_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pomodoro_garden/src/garden/garden_atlas.dart';
import 'package:pomodoro_garden/src/garden/plant_sprite.dart';

import '../support/decor_fixtures.dart';

/// What the garden turns into on its way to the GPU.
///
/// The batch is the unit of interest, not the pixels: ticket 07's two
/// requirements that a test can actually hold are that every plant becomes one
/// quad in one `drawAtlas` call, and that the quads come out back to front.

final DateTime _anchor = DateTime.utc(2026, 8, 11, 9, 41);

const PlantPalette _palette = PlantPalette(
  foliage: Color(0xFF4CAF50),
  bloom: Color(0xFFFFC107),
  soil: Color(0xFF795548),
);

GardenAtlas _atlas() => GardenAtlas.bake(
      GardenAtlasRecipe(
        registry: const PlaceholderPlantSpriteRegistry(),
        decorRegistry: testDecorRegistry,
        decorPalette: testDecorPalette,
        palettes: {
          for (final species in PlantSpecies.values) species: _palette,
        },
        soil: const Color(0xFF795548),
        decor: const Color(0xFF9A9A92),
      ),
    );

Plant _plant(int n, GardenPlot plot) => Plant(
      id: 'plant-$n',
      sessionId: 'session-$n',
      type: PlantType.largeTree,
      species: PlantSpecies.oak,
      stage: GrowthStage.mature,
      plantedAt: _anchor.add(Duration(days: n)),
      sessionDuration: const Duration(minutes: 90),
      plot: plot,
    );

GardenLayout _garden(int plants, {int completedSessions = 0}) =>
    GardenLayout.of(
      plants: [
        for (var n = 0; n < plants; n++)
          _plant(n, GardenPlots.inPlacementOrder[n]),
      ],
      completedSessions: completedSessions,
    );

/// A window big enough that nothing is culled for being off screen.
const Size _window = Size(4000, 4000);

/// One quad of the batch, read back into the terms it was written in.
///
/// `RSTransform` stores the transformed *corner*, not the anchor it was built
/// from, so the point a quad was hung at has to be recovered — and the anchor
/// depends on which kind of quad it is: a tile hangs from the middle of itself,
/// a plant from the bottom middle.
typedef _Quad = ({Rect rect, bool ground, Offset plot});

List<_Quad> _quads(GardenBatch batch, GardenAtlas atlas) => [
      for (var index = 0; index < batch.rects.length; index++)
        () {
          final rect = batch.rects[index];
          final transform = batch.transforms[index];
          final ground =
              rect == atlas.emptySoil || rect == atlas.plantedSoil;
          return (
            rect: rect,
            ground: ground,
            plot: Offset(
              transform.tx + transform.scos * rect.width / 2,
              transform.ty +
                  transform.scos * (ground ? rect.height / 2 : rect.height),
            ),
          );
        }(),
    ];

GardenPainter _painter(
  GardenLayout layout,
  GardenAtlas atlas, {
  GardenProjection projection = const GardenProjection(pan: Offset(2000, 2000)),
}) =>
    GardenPainter(layout: layout, projection: projection, atlas: atlas);

void main() {
  late GardenAtlas atlas;

  setUp(() => atlas = _atlas());
  tearDown(() => atlas.dispose());

  test('one quad per plot, and one more for each plant standing on one', () {
    // A garden of five plants after five sessions: twelve plots, five of them
    // planted. Seventeen quads, in one batch — not seventeen draw calls and not
    // seventeen widgets.
    final batch = _painter(_garden(5, completedSessions: 5), atlas)
        .batchFor(_window);

    expect(batch.transforms, hasLength(12 + 5));
    expect(batch.rects, hasLength(batch.transforms.length));
  });

  test('an empty garden is twelve plots of bare soil and nothing else', () {
    final batch = _painter(_garden(0), atlas).batchFor(_window);

    expect(batch.transforms, hasLength(12));
    expect(batch.rects.toSet(), {atlas.emptySoil});
  });

  test('a planted plot is drawn on different ground from an empty one', () {
    // "Newly unlocked plots are visible as empty soil": the user has to be able
    // to see which plots are waiting for something.
    final batch = _painter(_garden(3, completedSessions: 3), atlas)
        .batchFor(_window);

    expect(batch.rects.where((rect) => rect == atlas.emptySoil), hasLength(9));
    expect(batch.rects.where((rect) => rect == atlas.plantedSoil), hasLength(3));
    expect(
      batch.rects.where((rect) => rect == atlas.rectFor(PlantSpecies.oak)),
      hasLength(3),
    );
  });

  test('quads come out back to front, so a plant in front overlaps the one '
      'behind it', () {
    final batch = _painter(_garden(200, completedSessions: 500), atlas)
        .batchFor(_window);

    var previous = double.negativeInfinity;
    for (final quad in _quads(batch, atlas)) {
      expect(
        quad.plot.dy,
        // A hair of tolerance: the anchor is recovered from a transform that
        // put it there, and the two are a rounding error apart. Anything that
        // is actually out of order is out by half a tile.
        greaterThanOrEqualTo(previous - 0.001),
        reason: 'a quad was drawn behind one that had already been drawn',
      );
      previous = quad.plot.dy;
    }
  });

  test('a plant is drawn immediately after the ground it stands on', () {
    final quads = _quads(_painter(_garden(3), atlas).batchFor(_window), atlas);

    for (var index = 0; index < quads.length; index++) {
      if (quads[index].ground) continue;
      expect(index, greaterThan(0));
      expect(quads[index - 1].ground, isTrue,
          reason: 'a plant with no ground under it');
      expect(quads[index - 1].rect, atlas.plantedSoil);
      expect(quads[index - 1].plot.dy, closeTo(quads[index].plot.dy, 0.0001),
          reason: 'both hang off the middle of the same tile');
    }
  });

  test('every plot lands where the projection says it is', () {
    const projection = GardenProjection(scale: 1.4, pan: Offset(2000, 2000));
    final layout = _garden(4, completedSessions: 4);
    final quads = _quads(
      _painter(layout, atlas, projection: projection).batchFor(_window),
      atlas,
    );

    for (final plot in layout.plots) {
      final at = projection.centreOf(plot);
      expect(
        quads.any((quad) =>
            (quad.plot.dx - at.dx).abs() < 0.001 &&
            (quad.plot.dy - at.dy).abs() < 0.001),
        isTrue,
        reason: '$plot should have been drawn at $at',
      );
    }
  });

  test('a plant is scaled from the size it was baked to the size it is drawn',
      () {
    const projection = GardenProjection(scale: 2, pan: Offset(2000, 2000));
    final batch = _painter(_garden(1), atlas, projection: projection)
        .batchFor(_window);

    // RSTransform's scale is in `scos` when there is no rotation.
    expect(
      batch.transforms[1].scos,
      closeTo(GardenProjection.spriteSide * 2 / atlas.plantCell, 0.0001),
    );
  });

  group('culling', () {
    test('plots the window cannot see are not put in the batch', () {
      // Zoomed in on a full garden, most of it is off screen. Two hundred
      // plants must not cost two hundred quads to show four.
      const projection = GardenProjection(scale: 2.5, pan: Offset(200, 400));
      final batch = _painter(
        _garden(200, completedSessions: 500),
        atlas,
        projection: projection,
      ).batchFor(const Size(400, 800));

      expect(batch.transforms.length, lessThan(200));
    });

    test('a whole garden zoomed out to fit is all in the batch', () {
      final layout = _garden(200, completedSessions: 500);
      const window = Size(400, 800);
      final projection = GardenProjection.fitting(window, layout.plots);

      final batch =
          _painter(layout, atlas, projection: projection).batchFor(window);

      expect(batch.transforms, hasLength(400),
          reason: 'two hundred plots and the two hundred plants on them');
    });
  });

  group('repainting', () {
    test('a camera that has not moved does not repaint', () {
      final layout = _garden(3);
      final painter = _painter(layout, atlas);

      expect(painter.shouldRepaint(_painter(layout, atlas)), isFalse);
    });

    test('a dragged camera repaints', () {
      final layout = _garden(3);

      expect(
        _painter(layout, atlas).shouldRepaint(
          _painter(layout, atlas,
              projection: const GardenProjection(pan: Offset(1, 1))),
        ),
        isTrue,
      );
    });

    test('a new plant repaints', () {
      expect(
        _painter(_garden(3), atlas).shouldRepaint(_painter(_garden(4), atlas)),
        isTrue,
      );
    });
  });
}
