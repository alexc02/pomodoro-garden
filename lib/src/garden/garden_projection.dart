import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

/// The map between a [GardenPlot] and a point on screen, in both directions.
///
/// One value holds the whole of the garden's camera: how big a tile is, how far
/// the user has zoomed and how far they have dragged. Everything that needs to
/// agree about where a plot is — the painter putting sprites down, the gesture
/// deciding which plot was tapped, the clamp that stops the garden being
/// dragged off screen — asks this and nothing else, so there is no second copy
/// of the projection to fall out of step with the first.
///
/// Written out by hand rather than delegated to a `Transform` or an
/// `InteractiveViewer` for the reason ticket 07 gives: two hundred plants have
/// to be a batch of sprite instances with computed positions, not two hundred
/// widgets the framework lays out. A matrix in the widget tree could still
/// place them, but nothing could then *invert* it without asking the widget
/// tree — and the inverse is the half that ticket 12 needs and that this ticket
/// is asked to unit-test on its own.
///
/// Both grid axes run away from the viewer, so a plot's screen position is
/// `((x - y) * w/2, (x + y) * h/2)` from the garden's origin: x moves down and
/// right, y moves down and left. Nothing about that changes with the zoom; the
/// zoom is a multiplier on the tile.
@immutable
final class GardenProjection {
  const GardenProjection({
    this.scale = 1,
    this.pan = Offset.zero,
  });

  /// One plot's diamond, unzoomed.
  ///
  /// Twice as wide as it is tall — the classic two-to-one isometric tile. The
  /// ratio is what makes the grid read as ground rather than as a rotated
  /// chessboard, and it is fixed rather than a parameter because every other
  /// number here is measured against it.
  static const Size tile = Size(88, 44);

  /// The square a plant is drawn in, unzoomed, standing on its plot.
  ///
  /// A side of a full tile width rather than a tile height: a large tree is
  /// meant to be the dominant feature of a garden and has to be taller than the
  /// ground it stands on. It is the same square `PlantPainter` uses on the timer
  /// screen, which is what makes the plant the user watched grow the same shape
  /// as the one they find in the garden.
  static double get spriteSide => tile.width;

  /// How far out the user can zoom. Far enough to see a full garden of two
  /// hundred plots on a phone, and no further — past this the plants stop being
  /// distinguishable and the screen is just texture.
  static const double minimumScale = 0.35;

  /// How far in. Capped where the atlas runs out of pixels: past this a sprite
  /// is being magnified rather than drawn, and it shows.
  static const double maximumScale = 2.5;

  /// The zoom, 1 being a tile at [tile]'s size.
  final double scale;

  /// Where the garden's origin — the middle of plot (0, 0) — sits on screen.
  final Offset pan;

  /// Half a tile, zoomed. The two numbers every conversion is built from.
  double get _halfWidth => tile.width * scale / 2;
  double get _halfHeight => tile.height * scale / 2;

  /// Where the middle of [plot]'s tile lands on screen.
  Offset centreOf(GardenPlot plot) => pan +
      Offset(
        (plot.x - plot.y) * _halfWidth,
        (plot.x + plot.y) * _halfHeight,
      );

  /// The four corners of [plot]'s tile, clockwise from the top.
  List<Offset> tileCorners(GardenPlot plot) {
    final centre = centreOf(plot);
    return [
      centre.translate(0, -_halfHeight),
      centre.translate(_halfWidth, 0),
      centre.translate(0, _halfHeight),
      centre.translate(-_halfWidth, 0),
    ];
  }

  /// The square [plot]'s plant is drawn in: standing on the middle of the tile,
  /// centred across it.
  Rect spriteBounds(GardenPlot plot) {
    final side = spriteSide * scale;
    final centre = centreOf(plot);
    return Rect.fromLTWH(centre.dx - side / 2, centre.dy - side, side, side);
  }

  /// The plot whose tile [point] falls in.
  ///
  /// The inverse of [centreOf], and total: every point on screen is inside
  /// exactly one tile of the infinite grid, whether or not the garden has
  /// unlocked that one. A caller that wants "the plot the user tapped, if any"
  /// checks the answer against the plots the garden has — see `GardenHitTest`,
  /// which gets both of ticket 12's "does nothing" cases out of asking the
  /// layout what is growing in whatever this returns.
  ///
  /// Rounding rather than flooring, because a plot's tile is centred on it: the
  /// diamond around plot (2, -1) is every point whose fractional coordinates
  /// round to (2, -1).
  GardenPlot plotUnder(Offset point) {
    final from = point - pan;
    // (x - y) and (x + y): the two diagonals the grid is built on.
    final across = from.dx / _halfWidth;
    final down = from.dy / _halfHeight;

    return GardenPlot(
      ((across + down) / 2).round(),
      ((down - across) / 2).round(),
    );
  }

