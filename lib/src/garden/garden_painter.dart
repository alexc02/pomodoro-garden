import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'garden_projection.dart';
import 'garden_atlas.dart';
import 'golden_shimmer.dart';
import 'plant_sway.dart';

/// One `drawAtlas` batch: a quad per plot and a quad per thing standing on one,
/// paired with the piece of the texture each is cut from.
///
/// The two lists are parallel and in draw order, which is what `drawAtlas`
/// wants and what makes the depth sort assertable: entry *n* is drawn over
/// entry *n - 1*.
typedef GardenBatch = ({
  List<RSTransform> transforms,
  List<Rect> rects,
  List<Color>? colors,
});

/// The whole garden, in one draw call.
///
/// Every plot, every plant on it and every one of REQ-040's objects becomes one
/// quad in a single `Canvas.drawAtlas` batch, in the order [GardenLayout] hands
/// the plots over — which is back to front, so a thing nearer the viewer is
/// drawn later and overlaps the one behind it. The depth sort is a property of
/// the plot order rather than of the widget tree, which is what lets two
/// hundred plants cost one call instead of two hundred layers.
///
/// **Decor is depth-sorted by construction rather than by a rule of its own.**
/// A plot holds a plant or an object and never both, so both come out of the
/// same walk over the same ordered list — which is the only way a bench can be
/// in front of the tree behind it *and* behind the tree in front of it. A
/// separate pass over the furniture, whether before the plants or after them,
/// would put every object on one side of every plant.
///
/// **REQ-023's sway is a field of the transform, not a layer over it.** The
/// batch already carried a rotation per quad and it was being passed zero; a
/// leaning garden fills it in. So two hundred plants swaying costs two hundred
/// `sin` calls a frame and not one quad, one draw call or one widget more than a
/// still garden — which is the reason ticket 07 left the sway for this ticket
/// rather than building it as two hundred `Transform`s and finding out later.
///
/// The painter owns no colours and no shapes. What a plot's ground looks like,
/// what a species looks like and what a lantern looks like are all decided when
/// [GardenAtlas] is baked; all that happens here is arithmetic turning plots
/// into transforms.
final class GardenPainter extends CustomPainter {
  GardenPainter({
    required this.layout,
    required this.projection,
    required this.atlas,
    this.sway,
  }) : super(repaint: sway);

  /// The garden: which plots there are, and what is in them.
  final GardenLayout layout;

  /// Where those plots are on screen.
  final GardenProjection projection;

  /// The texture every quad is cut from.
  final GardenAtlas atlas;

  /// REQ-023's sway, as one loop the whole garden leans off — or null for a
  /// garden that is to stand still, which is a phone with reduce-motion on.
  ///
  /// Null is *not* how a hidden tab stops swaying: that is `TickerMode`, which
  /// mutes the controller itself, so the painter goes on holding an animation
  /// that has stopped producing frames. Null is for the case where the plants
  /// must be drawn upright rather than merely frozen wherever the sine had got
  /// to.
  ///
  /// **Passed as an `Animation` and handed to `super.repaint` rather than read
  /// as a number, and that is the point of it.** A painter given a `double`
  /// would need a new painter for every frame of the sway, which means a
  /// `setState` in [GardenView], which means rebuilding and re-laying-out the
  /// whole tab sixty times a second to move some pixels. Listening to the
  /// controller instead repaints and does nothing else: no build, no layout, and
  /// the batch arithmetic below is the entire per-frame cost of a swaying
  /// garden. On a screen that now animates continuously, that difference is the
  /// battery criterion in PRD §4.4.
  final Animation<double>? sway;

  @override
  void paint(Canvas canvas, Size size) {
    final batch = batchFor(size);
    atlas.drawInto(
      canvas,
      transforms: batch.transforms,
      rects: batch.rects,
      colors: batch.colors,
    );
  }

