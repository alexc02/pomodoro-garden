import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'plant_sprite.dart';

/// One plant on its patch of soil, in a pose.
///
/// The painter knows how to draw a plant that is leaning, scaled or still
/// falling; it does not know how any of those got their values. `GrowingPlant`
/// drives them from a session. Splitting it this way is what makes the
/// animation testable — [scale], [lean], [drop] and [burst] are numbers a test
/// can read off the painter, rather than a matrix buried in the widget tree.
///
/// Every transform is applied about the point where the plant meets the soil,
/// because that is where a plant is attached to the world: a swaying plant
/// pivots at its base, and a growing one pushes up from it.
final class PlantPainter extends CustomPainter {
  const PlantPainter({
    required this.sprite,
    required this.palette,
    this.scale = 1,
    this.lean = 0,
    this.drop = 0,
    this.burst = 0,
    this.bloom = 0,
  });

  /// The plant to draw, or null for an empty bed of soil waiting for one.
  final PlantSprite? sprite;

  final PlantPalette palette;

  /// A multiplier about the base. 1 is the plant at the size its stage says.
  final double scale;

  /// How far the plant is leaning, in radians. Positive leans right.
  final double lean;

  /// How far above the soil the plant still is, in logical pixels. Non-zero
  /// only while a seed is falling.
  final double drop;

  /// The soil kicked up by a landing seed: 0 before it lands, 1 once the specks
  /// have thrown as far as they go and faded out completely.
  final double burst;

  /// §5.3's bloom, the PRD's "session end celebration": 0 before the plant blooms, 1 once the last
  /// petal has drifted out of the box and faded.
  ///
  /// Read exactly as [burst] is — a fraction of one throw of particles, with no
  /// per-petal state anywhere — and for the same reason: a spray that is a pure
  /// function of how far through it is costs one paint and keeps nothing alive
  /// between frames.
  final double bloom;

  /// How deep the bed of soil is drawn, as a fraction of the box.
  static const double _bedFraction = 0.14;

  /// How many petals the bloom throws.
  ///
  /// Twice the landing burst's six, and spread over the whole circle rather
  /// than the upper half: soil is kicked up out of the ground, and petals come
  /// off a plant in every direction. Still a number small enough to be drawn
  /// one circle at a time.
  static const int _petals = 12;

  /// Where the petals come off the plant, as a fraction of the way down from
  /// the top of the box to the soil line — the crown of a mature plant, which
  /// is where its flowers are.
  static const double _crownFraction = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final bed = Rect.fromLTWH(
      0,
      size.height * (1 - _bedFraction),
      size.width,
      size.height * _bedFraction,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bed, Radius.circular(bed.height / 2)),
      // Tilled earth, not a solid block: the bed is a surface for the plant,
      // not a second object competing with it.
      Paint()..color = palette.soil.withValues(alpha: 0.35),
    );

    // Plants stand a little inside the bed rather than on top of it, so a seed
    // that has landed reads as *in* the soil.
    final soilLine = bed.top + bed.height * 0.4;

    // Skipped at 1 as well as at 0: a finished burst is fully transparent, and
    // a plant sits on screen for a session's worth of frames after it landed.
    if (burst > 0 && burst < 1) {
      _paintBurst(canvas, Offset(size.width / 2, soilLine), size);
    }

    final plant = sprite;
    if (plant == null) return;

    canvas.save();
    canvas.translate(size.width / 2, soilLine - drop);
    canvas.rotate(lean);
    canvas.scale(scale);
    canvas.translate(-size.width / 2, -soilLine);
    plant.paint(canvas, Rect.fromLTRB(0, 0, size.width, soilLine), palette);
    canvas.restore();

    // After the plant rather than before it, which is the one way the petals
    // differ from the landing burst: soil is thrown up behind what has just
    // landed in it, and petals come off the front of a plant as well as the
    // back. Skipped at 1 as the burst is — a bloom that has finished is
    // fully transparent, and a mature plant sits on screen long after one.
    if (bloom > 0 && bloom < 1) {
      _paintBloom(canvas, Offset(size.width / 2, soilLine * _crownFraction),
          size);
    }
  }

  /// §5.3's "small soil particle burst on landing": six specks thrown out from
  /// where the seed hit, fading as they go.
  void _paintBurst(Canvas canvas, Offset landing, Size size) {
    final reach = size.shortestSide * 0.16 * burst;
    final paint = Paint()
      ..color = palette.soil.withValues(alpha: (1 - burst) * 0.8);

    for (var i = 0; i < 6; i++) {
      // Spread over the upper half only — soil is thrown up out of the ground,
      // not down into it.
      final angle = math.pi + (i + 0.5) * math.pi / 6;
      canvas.drawCircle(
        landing + Offset(math.cos(angle), math.sin(angle)) * reach,
        math.max(0.5, size.shortestSide * 0.012 * (1 - burst)),
        paint,
      );
    }
  }

  /// §5.3's "particle petals/spores": [_petals] petals thrown out from the
  /// plant's crown in every direction, drifting down as they go and fading.
  ///
  /// Eased out, so the petals leave fast and slow to a drift — the "ease" half
  /// of §5.3's spring-and-ease, the spring being the plant's own pop. Each
  /// petal's reach and spin are a fixed function of its index rather than
  /// random, so the spray is the same picture on every frame of every bloom
  /// and nothing has to be remembered between paints.
  void _paintBloom(Canvas canvas, Offset crown, Size size) {
    final out = Curves.easeOut.transform(bloom);
    // Short enough that the highest petal stays inside the box: nothing here
    // clips, and a petal drawn above it would land on the ring.
    final reach = size.shortestSide * 0.36 * out;
    // Gravity, gently: petals are thrown and then fall, which is what tells
    // them apart from sparks.
    final fall = size.shortestSide * 0.12 * bloom * bloom;
    final fade = 1 - Curves.easeIn.transform(bloom);
    final petal = size.shortestSide * 0.028;

    final paint = Paint();
    for (var i = 0; i < _petals; i++) {
      // Alternate petals take the bloom colour and the foliage colour, and
      // alternate ones fly a little shorter, so the spray reads as a scatter
      // rather than a ring.
      paint.color = (i.isEven ? palette.bloom : palette.foliage)
          .withValues(alpha: fade * 0.9);
      final angle = (i + 0.25) * 2 * math.pi / _petals;
      final distance = reach * (i.isEven ? 1 : 0.7);
      final at = crown +
          Offset(math.cos(angle), math.sin(angle)) * distance +
          Offset(0, fall);

      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(angle + bloom * math.pi);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: petal * 2,
          height: petal,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(PlantPainter old) =>
      old.sprite != sprite ||
      old.palette != palette ||
      old.scale != scale ||
      old.lean != lean ||
      old.drop != drop ||
      old.burst != burst ||
      old.bloom != bloom;
}
