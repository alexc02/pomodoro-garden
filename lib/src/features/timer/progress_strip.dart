import 'package:flutter/material.dart';

import '../../design/garden_colors.dart';
import '../../design/palette.dart';

/// How far through the session is, as a strip of paper being torn across
/// (PRD v2.3, Paper Theatre).
///
/// In place of the circular ring, which was the most generic thing on the
/// screen — every timer app has one. The strip fills from the left, and its
/// leading edge is ragged, the way paper tears, rather than a clean bar.
///
/// Decoration as far as a screen reader goes: the countdown above it says the
/// same thing in words, and says it exactly.
class ProgressStrip extends StatelessWidget {
  const ProgressStrip({required this.progress, this.color, super.key});

  /// How much of the session has been spent, 0 to 1.
  final double progress;

  /// The colour of the filled part. Defaults to the theme's secondary — the
  /// marigold the screen's one action is in; the screen passes the bloom
  /// accent at the moment a session completes.
  final Color? color;

  /// How tall the strip is drawn.
  static const double height = 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final garden = GardenColors.of(context);

    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: ProgressStripPainter(
            progress: progress.clamp(0, 1),
            // Bare soil on paper: the strip still to be filled.
            track: Color.lerp(
              theme.scaffoldBackgroundColor,
              garden.soil,
              0.22,
            )!,
            fill: color ?? theme.colorScheme.secondary,
          ),
        ),
      ),
    );
  }
}

/// The painting behind [ProgressStrip].
class ProgressStripPainter extends CustomPainter {
  const ProgressStripPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  /// The tear on the leading edge, as (reach forward, depth down) pairs in
  /// fractions of the strip's height.
  static const List<(double, double)> _tear = [
    (0.22, 0.28),
    (0, 0.5),
    (0.28, 0.72),
    (0, 1),
  ];

  /// The filled part, [progress] of the way across [size].
  static Path filled(Size size, double progress) {
    final x = size.width * progress;
    final h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(x, 0);
    // No tear on a full strip: there is no edge left to tear.
    if (progress < 1) {
      for (final (reach, depth) in _tear) {
        path.lineTo(x + reach * h, depth * h);
      }
    }
    return path
      ..lineTo(x, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final whole = Offset.zero & size;
    canvas
      ..drawRect(
        whole.shift(const Offset(0, 2)),
        Paint()
          ..color = Palette.textPrimary.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      )
      ..drawRect(whole, Paint()..color = track);
    if (progress <= 0) return;
    canvas
      ..save()
      ..clipRect(whole)
      ..drawPath(filled(size, progress), Paint()..color = fill)
      ..restore();
  }

  @override
  bool shouldRepaint(ProgressStripPainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}
