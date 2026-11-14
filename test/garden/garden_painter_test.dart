import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/garden_projection.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/garden_atlas.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';

import '../support/decor_fixtures.dart';

// The batch, not the pixels: every plant is one quad in one drawAtlas call,
// and quads come out back to front.

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

/// Big enough that nothing is culled.
const Size _window = Size(4000, 4000);

/// One quad read back. RSTransform stores the transformed corner, so the
/// anchor has to be recovered: tiles hang from their middle, plants from the
/// bottom middle.
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

  test('one quad per plot plus one per plant', () {
    // Five plants, twelve plots: 17 quads in one batch.
    final batch = _painter(_garden(5, completedSessions: 5), atlas)
        .batchFor(_window);

    expect(batch.transforms, hasLength(12 + 5));
    expect(batch.rects, hasLength(batch.transforms.length));
  });

  test('empty garden is twelve bare plots', () {
    final batch = _painter(_garden(0), atlas).batchFor(_window);

    expect(batch.transforms, hasLength(12));
    expect(batch.rects.toSet(), {atlas.emptySoil});
  });

  test('planted plots use different ground', () {
    // Empty unlocked plots have to look different from planted ones.
    final batch = _painter(_garden(3, completedSessions: 3), atlas)
        .batchFor(_window);

    expect(batch.rects.where((rect) => rect == atlas.emptySoil), hasLength(9));
    expect(batch.rects.where((rect) => rect == atlas.plantedSoil), hasLength(3));
    expect(
      batch.rects.where((rect) => rect == atlas.rectFor(PlantSpecies.oak)),
      hasLength(3),
    );
  });

  test('quads are ordered back to front', () {
    final batch = _painter(_garden(200, completedSessions: 500), atlas)
        .batchFor(_window);

    var previous = double.negativeInfinity;
    for (final quad in _quads(batch, atlas)) {
      expect(
        quad.plot.dy,
        // Rounding tolerance. Real misordering is off by half a tile.
        greaterThanOrEqualTo(previous - 0.001),
        reason: 'out of order',
      );
      previous = quad.plot.dy;
    }
  });

  test('plant follows its ground quad', () {
    final quads = _quads(_painter(_garden(3), atlas).batchFor(_window), atlas);

    for (var index = 0; index < quads.length; index++) {
      if (quads[index].ground) continue;
      expect(index, greaterThan(0));
      expect(quads[index - 1].ground, isTrue,
          reason: 'plant with no ground');
      expect(quads[index - 1].rect, atlas.plantedSoil);
      expect(quads[index - 1].plot.dy, closeTo(quads[index].plot.dy, 0.0001),
          reason: 'same tile centre');
    }
  });

  test('plots match the projection', () {
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

  test('plant is scaled from baked to drawn size', () {
    const projection = GardenProjection(scale: 2, pan: Offset(2000, 2000));
    final batch = _painter(_garden(1), atlas, projection: projection)
        .batchFor(_window);

    // With no rotation, RSTransform's scale is scos.
    expect(
      batch.transforms[1].scos,
      closeTo(GardenProjection.spriteSide * 2 / atlas.plantCell, 0.0001),
    );
  });

  group('culling', () {
    test('skips offscreen plots', () {
      // Zoomed in on a full garden; showing four plants shouldn't cost 200
      // quads.
      const projection = GardenProjection(scale: 2.5, pan: Offset(200, 400));
      final batch = _painter(
        _garden(200, completedSessions: 500),
        atlas,
        projection: projection,
      ).batchFor(const Size(400, 800));

      expect(batch.transforms.length, lessThan(200));
    });

    test('zoomed-out garden is all in the batch', () {
      final layout = _garden(200, completedSessions: 500);
      const window = Size(400, 800);
      final projection = GardenProjection.fitting(window, layout.plots);

      final batch =
          _painter(layout, atlas, projection: projection).batchFor(window);

      expect(batch.transforms, hasLength(400),
          reason: '200 plots and 200 plants');
    });
  });

  group('repainting', () {
    test('no repaint without camera change', () {
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

  group('held', () {
    const projection = GardenProjection(pan: Offset(2000, 2000));
    final layout = _garden(3);
    final held = GardenPlots.inPlacementOrder[1];

    GardenBatch batch({GardenPlot? holding}) => GardenPainter(
          layout: layout,
          projection: projection,
          atlas: atlas,
          held: holding,
        ).batchFor(_window);

    test('raises only what stands in the held plot', () {
      final resting = batch();
      final lifted = batch(holding: held);

      expect(lifted.rects, resting.rects, reason: 'same quads, same order');

      final lift = GardenProjection.tile.height * GardenPainter.heldLift;
      final moved = <int>[
        for (var n = 0; n < resting.transforms.length; n++)
          if (resting.transforms[n].ty != lifted.transforms[n].ty) n,
      ];

      // One plant quad; its soil tile and every other plot stay put.
      expect(moved, hasLength(1));
      final quad = moved.single;
      expect(resting.rects[quad], atlas.rectFor(PlantSpecies.oak));
      expect(
        resting.transforms[quad].ty - lifted.transforms[quad].ty,
        // RSTransform keeps 32-bit floats.
        closeTo(lift, 1e-3),
      );
      expect(lifted.transforms[quad].tx, resting.transforms[quad].tx);
    });

    test('an empty held plot raises nothing', () {
      final empty = GardenPlots.inPlacementOrder[8];
      expect(layout.isEmpty(empty), isTrue);

      final resting = batch();
      final lifted = batch(holding: empty);

      expect(
        [for (final quad in lifted.transforms) quad.ty],
        [for (final quad in resting.transforms) quad.ty],
      );
    });

    test('repaints when the hold changes', () {
      GardenPainter painter({GardenPlot? holding, Color? outline}) =>
          GardenPainter(
            layout: layout,
            projection: projection,
            atlas: atlas,
            held: holding,
            heldOutline: outline ?? const Color(0xFFE89B9B),
          );

      expect(painter().shouldRepaint(painter()), isFalse);
      expect(painter(holding: held).shouldRepaint(painter()), isTrue);
      expect(painter().shouldRepaint(painter(holding: held)), isTrue);
      expect(
        painter(holding: held, outline: const Color(0xFF000000))
            .shouldRepaint(painter(holding: held)),
        isTrue,
      );
    });
  });
}
