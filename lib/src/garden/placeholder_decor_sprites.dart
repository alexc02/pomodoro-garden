import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'decor_sprite.dart';

/// The [DecorSpriteRegistry] the app runs on until ticket 23 delivers the
/// watercolour art: four objects drawn out of ovals and rectangles.
///
/// The placeholders are deliberately crude but not interchangeable, on the same
/// terms `PlaceholderPlantSpriteRegistry` sets: a user arranging their garden
/// has to be able to tell at a glance which of the four they just put down and
/// which one they are about to move, and they have to read as different objects
/// from across a garden zoomed out to two hundred plots. That is the behaviour
/// this ticket ships, and it is not waiting on art. Ticket 23 replaces this
/// class and nothing else.
///
/// Every one of them is drawn in a square cell, standing on the bottom edge and
/// centred across it — the same contract a plant's sprite works to, which is
/// what lets the atlas bake both kinds of picture the same way and the painter
/// hang both from the same anchor.
final class PlaceholderDecorSpriteRegistry implements DecorSpriteRegistry {
  const PlaceholderDecorSpriteRegistry();

  /// Built once, at first use, rather than per lookup — the same reason the
  /// plant registry does it: the atlas asks for these while baking, and a
  /// garden with fifty items in it should not be fifty allocations.
  static final Map<DecorKind, DecorSprite> _sprites = {
    for (final kind in DecorKind.values)
      kind: PlaceholderDecorSprite(kind: kind),
  };

  @override
  DecorSprite spriteFor(DecorKind kind) => _sprites[kind]!;
}

/// How much of its cell one object fills.
///
/// Worked out once and used twice — [PlaceholderDecorSprite.paint] draws from
/// it and [PlaceholderDecorSprite.footprintIn] measures it — because the two
/// must not disagree. A footprint derived separately from the drawing is one
/// that drifts away from it as the drawing is tuned, and what it decides is
/// which object a finger landed on.
typedef _Shape = ({double extent, double halfWidth});

/// One placeholder object: a [DecorKind], drawn from shapes.
final class PlaceholderDecorSprite implements DecorSprite {
  const PlaceholderDecorSprite({required this.kind});

  final DecorKind kind;

  /// How tall each object stands and how wide it gets, as fractions of the
  /// square it is drawn in.
  ///
  /// **Nothing here is as tall as a plant.** The tallest of the four reaches
  /// half its cell where a large tree fills all of it, and that is a rule about
  /// the product rather than about drawing: decor is the furniture of a garden
  /// and the plants are what the garden is *for*. An ornament that stood over
  /// the oak a ninety-minute session grew would be the app selling the user
  /// something that upstages their own work.
  ///
  /// The two water objects are the widest, because water is read by its surface
  /// and a surface seen from this angle is a flat oval.
  static const Map<DecorKind, _Shape> _shapes = {
    DecorKind.lantern: (extent: 0.50, halfWidth: 0.18),
    DecorKind.bench: (extent: 0.32, halfWidth: 0.32),
    DecorKind.birdbath: (extent: 0.44, halfWidth: 0.20),
    // Flat and wide: a pool lying in its plot rather than standing on it. It is
    // the one object with almost no height, which is what makes it read as
    // ground rather than as an object at any zoom.
    DecorKind.pond: (extent: 0.34, halfWidth: 0.40),
  };

  @override
  Rect footprintIn(Rect bounds) {
    if (bounds.isEmpty) return Rect.zero;

    final shape = _shapes[kind]!;
    final base = Offset(bounds.center.dx, bounds.bottom);
    final reach = shape.halfWidth * bounds.width;

    return Rect.fromLTRB(
      base.dx - reach,
      base.dy - shape.extent * bounds.height,
      base.dx + reach,
      base.dy,
    );
  }

  @override
  void paint(Canvas canvas, Rect bounds, DecorPalette palette) {
    if (bounds.isEmpty) return;

    final base = Offset(bounds.center.dx, bounds.bottom);
    // One number for both axes: the cell is square, and an object measured
    // against its width in one direction and its height in the other would
    // change shape the day the cell stops being square.
    final side = bounds.width;

    switch (kind) {
      case DecorKind.lantern:
        _paintLantern(canvas, base, side, palette);
      case DecorKind.bench:
        _paintBench(canvas, base, side, palette);
      case DecorKind.birdbath:
        _paintBirdbath(canvas, base, side, palette);
      case DecorKind.pond:
        _paintPond(canvas, base, side, palette);
    }
  }