  /// The rectangle every plot in [plots] and the plants standing on them
  /// occupy, at this projection's zoom.
  ///
  /// Empty for an empty garden, which cannot happen — the garden has twelve
  /// plots before a single session is finished.
  Rect boundsOf(Iterable<GardenPlot> plots) {
    var bounds = Rect.zero;
    var first = true;
    for (final plot in plots) {
      // The union of the tile and the sprite standing on it: a plant reaches
      // well above its own tile, and a garden bounded by its ground would let
      // the user drag the tallest tree off the top of the screen.
      final around = spriteBounds(plot).expandToInclude(
        Rect.fromCenter(
          center: centreOf(plot),
          width: _halfWidth * 2,
          height: _halfHeight * 2,
        ),
      );
      bounds = first ? around : bounds.expandToInclude(around);
      first = false;
    }
    return bounds;
  }

  /// This projection, dragged by [delta].
  GardenProjection pannedBy(Offset delta) =>
      GardenProjection(scale: scale, pan: pan + delta);

  /// This projection zoomed to [scale], keeping whatever is under [around]
  /// under it.
  ///
  /// Pinching about a point means that point does not move: the garden grows
  /// out from between the user's fingers rather than from the middle of the
  /// screen. Clamped to the zoom range here rather than at the gesture, so
  /// there is one place that decides how far in and out the garden goes.
  GardenProjection zoomedTo(double scale, {required Offset around}) {
    final zoom = scale.clamp(minimumScale, maximumScale);
    // Where the fixed point is in the garden's own coordinates, which is the
    // one thing the zoom must not change.
    final anchored = (around - pan) / this.scale;
    return GardenProjection(scale: zoom, pan: around - anchored * zoom);
  }

  /// This projection, panned as little as possible to keep the garden on
  /// screen.
  ///
  /// Two rules, and which one applies depends on whether the garden is bigger
  /// than the window looking at it:
  ///
  /// - A garden larger than the viewport may be dragged, but not past its own
  ///   edges: there is never a band of empty screen beside it.
  /// - A garden smaller than the viewport is centred and stays centred. A small
  ///   garden that could be dragged into a corner would be a garden a new user
  ///   could lose, and their garden is twelve plots for their first ten
  ///   sessions.
  GardenProjection boundedTo(Size viewport, Iterable<GardenPlot> plots) {
    final garden = boundsOf(plots);
    if (garden.isEmpty) return this;

    return GardenProjection(
      scale: scale,
      pan: Offset(
        pan.dx + _slack(garden.left, garden.right, viewport.width),
        pan.dy + _slack(garden.top, garden.bottom, viewport.height),
      ),
    );
  }

  /// How far the garden has to move along one axis to obey [boundedTo]'s rules.
  static double _slack(double low, double high, double extent) {
    if (high - low <= extent) {
      // Smaller than the window: centred, and the move is however far off
      // centre it currently is.
      return (extent - (low + high)) / 2;
    }
    if (low > 0) return -low;
    if (high < extent) return extent - high;
    return 0;
  }

  /// The projection that shows all of [plots] at once, centred, at the largest
  /// zoom that fits.
  ///
  /// What the garden opens on. A user's first sight of it should be the whole
  /// thing rather than a corner they have to hunt around, and a user with two
  /// hundred plants should see two hundred plants.
  static GardenProjection fitting(Size viewport, Iterable<GardenPlot> plots) {
    final unzoomed = const GardenProjection().boundsOf(plots);
    if (unzoomed.isEmpty || viewport.isEmpty) return const GardenProjection();

    final fits = math.min(
      viewport.width / unzoomed.width,
      viewport.height / unzoomed.height,
    );

    return GardenProjection(
      scale: fits.clamp(minimumScale, maximumScale),
    ).boundedTo(viewport, plots);
  }

  @override
  bool operator ==(Object other) =>
      other is GardenProjection && other.scale == scale && other.pan == pan;

  @override
  int get hashCode => Object.hash(scale, pan);

  @override
  String toString() => 'GardenProjection(scale: $scale, pan: $pan)';
}
