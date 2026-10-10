import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'garden_atlas.dart';
import 'garden_projection.dart';

/// What the user just tapped, and the plot it is standing in.
///
/// Sealed, and with a [plot] on every case, because the two screens that ask
/// want different halves of the answer: ticket 12's card wants the plant, and
/// REQ-040's arranging wants the plot — to put something in it, to move
/// something to it, or to pick up what is already there. A nullable [Plant] can
/// say the first and cannot say the second, which is why this type exists at
/// all.
sealed class GardenTarget {
  const GardenTarget(this.plot);

  /// The plot the tap resolved to. Always one the garden actually has.
  final GardenPlot plot;
}

/// A plant, and the plot it grew in.
final class PlantTarget extends GardenTarget {
  const PlantTarget(super.plot, this.plant);

  final Plant plant;
}

/// One of REQ-040's objects, and the plot it stands in.
final class DecorTarget extends GardenTarget {
  const DecorTarget(super.plot, this.decor);

  final Decor decor;
}

/// A plot of this garden with nothing at all in it.
///
/// Not the same as "the tap hit nothing": a tap on the sky, or on a plot the
/// garden has not unlocked, resolves to null. This is bare soil the user could
/// put something in, which is exactly the distinction the picker needs and the
/// one ticket 12 had no use for.
final class SoilTarget extends GardenTarget {
  const SoilTarget(super.plot);
}

/// Which thing in the garden the user just tapped.
///
/// The inverse of the whole garden, where [GardenProjection] is the inverse of
/// its ground: the camera turns a point on screen back into a plot, and this
/// turns it back into the thing the user was actually looking at.
///
/// The two are not the same question, and ticket 07 left the difference for
/// ticket 12. A plant stands *on* its plot and grows upwards, so a tall plant
/// is drawn over the two plots behind it — and the plot under the finger is
/// therefore not always the plant under the finger. Tapping a tree's canopy has
/// to open the tree, not the wildflower whose bare soil happens to be behind
/// it.
///
/// Two passes, in the order the user's eye reads the screen:
///
/// 1. **What is standing in the garden, nearest first.** The garden is painted
///    back to front, so walking it front to back and taking the first thing
///    whose picture covers the point gives the one that is visibly on top.
///    Plants and REQ-040's objects are walked together, in one pass, for the
///    same reason the painter draws them in one: a bench in front of a tree is
///    in front of it here too, or the tap and the picture disagree.
/// 2. **Then the ground.** A point on nothing at all belongs to the plot it
///    falls in, so that the soil at a plant's feet opens the plant standing on
///    it — a stem is three pixels wide and nobody should have to hit it.
///
/// Nothing here is cached and nothing is precomputed: this runs once per tap,
/// over at most two hundred plots.
final class GardenHitTest {
  const GardenHitTest({
    required this.layout,
    required this.projection,
    required this.atlas,
  });

  /// The garden being tapped: which plots it has, and what is in them.
  final GardenLayout layout;

  /// Where those plots currently are on screen.
  final GardenProjection projection;

  /// The pictures the garden is drawn from, and so the only thing that knows
  /// how much of its box a plant or an object fills. The same atlas
  /// `GardenPainter` blits, deliberately: what is hit has to be what was drawn,
  /// and asking anything else would be a second opinion about the same picture.
  /// See [GardenAtlas.footprintFor].
  final GardenAtlas atlas;

  /// What is at [point], in the same coordinates the garden is painted in, or
  /// null if the user tapped a plot the garden has not unlocked or the sky over
  /// the whole thing.
  GardenTarget? at(Offset point) {
    // Front to back: `layout.plots` is in paint order, so the last plot drawn
    // is the nearest one and the first one to claim a tap.
    for (final plot in layout.plots.reversed) {
      final plant = layout.plantIn(plot);
      if (plant != null) {
        final picture = _pictureIn(plot, atlas.footprintFor(plant.species));
        if (picture.contains(point)) return PlantTarget(plot, plant);
        continue;
      }

      final item = layout.decorIn(plot);
      if (item == null) continue;
      final picture = _pictureIn(plot, atlas.footprintForDecor(item.kind));
      if (picture.contains(point)) return DecorTarget(plot, item);
    }

    // On nothing's picture, so on the ground.
    final under = projection.plotUnder(point);
    if (!layout.hasPlot(under)) return null;

    final plant = layout.plantIn(under);
    if (plant != null) return PlantTarget(under, plant);

    final item = layout.decorIn(under);
    if (item != null) return DecorTarget(under, item);

    return SoilTarget(under);
  }

  /// The plant at [point], or null if the user tapped anything else.
  ///
  /// Ticket 12's question, unchanged: bare soil, a plot the garden has not
  /// unlocked and the sky all answer null, and from this ticket so does a
  /// lantern. That last one is REQ-040's "does not break plant hit-testing"
  /// said the right way round — an object standing in front of a tree takes the
  /// tap rather than passing it through, and taking it means nothing opens.
  Plant? plantAt(Offset point) => switch (at(point)) {
        PlantTarget(:final plant) => plant,
        _ => null,
      };

  /// Where the picture standing in [plot] lands on screen, given how much of
  /// its cell that picture fills.
  ///
  /// The square the thing is drawn in, narrowed to the part of it the picture
  /// actually covers. The narrowing is the whole of this class: the square is a
  /// tile wide and a large tree tall whatever is standing in it, so a
  /// wildflower's square covers the trunk of the tree two rows behind it — and
  /// a lantern's square, which is mostly sky, would cover the same.
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
