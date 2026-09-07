import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'plant_sprite.dart';

/// One plant on its patch of soil, in a pose.
///
/// Only draws; `GrowingPlant` drives the values, which keeps [scale], [lean],
/// [drop] and [burst] readable from tests. All transforms pivot on the point
/// where the plant meets the soil.
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

  /// Multiplier about the base; 1 is the stage's normal size.
  final double scale;

  /// Radians; positive leans right.
  final double lean;

  /// Logical pixels above the soil. Non-zero only while a seed is falling.
  final double drop;

  /// Landing soil burst progress, 0 to 1 (1 means fully faded).
  final double burst;

  /// Session-end petal bloom progress, 0 to 1. Like [burst], the spray is a
  /// pure function of progress, so no per-petal state between frames.
  final double bloom;

  /// Soil bed depth as a fraction of the box.
  static const double _bedFraction = 0.14;

  /// Petals in the bloom, spread over the full circle (the burst only goes
  /// up).
  static const int _petals = 12;

  /// Where petals come from, as a fraction of the way from box top to the
  /// soil line (roughly a mature plant's crown).
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
      Paint()..color = palette.soil.withValues(alpha: 0.35),
    );

    // Slightly inside the bed so a landed seed reads as in the soil.
    final soilLine = bed.top + bed.height * 0.4;

    // Skip at 1 too: a finished burst is invisible.
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

    // Petals go on top of the plant (the soil burst goes behind it).
    if (bloom > 0 && bloom < 1) {
      _paintBloom(canvas, Offset(size.width / 2, soilLine * _crownFraction),
          size);
    }
  }

  /// Six soil specks thrown up from where the seed hit, fading out.
  void _paintBurst(Canvas canvas, Offset landing, Size size) {
    final reach = size.shortestSide * 0.16 * burst;
    final paint = Paint()
      ..color = palette.soil.withValues(alpha: (1 - burst) * 0.8);

    for (var i = 0; i < 6; i++) {
      // Upper half only.
      final angle = math.pi + (i + 0.5) * math.pi / 6;
      canvas.drawCircle(
        landing + Offset(math.cos(angle), math.sin(angle)) * reach,
        math.max(0.5, size.shortestSide * 0.012 * (1 - burst)),
        paint,
      );
    }
  }

  /// [_petals] petals thrown from the crown, eased out, drifting down and
  /// fading. Reach and spin depend only on the index, so no randomness.
  void _paintBloom(Canvas canvas, Offset crown, Size size) {
    final out = Curves.easeOut.transform(bloom);
    // Short enough that the top petal stays inside the box (nothing clips).
    final reach = size.shortestSide * 0.36 * out;
    // A little gravity so they read as petals, not sparks.
    final fall = size.shortestSide * 0.12 * bloom * bloom;
    final fade = 1 - Curves.easeIn.transform(bloom);
    final petal = size.shortestSide * 0.028;

    final paint = Paint();
    for (var i = 0; i < _petals; i++) {
      // Alternate colour and reach so it scatters instead of forming a ring.
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
