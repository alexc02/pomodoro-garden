import 'package:flutter/material.dart';

import '../../design/garden_colors.dart';
import '../../design/palette.dart';

/// Session progress as a paper strip with a torn leading edge. Hidden from
/// screen readers; the countdown says the same thing.
class ProgressStrip extends StatelessWidget {
  const ProgressStrip({required this.progress, this.color, super.key});

  /// 0 to 1.
  final double progress;

  /// Fill colour. Defaults to the theme's secondary (marigold).
  final Color? color;

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
            // Unfilled track: soil tinted into the paper.
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

class ProgressStripPainter extends CustomPainter {
  const ProgressStripPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  /// Leading-edge tear as (reach, depth) pairs, in fractions of strip height.
  static const List<(double, double)> _tear = [
    (0.22, 0.28),
    (0, 0.5),
    (0.28, 0.72),
    (0, 1),
  ];

  static Path filled(Size size, double progress) {
    final x = size.width * progress;
    final h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(x, 0);
    // No tear once full.
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
