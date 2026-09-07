import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'decor_sprite.dart';

/// Fallback [DecorSpriteRegistry] for builds without art: four objects made
/// of ovals and rectangles.
///
/// Crude, but each must be recognisable at a glance and when zoomed out to 200
/// plots. Same sprite contract as plants (square cell, standing on the bottom
/// edge, centred), so the atlas and painter treat both the same.
final class PlaceholderDecorSpriteRegistry implements DecorSpriteRegistry {
  const PlaceholderDecorSpriteRegistry();

  /// Built once rather than per lookup.
  static final Map<DecorKind, DecorSprite> _sprites = {
    for (final kind in DecorKind.values)
      kind: PlaceholderDecorSprite(kind: kind),
  };

  @override
  DecorSprite spriteFor(DecorKind kind) => _sprites[kind]!;
}

/// How much of its cell one object fills. Both [PlaceholderDecorSprite.paint]
/// and [PlaceholderDecorSprite.footprintIn] read this so hit-testing can't
/// drift from the drawing.
typedef _Shape = ({double extent, double halfWidth});

final class PlaceholderDecorSprite implements DecorSprite {
  const PlaceholderDecorSprite({required this.kind});

  final DecorKind kind;

  /// Height and half-width as fractions of the cell.
  ///
  /// Nothing is as tall as a plant (tallest is half a cell): decor shouldn't
  /// upstage the plants the user grew. The water objects are widest since a
  /// surface at this angle is a flat oval.
  static const Map<DecorKind, _Shape> _shapes = {
    DecorKind.lantern: (extent: 0.50, halfWidth: 0.18),
    DecorKind.bench: (extent: 0.32, halfWidth: 0.32),
    DecorKind.birdbath: (extent: 0.44, halfWidth: 0.20),
    // Almost no height, so it reads as ground at any zoom.
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
    // One scale for both axes, so shapes don't distort if the cell ever
    // stops being square.
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

  /// A pedestal, a post, and a lit head under a cap. The only thing that uses
  /// [DecorPalette.glow].
  void _paintLantern(
    Canvas canvas,
    Offset base,
    double side,
    DecorPalette palette,
  ) {
    final stone = Paint()..color = palette.material;
    _paintGroundShadow(canvas, base, side, 0.30, palette);

    // Pedestal as a flat oval so it sits on the ground.
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

    // The cap's overhang is what makes it a lantern and not a signpost.
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

    // Back posts and rail before the seat so the seat plank sits in front.
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
    // Inset so the rim shows all the way round.
    canvas.drawOval(
      basin.deflate(side * 0.045),
      Paint()..color = palette.water,
    );
  }

  /// A pool of water with a rim of the biome's material.
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
    // Off-centre highlight; without it still water looks like a hole.
    canvas.drawOval(
      Rect.fromCenter(
        center: pool.center.translate(-side * 0.14, -side * 0.05),
        width: side * 0.18,
        height: side * 0.05,
      ),
      Paint()..color = palette.glow.withValues(alpha: 0.35),
    );
  }

  /// Soft shadow under an object so it stands on the plot. Soil colour at low
  /// alpha, never black.
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
