import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/garden_colors.dart';

/// The circular progress ring, with the countdown in the middle.
///
/// The ring is the session: an empty circle of bare soil that fills with green
/// as the time is spent, closing the loop exactly as the session ends.
class SessionRing extends StatelessWidget {
  const SessionRing({
    required this.progress,
    required this.child,
    required this.diameter,
    this.color,
    super.key,
  });

  /// How much of the session has been spent, 0 to 1.
  final double progress;

  /// Shown in the centre of the ring — the countdown.
  final Widget child;

  /// The colour of the filled arc. Defaults to the theme's primary green; the
  /// screen passes the bloom accent at the moment a session completes.
  final Color? color;

  /// The ring's outer size in logical pixels.
  final double diameter;

  /// How thick the ring is drawn. Wide enough to read as a band of planting
  /// rather than a hairline.
  static const double strokeWidth = 14;

  @override
  Widget build(BuildContext context) {
    final garden = GardenColors.of(context);

    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0, 1),
          // Bare soil, lightened so the filled arc reads as growth over it
          // rather than as a second, competing ring.
          trackColor: garden.soil.withValues(alpha: 0.25),
          progressColor: color ?? Theme.of(context).colorScheme.primary,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) -
            SessionRing.strokeWidth) /
        2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = SessionRing.strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawCircle(centre, radius, track);

    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = SessionRing.strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = progressColor;

    // From twelve o'clock, clockwise: the direction a clock face moves, and
    // the direction the eye expects a fill to travel.
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}
