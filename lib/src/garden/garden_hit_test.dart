import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'garden_atlas.dart';
import 'garden_projection.dart';

/// What the user just tapped, and the plot it's in.
///
/// Every case carries a [plot] because arranging needs the plot even when the
/// plant card only needs the plant.
sealed class GardenTarget {
  const GardenTarget(this.plot);

  /// Always a plot the garden actually has.
  final GardenPlot plot;
}

/// A plant, and the plot it grew in.
final class PlantTarget extends GardenTarget {
  const PlantTarget(super.plot, this.plant);

  final Plant plant;
}

/// One of the objects, and the plot it stands in.
final class DecorTarget extends GardenTarget {
  const DecorTarget(super.plot, this.decor);

  final Decor decor;
}

/// An unlocked plot with nothing in it. A tap on the sky or a locked plot
/// gives null instead.
final class SoilTarget extends GardenTarget {
  const SoilTarget(super.plot);
}

/// Works out which thing in the garden the user tapped.
///
/// The plot under the finger isn't always the thing under it: tall plants are
/// drawn over the plots behind them. So:
///
/// 1. Walk plants and decor together, front to back, and take the first whose
///    footprint covers the point (the one visibly on top).
/// 2. Otherwise fall back to the plot under the point, so tapping the soil at
///    a plant's feet still opens it.
///
/// Runs once per tap over at most 200 plots, so nothing is cached.
final class GardenHitTest {
  const GardenHitTest({
    required this.layout,
    required this.projection,
    required this.atlas,
  });

  final GardenLayout layout;

  final GardenProjection projection;

  /// The same atlas `GardenPainter` draws from, so hits match what was drawn.
  /// See [GardenAtlas.footprintFor].
  final GardenAtlas atlas;

  /// What is at [point] (garden paint coordinates), or null for the sky or a
  /// locked plot.
  ///
  /// Plants are skipped while [arranging]. They can't be picked up, and a
  /// tall one would otherwise swallow taps meant for decor behind it.
  GardenTarget? at(Offset point, {bool arranging = false}) {
    // `layout.plots` is in paint order, so reversed is nearest first.
    for (final plot in layout.plots.reversed) {
      final plant = layout.plantIn(plot);
      if (plant != null) {
        if (arranging) continue;
        final picture = _pictureIn(plot, atlas.footprintFor(plant.species));
        if (picture.contains(point)) return PlantTarget(plot, plant);
        continue;
      }

      final item = layout.decorIn(plot);
      if (item == null) continue;
      final picture = _pictureIn(plot, atlas.footprintForDecor(item.kind));
      if (picture.contains(point)) return DecorTarget(plot, item);
    }

    final under = projection.plotUnder(point);
    if (!layout.hasPlot(under)) return null;

    final plant = layout.plantIn(under);
    if (plant != null) return PlantTarget(under, plant);

    final item = layout.decorIn(under);
    if (item != null) return DecorTarget(under, item);

    return SoilTarget(under);
  }

  /// The plant at [point], or null for anything else. Decor in front of a
  /// plant takes the tap, so that's null too.
  Plant? plantAt(Offset point) => switch (at(point)) {
        PlantTarget(:final plant) => plant,
        _ => null,
      };

  /// The plot's sprite box narrowed to the fraction [fills] that the picture
  /// actually covers.
  Rect _pictureIn(GardenPlot plot, Rect fills) {
    final box = projection.spriteBounds(plot);

    return Rect.fromLTRB(
      box.left + fills.left * box.width,
      box.top + fills.top * box.height,
      box.left + fills.right * box.width,
      box.top + fills.bottom * box.height,
    );
  }
}