  /// A pedestal, a post, and a lit head under a cap.
  ///
  /// The one object that gives light, and the only place [DecorPalette.glow] is
  /// spent: a lantern with an unlit window is a stone box.
  void _paintLantern(
    Canvas canvas,
    Offset base,
    double side,
    DecorPalette palette,
  ) {
    final stone = Paint()..color = palette.material;
    _paintGroundShadow(canvas, base, side, 0.30, palette);

    // The pedestal, drawn as the near half of an oval so the base reads as
    // sitting on ground the viewer is looking across rather than at.
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, -side * 0.05),
        width: side * 0.32,
        height: side * 0.11,
      ),
      stone,
    );

    canvas.drawRect(
      Rect.fromLTRB(
        base.dx - side * 0.05,
        base.dy - side * 0.30,
        base.dx + side * 0.05,
        base.dy - side * 0.04,
      ),
      stone,
    );

    // The head: a box with a window in it.
    final head = Rect.fromLTRB(
      base.dx - side * 0.13,
      base.dy - side * 0.44,
      base.dx + side * 0.13,
      base.dy - side * 0.28,
    );
    canvas.drawRect(head, stone);
    canvas.drawRect(
      Rect.fromCenter(
        center: head.center,
        width: side * 0.14,
        height: side * 0.09,
      ),
      Paint()..color = palette.glow,
    );

    // The cap, as a wide flat triangle. Its overhang is what makes the
    // silhouette a lantern rather than a signpost.
    final cap = Path()
      ..moveTo(base.dx, base.dy - side * 0.50)
      ..lineTo(base.dx + side * 0.18, base.dy - side * 0.43)
      ..lineTo(base.dx - side * 0.18, base.dy - side * 0.43)
      ..close();
    canvas.drawPath(cap, stone);
  }

  /// A seat on two legs, with a back rail behind it.
  void _paintBench(
    Canvas canvas,
    Offset base,
    double side,
    DecorPalette palette,
  ) {
    final wood = Paint()..color = palette.material;
    _paintGroundShadow(canvas, base, side, 0.58, palette);

    for (final at in [-0.24, 0.24]) {
      canvas.drawRect(
        Rect.fromLTRB(
          base.dx + side * (at - 0.025),
          base.dy - side * 0.16,
          base.dx + side * (at + 0.025),
          base.dy - side * 0.01,
        ),
        wood,
      );
    }

    // The back: two posts and a rail, drawn before the seat so the seat's
    // plank stands in front of them.
    for (final at in [-0.24, 0.24]) {
      canvas.drawRect(
        Rect.fromLTRB(
          base.dx + side * (at - 0.02),
          base.dy - side * 0.32,
          base.dx + side * (at + 0.02),
          base.dy - side * 0.18,
        ),
        wood,
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(
        base.dx - side * 0.30,
        base.dy - side * 0.30,
        base.dx + side * 0.30,
        base.dy - side * 0.25,
      ),
      wood,
    );

    canvas.drawRect(
      Rect.fromLTRB(
        base.dx - side * 0.32,
        base.dy - side * 0.21,
        base.dx + side * 0.32,
        base.dy - side * 0.15,
      ),
      wood,
    );
  }

  /// A basin on a stem, with water in it.
  void _paintBirdbath(
    Canvas canvas,
    Offset base,
    double side,
    DecorPalette palette,
  ) {
    final stone = Paint()..color = palette.material;
    _paintGroundShadow(canvas, base, side, 0.34, palette);

    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, -side * 0.04),
        width: side * 0.24,
        height: side * 0.09,
      ),
      stone,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        base.dx - side * 0.04,
        base.dy - side * 0.34,
        base.dx + side * 0.04,
        base.dy - side * 0.03,
      ),
      stone,
    );

    final basin = Rect.fromCenter(
      center: base.translate(0, -side * 0.37),
      width: side * 0.40,
      height: side * 0.14,
    );
    canvas.drawOval(basin, stone);
    // The water, inset far enough that the rim reads all the way round it —
    // a basin whose water reached its own edge would be a disc.
    canvas.drawOval(
      basin.deflate(side * 0.045),
      Paint()..color = palette.water,
    );
  }

  /// A pool of water with a rim of the biome's material around it.
  ///
  /// Wide, flat and low: the only one of the four with nothing standing up in
  /// it, which is what makes it read as part of the ground at any zoom.
  void _paintPond(
    Canvas canvas,
    Offset base,
    double side,
    DecorPalette palette,
  ) {
    final pool = Rect.fromCenter(
      center: base.translate(0, -side * 0.17),
      width: side * 0.80,
      height: side * 0.34,
    );

    canvas.drawOval(pool, Paint()..color = palette.material);
    canvas.drawOval(
      pool.deflate(side * 0.035),
      Paint()..color = palette.water,
    );
    // One highlight, off centre: still water with nothing on it is a hole.
    canvas.drawOval(
      Rect.fromCenter(
        center: pool.center.translate(-side * 0.14, -side * 0.05),
        width: side * 0.18,
        height: side * 0.05,
      ),
      Paint()..color = palette.glow.withValues(alpha: 0.35),
    );
  }

  /// The dark oval an object sits in, so that it reads as standing on the plot
  /// rather than floating over it.
  ///
  /// Drawn first, in the season's soil at low alpha: a shadow is the ground
  /// seen through the object, so it is the ground's colour and never black.
  void _paintGroundShadow(
    Canvas canvas,
    Offset base,
    double side,
    double width,
    DecorPalette palette,
  ) {
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, -side * 0.02),
        width: side * width,
        height: side * width * 0.34,
      ),
      Paint()..color = palette.shade.withValues(alpha: 0.28),
    );
  }
}
