import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/garden_projection.dart';

/// The isometric coordinate maths, on its own.
///
/// Not a widget in sight, and deliberately: the ticket asks for the
/// screen-to-plot inverse to be tested independently of rendering, because a
/// projection checked only through a painted garden is checked by looking at
/// it. Everything here is a number in and a number out.

/// Every zoom worth checking a round trip at: both ends of the range, and one
/// in the middle that is not a whole number.
const List<double> _zooms = [
  GardenProjection.minimumScale,
  0.73,
  1,
  1.6,
  GardenProjection.maximumScale,
];

/// A spread of plots including the middle, both signs of both axes and the far
/// corner of a full garden.
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
    test('the middle of the garden lands where the garden has been dragged to',
        () {
      const projection = GardenProjection(scale: 1, pan: Offset(120, 260));

      expect(projection.centreOf(const GardenPlot(0, 0)), const Offset(120, 260));
    });

    test('both axes run away from the viewer, one each way', () {
      const projection = GardenProjection();
      final origin = projection.centreOf(const GardenPlot(0, 0));

      final right = projection.centreOf(const GardenPlot(1, 0));
      final left = projection.centreOf(const GardenPlot(0, 1));

      // x moves down and to the right, y down and to the left, and both by the
      // same amount down — that is what makes them the same distance away.
      expect(right.dx, greaterThan(origin.dx));
      expect(left.dx, lessThan(origin.dx));
      expect(right.dy, greaterThan(origin.dy));
      expect(right.dy, left.dy);
    });

    test('a tile is twice as wide as it is tall', () {
      const projection = GardenProjection();
      final corners = projection.tileCorners(const GardenPlot(0, 0));

      final width = corners[1].dx - corners[3].dx;
      final height = corners[2].dy - corners[0].dy;

      expect(width, GardenProjection.tile.width);
      expect(height, GardenProjection.tile.height);
      expect(width, 2 * height);
    });

    test('zooming scales the tile and nothing else about the shape', () {
      const near = GardenProjection(scale: 2);
      const far = GardenProjection(scale: 1);

      expect(
        near.centreOf(const GardenPlot(3, -2)),
        far.centreOf(const GardenPlot(3, -2)) * 2,
      );
    });

    test('a plant stands on its tile rather than in it', () {
      const projection = GardenProjection();
      const plot = GardenPlot(2, 2);
      final bounds = projection.spriteBounds(plot);
      final centre = projection.centreOf(plot);

      expect(bounds.bottom, centre.dy, reason: 'its base is on the ground');
      expect(bounds.center.dx, centre.dx);
      expect(bounds.height, greaterThan(GardenProjection.tile.height),
          reason: 'a large tree towers over the plot it grew in');
    });
  });

  group('the inverse', () {
    test('a plot round-trips at every zoom and wherever the garden is dragged',
        () {
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

    test('every point inside a tile belongs to that tile', () {
      // The round trip only checks the exact centre. A tap lands anywhere, and
      // the case that catches an off-by-half is a point near the diamond's edge.
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
          // Just inside each of the four corners, and just inside the middle of
          // each edge — the eight points a diamond is most likely to get wrong.
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

    test('walking across the garden crosses one tile boundary at a time', () {
      // A step of a couple of pixels cannot skip a plot, and cannot jump two.
      // A projection that had its two axes crossed would pass the round trip
      // above and fail here.
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
          reason: 'the walk really did cross the grid');
    });

    test('the whole grid is covered, so no tap falls between the tiles', () {
      const projection = GardenProjection(scale: 0.9, pan: Offset(120, 80));

      for (var x = 0.0; x < 400; x += 7.3) {
        for (var y = 0.0; y < 400; y += 5.1) {
          final point = Offset(x, y);
          final plot = projection.plotUnder(point);
          // The point is inside the diamond it was assigned to: the sum of the
          // normalised distances along the two axes is under one.
          final from = point - projection.centreOf(plot);
          final normalised = (from.dx.abs() / (GardenProjection.tile.width * 0.9 / 2)) +
              (from.dy.abs() / (GardenProjection.tile.height * 0.9 / 2));
          expect(normalised, lessThanOrEqualTo(1.0000001), reason: '$point');
        }
      }
    });
  });

  group('zooming', () {
    test('keeps whatever is under the fingers under the fingers', () {
      const before = GardenProjection(scale: 1, pan: Offset(50, 60));
      const focus = Offset(310, 190);
      final plot = before.plotUnder(focus);

      for (final to in _zooms) {
        final after = before.zoomedTo(to, around: focus);
        expect(after.plotUnder(focus), plot, reason: 'zoomed to $to');
      }
    });

    test('stops at the ends of the range rather than going past them', () {
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

    test('a garden bigger than the screen cannot be dragged off the edge of '
        'itself', () {
      const projection = GardenProjection(scale: 2, pan: Offset(9000, -9000));
      final bounded = projection.boundedTo(viewport, full);
      final bounds = bounded.boundsOf(full);

      // No band of empty screen on any side: the garden still covers the
      // window it is being looked at through.
      expect(bounds.left, lessThanOrEqualTo(0.001));
      expect(bounds.top, lessThanOrEqualTo(0.001));
      expect(bounds.right, greaterThanOrEqualTo(viewport.width - 0.001));
      expect(bounds.bottom, greaterThanOrEqualTo(viewport.height - 0.001));
    });

    test('a garden that already fits is left where it is', () {
      final settled =
          GardenProjection.fitting(viewport, full).boundedTo(viewport, full);

      expect(settled.boundedTo(viewport, full), settled,
          reason: 'clamping a clamped projection changes nothing');
    });

    test('a garden smaller than the screen is centred, however hard it is '
        'dragged', () {
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

    test('a new user never has to go looking for their twelve plots', () {
      // The failure this rule exists to stop: an empty garden is small, and a
      // small garden that could be flung into a corner is a garden the user
      // opens to a blank screen.
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

    test('does not zoom past the end of the range to do it', () {
      final opening = GardenProjection.fitting(
        const Size(4000, 4000),
        GardenPlots.inPlacementOrder.take(1).toList(),
      );

      expect(opening.scale, lessThanOrEqualTo(GardenProjection.maximumScale));
    });

    test('an empty viewport is not a divide by zero', () {
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
