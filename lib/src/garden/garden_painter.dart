import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'garden_projection.dart';
import 'garden_atlas.dart';
import 'golden_shimmer.dart';
import 'plant_sway.dart';

/// One `drawAtlas` batch: a quad per plot and per thing standing on one, with
/// the texture rect each is cut from. Parallel lists in draw order (entry n is
/// drawn over n - 1).
typedef GardenBatch = ({
  List<RSTransform> transforms,
  List<Rect> rects,
  List<Color>? colors,
});

/// The whole garden in one `drawAtlas` call.
///
/// Plots come from [GardenLayout] back to front, so nearer things draw later
/// and overlap. Plants and decor share that one walk (a plot holds one or the
/// other), which is what puts a bench correctly between the trees in front of
/// and behind it.
///
/// Sway is just the per-quad rotation, so a swaying garden costs a `sin` per
/// plant and nothing else. All colours and shapes are baked into
/// [GardenAtlas]; this only turns plots into transforms.
final class GardenPainter extends CustomPainter {
  GardenPainter({
    required this.layout,
    required this.projection,
    required this.atlas,
    this.sway,
    this.held,
    this.heldOutline = const Color(0x00000000),
  }) : super(repaint: sway);

  /// How far the held thing is raised, as a fraction of a tile's height.
  static const double heldLift = 0.22;

  final GardenLayout layout;

  final GardenProjection projection;

  /// The texture every quad is cut from.
  final GardenAtlas atlas;

  /// The shared sway loop, or null to draw everything upright (reduce-motion).
  /// Hidden tabs are paused by `TickerMode`, not by passing null.
  ///
  /// Passed as an `Animation` into `super.repaint` so each frame is a repaint
  /// only, with no rebuild or relayout of [GardenView].
  final Animation<double>? sway;

  /// The plot whose plant or decor is in hand while arranging, or null. It's
  /// drawn raised by [heldLift], with its tile outlined in [heldOutline].
  /// Nothing animates, so it reads the same under reduce-motion.
  final GardenPlot? held;

  final Color heldOutline;

  @override
  void paint(Canvas canvas, Size size) {
    final batch = batchFor(size);
    atlas.drawInto(
      canvas,
      transforms: batch.transforms,
      rects: batch.rects,
      colors: batch.colors,
    );
    _outlineHeld(canvas);
  }

  /// Drawn after the batch rather than in it, since the atlas colours are
  /// baked in, and so a nearer plant overlapping the plot can't hide it.
  void _outlineHeld(Canvas canvas) {
    final plot = held;
    if (plot == null || !layout.hasPlot(plot)) return;

    final corners = projection.tileCorners(plot);
    final diamond = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.drawPath(
      diamond,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        // Thinner zoomed out, but never a hairline.
        ..strokeWidth = (2.5 * projection.scale).clamp(1.5, 4.0)
        ..color = heldOutline,
    );
  }

  /// The quads this would draw into a window of [size], back to front.
  /// Separate from [paint] so tests can assert on the depth order.
  GardenBatch batchFor(Size size) {
    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    // Per-quad colours only once the golden garden is earned.
    final colors = GoldenShimmer.earnedBy(layout) ? <Color>[] : null;
    const untouched = Color(0x00000000);

    // Read once for the whole batch; null means holding still.
    final turn = sway?.value;

    // Region plot centres must fall in to be drawn. Asymmetric because plants
    // grow upwards: a plot below the top edge can still show its canopy.
    final side = GardenProjection.spriteSide * projection.scale;
    final visible = Rect.fromLTRB(
      -side / 2,
      -side,
      size.width + side / 2,
      size.height + GardenProjection.tile.height * projection.scale / 2,
    );

    final soilScale =
        GardenProjection.tile.width * projection.scale / GardenAtlas.cellWidth;
    final plantScale =
        GardenProjection.spriteSide * projection.scale / atlas.plantCell;

    for (final plot in layout.plots) {
      final centre = projection.centreOf(plot);
      if (!visible.contains(centre)) continue;

      final plant = layout.plantIn(plot);
      final item = plant == null ? layout.decorIn(plot) : null;
      final occupied = plant != null || item != null;
      // Only what stands on the tile is raised, not the tile itself.
      final base = plot == held
          ? centre.dy -
              GardenProjection.tile.height * projection.scale * heldLift
          : centre.dy;
      final ground = occupied ? atlas.plantedSoil : atlas.emptySoil;

    // Ground tile, anchored at the middle of its diamond.
      transforms.add(RSTransform.fromComponents(
        rotation: 0,
        scale: soilScale,
        anchorX: ground.width / 2,
        anchorY: ground.height / 2,
        translateX: centre.dx,
        translateY: centre.dy,
      ));
      rects.add(ground);
      colors?.add(untouched);

      // Plant or decor, anchored at the bottom middle of its cell so it stands
      // on the ground. Both are baked the same way, so one anchor works.
      final Rect picture;
      if (plant != null) {
        picture = atlas.rectFor(plant.species);
      } else if (item != null) {
        picture = atlas.rectForDecor(item.kind);
      } else {
        continue;
      }

      // Enchanted willow halo: a slightly larger quad behind it that doesn't
      // sway.
      if (plant?.species == PlantSpecies.enchantedWillow) {
        transforms.add(RSTransform.fromComponents(
          rotation: 0,
          scale: plantScale * 1.25,
          anchorX: atlas.plantCell / 2,
          anchorY: atlas.plantCell,
          translateX: centre.dx,
          translateY: base,
        ));
        rects.add(atlas.glowHalo);
        colors?.add(untouched);
      }

      // Rotation about the anchor (the plant's base), so it pivots like
      // something rooted. Decor doesn't sway. Seeded from the session id so the
      // phase matches the timer screen; bonus plants use their own id.
      transforms.add(RSTransform.fromComponents(
        rotation: turn == null || plant == null
            ? 0
            : PlantSway.leanAt(turn, seed: plant.sessionId ?? plant.id),
        scale: plantScale,
        anchorX: atlas.plantCell / 2,
        anchorY: atlas.plantCell,
        translateX: centre.dx,
        translateY: base,
      ));
      rects.add(picture);
      colors?.add(plant == null
          ? untouched
          : GoldenShimmer.tintAt(turn, seed: plant.sessionId ?? plant.id));
    }

    return (transforms: transforms, rects: rects, colors: colors);
  }

  // Sway frames come through `super.repaint`, so they never reach this.
  @override
  bool shouldRepaint(GardenPainter old) =>
      !identical(old.layout, layout) ||
      old.projection != projection ||
      !identical(old.atlas, atlas) ||
      old.sway != sway ||
      old.held != held ||
      old.heldOutline != heldOutline;
}
