import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paper texture used behind every screen: a warm edge wash plus short
/// fibres. Painted rather than a bitmap so it scales and follows the theme.
/// Kept very faint on purpose (nothing above 0.06 alpha).
class PaperPainter extends CustomPainter {
  const PaperPainter({required this.fibre, required this.wash});

  /// Usually the theme's secondary text colour.
  final Color fibre;

  /// Edge tint, usually soil.
  final Color wash;

  /// Square logical pixels per fibre.
  static const double _pixelsPerFibre = 2600;

  /// Cap so paint cost doesn't grow with screen size.
  static const int maximumFibres = 320;

  /// Fixed so the grain doesn't crawl between paints.
  static const int _seed = 15;

  static int fibresIn(Size size) {
    final count = (size.width * size.height / _pixelsPerFibre).round();
    return count > maximumFibres ? maximumFibres : count;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final page = Offset.zero & size;

    canvas.drawRect(
      page,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [
            wash.withValues(alpha: 0),
            wash.withValues(alpha: 0.05),
          ],
        ).createShader(page),
    );

    final random = math.Random(_seed);
    final ink = Paint()
      ..color = fibre.withValues(alpha: 0.055)
      ..strokeCap = StrokeCap.round;

    for (var n = fibresIn(size); n > 0; n--) {
      final at = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final angle = random.nextDouble() * math.pi;
      final length = 2 + random.nextDouble() * 5;

      canvas.drawLine(
        at,
        at + Offset(math.cos(angle), math.sin(angle)) * length,
        ink..strokeWidth = 0.6 + random.nextDouble() * 0.6,
      );
    }
  }

  @override
  bool shouldRepaint(PaperPainter old) =>
      old.fibre != fibre || old.wash != wash;
}
