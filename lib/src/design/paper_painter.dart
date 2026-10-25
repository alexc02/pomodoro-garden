import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paper: a warm wash towards the edges, and short fibres through it.
///
/// REQ-025's paper texture, and since PRD v2.3 the grain of every screen: the
/// garden's backdrop and the band of sky behind the timer, the journal and
/// the settings all lay it over themselves.
///
/// Drawn rather than shipped as an image, for the reason the plant sprites are:
/// a bitmap of paper is a fixed size on a screen that is not, it tiles visibly
/// on a tall page, and it would be a second thing to redraw when a theme
/// changes. It is a wash and a scatter of fibres in the theme's own colours,
/// so it is right in both brightnesses by construction and costs one paint per
/// resize.
///
/// Both are faint on purpose — the test of this texture is that a user
/// notices the page is not flat white without ever noticing why. Nothing here
/// is above 0.06 alpha.
class PaperPainter extends CustomPainter {
  const PaperPainter({required this.fibre, required this.wash});

  /// The colour of a fibre in the sheet. The theme's secondary text colour,
  /// which is the one value that is already legible-but-quiet in both
  /// brightnesses.
  final Color fibre;

  /// The warmth in the corners of the page. Soil, at almost nothing.
  final Color wash;

  /// One fibre per this much of the page, in square logical pixels.
  static const double _pixelsPerFibre = 2600;

  /// The most fibres any page gets, however large the window.
  ///
  /// A ceiling rather than a density alone, on the same reasoning
  /// `SeasonWeather.maximum` has one: the cost of the texture must not grow
  /// with the screen it is on.
  static const int maximumFibres = 320;

  /// Fixed, so the sheet has the same grain every time it is painted. A texture
  /// reseeded per paint would crawl.
  static const int _seed = 15;

  /// How many fibres a page of [size] gets.
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
