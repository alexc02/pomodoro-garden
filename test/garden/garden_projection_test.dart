import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/garden_projection.dart';

// Isometric maths, tested without rendering.

/// Both ends of the zoom range and a non-integer middle.
const List<double> _zooms = [
  GardenProjection.minimumScale,
  0.73,
  1,
  1.6,
  GardenProjection.maximumScale,
];

/// Middle, both signs on both axes, and the far corner of a full garden.
final List<GardenPlot> _plots = [
  const GardenPlot(0, 0),
  const GardenPlot(1, 0),
  const GardenPlot(0, 1),
  const GardenPlot(-1, 0),
  const GardenPlot(0, -1),
  const GardenPlot(3, -4),
  const GardenPlot(-7, 6),
  GardenPlots.inPlacementOrder.last,
];

void main() {
  group('a plot on screen', () {
    test('garden centre follows the pan', () {
      const projection = GardenProjection(scale: 1, pan: Offset(120, 260));

      expect(projection.centreOf(const GardenPlot(0, 0)), const Offset(120, 260));
    });

    test('axes go away from the viewer', () {
      const projection = GardenProjection();
      final origin = projection.centreOf(const GardenPlot(0, 0));

      final right = projection.centreOf(const GardenPlot(1, 0));
      final left = projection.centreOf(const GardenPlot(0, 1));

      // x goes down-right, y down-left, same vertical amount.
      expect(right.dx, greaterThan(origin.dx));
      expect(left.dx, lessThan(origin.dx));
      expect(right.dy, greaterThan(origin.dy));
      expect(right.dy, left.dy);
    });

    test('tile is twice as wide as tall', () {
      const projection = GardenProjection();
      final corners = projection.tileCorners(const GardenPlot(0, 0));

      final width = corners[1].dx - corners[3].dx;
      final height = corners[2].dy - corners[0].dy;

      expect(width, GardenProjection.tile.width);
      expect(height, GardenProjection.tile.height);
      expect(width, 2 * height);
    });

    test('zoom scales the tile only', () {
      const near = GardenProjection(scale: 2);
      const far = GardenProjection(scale: 1);

      expect(
        near.centreOf(const GardenPlot(3, -2)),
        far.centreOf(const GardenPlot(3, -2)) * 2,
      );
    });

    test('plant stands on its tile', () {
      const projection = GardenProjection();
      const plot = GardenPlot(2, 2);
      final bounds = projection.spriteBounds(plot);
      final centre = projection.centreOf(plot);

      expect(bounds.bottom, centre.dy, reason: 'base on the ground');
      expect(bounds.center.dx, centre.dx);
      expect(bounds.height, greaterThan(GardenProjection.tile.height),
          reason: 'large tree extends above the plot');
    });
  });

  group('the inverse', () {
    test('plot round-trips at every zoom and pan', () {
      for (final scale in _zooms) {
        for (final pan in const [
          Offset.zero,
          Offset(200, 400),
          Offset(-1337.5, 91.25),
        ]) {
          final projection = GardenProjection(scale: scale, pan: pan);
          for (final plot in _plots) {
            expect(
              projection.plotUnder(projection.centreOf(plot)),
              plot,
              reason: 'plot $plot at scale $scale, panned to $pan',
            );
          }
        }
      }
    });

    test('points inside a tile map to it', () {
      // The round trip only checks centres. Points near the edge catch
      // off-by-half errors.
      for (final scale in [
        GardenProjection.minimumScale,
        1.0,
        GardenProjection.maximumScale,
      ]) {
        final projection = GardenProjection(scale: scale, pan: const Offset(7, 9));
        final halfWidth = GardenProjection.tile.width * scale / 2;
        final halfHeight = GardenProjection.tile.height * scale / 2;

        for (final plot in _plots) {
          final centre = projection.centreOf(plot);
          // Just inside each corner and each edge midpoint.
          for (final towards in const [
            Offset(0.96, 0),
            Offset(-0.96, 0),
            Offset(0, 0.96),
            Offset(0, -0.96),
            Offset(0.47, 0.47),
            Offset(-0.47, 0.47),
            Offset(0.47, -0.47),
            Offset(-0.47, -0.47),
          ]) {
            final point = centre.translate(
              towards.dx * halfWidth,
              towards.dy * halfHeight,
            );
            expect(
              projection.plotUnder(point),
              plot,
              reason: '$point is inside $plot at scale $scale',
            );
          }
        }
      }
    });

    test('walk crosses one boundary at a time', () {
      // Small steps can't skip a plot. Swapped axes would pass the round trip
      // but fail this.
      const projection = GardenProjection(scale: 1.4, pan: Offset(300, 300));
      var previous = projection.plotUnder(const Offset(0, 240));
      final visited = <GardenPlot>{previous};

      for (var step = 1; step < 400; step++) {
        final plot = projection.plotUnder(Offset(step * 2.0, 240 + step * 1.0));
        expect((plot.x - previous.x).abs(), lessThanOrEqualTo(1));
        expect((plot.y - previous.y).abs(), lessThanOrEqualTo(1));
        visited.add(plot);
        previous = plot;
      }

      expect(visited.length, greaterThan(10),
          reason: 'walk crossed the grid');
    });

    test('no gaps between tiles', () {
      const projection = GardenProjection(scale: 0.9, pan: Offset(120, 80));

      for (var x = 0.0; x < 400; x += 7.3) {
        for (var y = 0.0; y < 400; y += 5.1) {
          final point = Offset(x, y);
          final plot = projection.plotUnder(point);
          // Inside the diamond: normalised axis distances sum to under one.
          final from = point - projection.centreOf(plot);
          final normalised = (from.dx.abs() / (GardenProjection.tile.width * 0.9 / 2)) +
              (from.dy.abs() / (GardenProjection.tile.height * 0.9 / 2));
          expect(normalised, lessThanOrEqualTo(1.0000001), reason: '$point');
        }
      }
    });
  });

  group('zooming', () {
    test('keeps the focal point fixed', () {
      const before = GardenProjection(scale: 1, pan: Offset(50, 60));
      const focus = Offset(310, 190);
      final plot = before.plotUnder(focus);

      for (final to in _zooms) {
        final after = before.zoomedTo(to, around: focus);
        expect(after.plotUnder(focus), plot, reason: 'zoomed to $to');
      }
    });

    test('clamps to the zoom range', () {
      const projection = GardenProjection();

      expect(projection.zoomedTo(100, around: Offset.zero).scale,
          GardenProjection.maximumScale);
      expect(projection.zoomedTo(0.0001, around: Offset.zero).scale,
          GardenProjection.minimumScale);
      expect(projection.zoomedTo(-5, around: Offset.zero).scale,
          GardenProjection.minimumScale);
    });
  });

  group('staying on screen', () {
    const viewport = Size(400, 800);
    final full = GardenPlots.inPlacementOrder;
    final small = GardenPlots.inPlacementOrder.take(12).toList();

    test('large garden cannot be dragged off screen', () {
      const projection = GardenProjection(scale: 2, pan: Offset(9000, -9000));
      final bounded = projection.boundedTo(viewport, full);
      final bounds = bounded.boundsOf(full);

      // No empty band on any side.
      expect(bounds.left, lessThanOrEqualTo(0.001));
      expect(bounds.top, lessThanOrEqualTo(0.001));
      expect(bounds.right, greaterThanOrEqualTo(viewport.width - 0.001));
      expect(bounds.bottom, greaterThanOrEqualTo(viewport.height - 0.001));
    });

    test('fitted garden is unchanged', () {
      final settled =
          GardenProjection.fitting(viewport, full).boundedTo(viewport, full);

      expect(settled.boundedTo(viewport, full), settled,
          reason: 'clamping is idempotent');
    });

    test('small garden stays centred', () {
      for (final pan in const [
        Offset(5000, 5000),
        Offset(-5000, -5000),
        Offset.zero,
      ]) {
        final bounded = GardenProjection(scale: 0.5, pan: pan)
            .boundedTo(viewport, small);
        final bounds = bounded.boundsOf(small);

        expect(bounds.center.dx, closeTo(viewport.width / 2, 0.001));
        expect(bounds.center.dy, closeTo(viewport.height / 2, 0.001));
      }
    });

    test('new garden is always on screen', () {
      // A small empty garden flung into a corner would open to a blank screen.
      final flung =
          const GardenProjection(pan: Offset(-9999, 4000)).boundedTo(viewport, small);

      for (final plot in small) {
        expect(
          Offset.zero & viewport,
          _contains(flung.centreOf(plot)),
          reason: '$plot is on screen',
        );
      }
    });
  });

  group('opening the garden', () {
    const viewport = Size(400, 800);

    test('shows all of it at once', () {
      for (final plots in [
        GardenPlots.inPlacementOrder.take(12).toList(),
        GardenPlots.inPlacementOrder.take(52).toList(),
        GardenPlots.inPlacementOrder,
      ]) {
        final opening = GardenProjection.fitting(viewport, plots);
        final bounds = opening.boundsOf(plots);

        expect(bounds.width, lessThanOrEqualTo(viewport.width + 0.001),
            reason: '${plots.length} plots');
        expect(bounds.height, lessThanOrEqualTo(viewport.height + 0.001),
            reason: '${plots.length} plots');
      }
    });

    test('stays within the zoom range', () {
      final opening = GardenProjection.fitting(
        const Size(4000, 4000),
        GardenPlots.inPlacementOrder.take(1).toList(),
      );

      expect(opening.scale, lessThanOrEqualTo(GardenProjection.maximumScale));
    });

    test("empty viewport doesn't divide by zero", () {
      expect(
        GardenProjection.fitting(Size.zero, GardenPlots.inPlacementOrder),
        const GardenProjection(),
      );
    });
  });
}

Matcher _contains(Offset point) => predicate<Rect>(
      (rect) => rect.contains(point),
      'contains $point',
    );