  /// The quads this painter would draw into a window of [size], back to front.
  ///
  /// Separated from [paint] so that the ordering can be asserted on directly. A
  /// depth sort checked only by looking at the screen is a depth sort checked
  /// by eye, and this one is the difference between a garden and a pile.
  GardenBatch batchFor(Size size) {
    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    // REQ-021's golden garden: a colour per quad, carried only once it has
    // been earned, so every other garden draws exactly as it always has.
    final colors = GoldenShimmer.earnedBy(layout) ? <Color>[] : null;
    const untouched = Color(0x00000000);

    // Where the shared sway loop has got to, read once for the whole batch. Null
    // is a garden holding still, and it costs the loop below nothing at all.
    final turn = sway?.value;

    // Which plots are worth putting in the batch, as a region their *centres*
    // have to fall in. Asymmetric, because a plant is not centred on its plot:
    // it stands on it and grows upwards, so a plot a full sprite below the top
    // edge can still have a canopy on screen while one below the bottom edge
    // can only show the near half of its own tile.
    final side = GardenProjection.spriteSide * projection.scale;
    final visible = Rect.fromLTRB(
      -side / 2,
      -side,
      size.width + side / 2,
      size.height + GardenProjection.tile.height * projection.scale / 2,
    );

    // The two scales the batch uses, computed once rather than per plot. Both
    // are the same ratio — how big the thing is drawn against how big it was
    // baked — and neither depends on which plot is being drawn.
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
      final ground = occupied ? atlas.plantedSoil : atlas.emptySoil;

      // The ground first: a tile is hung from the middle of its diamond, which
      // is where the projection says the plot is.
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

      // Then whatever is standing on it, hung from the bottom middle of its
      // cell — the point the sprite painted itself standing on — so that it
      // stands on the ground rather than floating over the middle of it. One
      // anchor for both, because both were baked into a square cell the same
      // way: nothing here has to know whether it is drawing an oak or a bench.
      final Rect picture;
      if (plant != null) {
        picture = atlas.rectFor(plant.species);
      } else if (item != null) {
        picture = atlas.rectForDecor(item.kind);
      } else {
        continue;
      }

      // REQ-021's enchanted willow stands in a halo of its own light: a quad
      // behind it, hung from the same point and a little larger, which leans
      // with nothing because light does not sway.
      if (plant?.species == PlantSpecies.enchantedWillow) {
        transforms.add(RSTransform.fromComponents(
          rotation: 0,
          scale: plantScale * 1.25,
          anchorX: atlas.plantCell / 2,
          anchorY: atlas.plantCell,
          translateX: centre.dx,
          translateY: centre.dy,
        ));
        rects.add(atlas.glowHalo);
        colors?.add(untouched);
      }

      // REQ-023's lean, and the whole of what it costs: one `sin` per plant per
      // frame, into a field the batch was already carrying. `RSTransform`
      // rotates about its anchor, and the anchor here is the bottom middle of
      // the cell — the point the plant is standing on — so a leaning plant
      // pivots at its base like something rooted rather than sliding sideways.
      //
      // Plants only. An object stands still, because a bench does not sway and a
      // pond cannot; the wind is in the planting, not in the furniture.
      //
      // Seeded from the session where there is one, so that a plant leans at the
      // same point in the loop here as it did on the timer screen the user
      // watched it grow on. REQ-021's bonus plants have no session and were
      // never on that screen, so their own id is both stable and enough.
      transforms.add(RSTransform.fromComponents(
        rotation: turn == null || plant == null
            ? 0
            : PlantSway.leanAt(turn, seed: plant.sessionId ?? plant.id),
        scale: plantScale,
        anchorX: atlas.plantCell / 2,
        anchorY: atlas.plantCell,
        translateX: centre.dx,
        translateY: centre.dy,
      ));
      rects.add(picture);
      colors?.add(plant == null
          ? untouched
          : GoldenShimmer.tintAt(turn, seed: plant.sessionId ?? plant.id));
    }

    return (transforms: transforms, rects: rects, colors: colors);
  }

  /// The sway is deliberately not compared here. It repaints through
  /// `super.repaint`, which is a subscription rather than a comparison, so a
  /// frame of the sway never reaches this method — and a painter that *was*
  /// rebuilt while the sway ran would answer false and be right to: nothing it
  /// is being asked about has changed.
  @override
  bool shouldRepaint(GardenPainter old) =>
      !identical(old.layout, layout) ||
      old.projection != projection ||
      !identical(old.atlas, atlas) ||
      old.sway != sway;
}
