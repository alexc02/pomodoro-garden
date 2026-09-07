import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

/// Maps between a [GardenPlot] and a screen point, both ways.
///
/// Holds the whole camera (tile size, zoom, pan) so the painter, hit-testing
/// and pan clamping all agree. Hand-rolled instead of `Transform` or
/// `InteractiveViewer` because the plants are drawn as one atlas batch, and we
/// need to invert the mapping without asking the widget tree.
///
/// Both grid axes run away from the viewer: a plot sits at
/// `((x - y) * w/2, (x + y) * h/2)` from the origin, so x goes down-right and y
/// goes down-left. Zoom just scales the tile.
@immutable
final class GardenProjection {
  const GardenProjection({
    this.scale = 1,
    this.pan = Offset.zero,
  });

  /// One plot's diamond, unzoomed: the classic 2:1 isometric tile.
  static const Size tile = Size(88, 44);

  /// The square a plant is drawn in, unzoomed. A full tile wide so large trees
  /// tower over their plot; matches `PlantPainter` on the timer screen.
  static double get spriteSide => tile.width;

  /// Zoomed out far enough to see a full 200-plot garden on a phone.
  static const double minimumScale = 0.35;

  /// Past this the atlas runs out of pixels and sprites look magnified.
  static const double maximumScale = 2.5;

  /// 1 is a tile at [tile]'s size.
  final double scale;

  /// Where the middle of plot (0, 0) sits on screen.
  final Offset pan;

  double get _halfWidth => tile.width * scale / 2;
  double get _halfHeight => tile.height * scale / 2;

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

  /// The square [plot]'s sprite is drawn in, standing on the tile's centre.
  Rect spriteBounds(GardenPlot plot) {
    final side = spriteSide * scale;
    final centre = centreOf(plot);
    return Rect.fromLTWH(centre.dx - side / 2, centre.dy - side, side, side);
  }

  /// The plot whose tile [point] falls in. Inverse of [centreOf].
  ///
  /// Total over the infinite grid, so callers check the result against the
  /// garden's real plots (see `GardenHitTest`). Rounds rather than floors
  /// because tiles are centred on their plot.
  GardenPlot plotUnder(Offset point) {
    final from = point - pan;
    // Coordinates along the two grid diagonals.
    final across = from.dx / _halfWidth;
    final down = from.dy / _halfHeight;

    return GardenPlot(
      ((across + down) / 2).round(),
      ((down - across) / 2).round(),
    );
  }

  /// The rect covering every plot in [plots] plus the sprites standing on them,
  /// at this zoom.
  Rect boundsOf(Iterable<GardenPlot> plots) {
    var bounds = Rect.zero;
    var first = true;
    for (final plot in plots) {
      // Include the sprite so tall trees can't be dragged off the top.
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

  GardenProjection pannedBy(Offset delta) =>
      GardenProjection(scale: scale, pan: pan + delta);

  /// Zoomed to [scale] (clamped) about [around], so the point between the
  /// user's fingers stays put.
  GardenProjection zoomedTo(double scale, {required Offset around}) {
    final zoom = scale.clamp(minimumScale, maximumScale);
    // The fixed point in garden coordinates.
    final anchored = (around - pan) / this.scale;
    return GardenProjection(scale: zoom, pan: around - anchored * zoom);
  }

  /// Panned as little as possible to keep the garden on screen.
  ///
  /// Bigger than the viewport: can be dragged, but never past its own edges.
  /// Smaller: stays centred, so a new 12-plot garden can't get lost in a
  /// corner.
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

  /// The move needed along one axis to satisfy [boundedTo].
  static double _slack(double low, double high, double extent) {
    if (high - low <= extent) {
      return (extent - (low + high)) / 2;
    }
    if (low > 0) return -low;
    if (high < extent) return extent - high;
    return 0;
  }

  /// All of [plots], centred, at the largest zoom that fits. What the garden
  /// opens on.
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
