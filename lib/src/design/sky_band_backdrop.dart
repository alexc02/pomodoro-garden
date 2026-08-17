import 'package:flutter/material.dart';

import 'garden_colors.dart';
import 'palette.dart';
import 'paper_painter.dart';

/// Paper background with a band of sky across the top, behind the timer,
/// journal and settings. Deeper on the timer (the pot sits below the edge),
/// shallower elsewhere. At night it's the dark canvas tinted by the sky.
class SkyBandBackdrop extends StatelessWidget {
  const SkyBandBackdrop({this.depth = 0.36, super.key});

  /// Lowest point of the band's edge, as a fraction of the height.
  final double depth;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final theme = Theme.of(context);
    final night = theme.brightness == Brightness.dark;
    final paper = theme.scaffoldBackgroundColor;

    return RepaintBoundary(
      child: CustomPaint(
        painter: SkyBandPainter(
          paper: paper,
          band: night
              ? Color.lerp(Palette.backgroundDark, colors.skyDay, 0.12)!
              : Color.lerp(paper, colors.skyDay, 0.6)!,
          night: night,
          depth: depth,
        ),
        foregroundPainter: PaperPainter(
          fibre: colors.textSecondary,
          wash: colors.soil,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class SkyBandPainter extends CustomPainter {
  const SkyBandPainter({
    required this.paper,
    required this.band,
    required this.night,
    required this.depth,
  });

  final Color paper;
  final Color band;
  final bool night;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height * depth;

    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final edge = Path()
      ..moveTo(-w * 0.03, -10)
      ..lineTo(w * 1.03, -10)
      ..lineTo(w * 1.03, h * 0.92)
      ..cubicTo(w * 0.82, h * 1.02, w * 0.56, h * 0.9, w * 0.36, h * 0.97)
      ..cubicTo(w * 0.2, h * 1.02, w * 0.08, h * 0.98, -w * 0.03, h)
      ..close();
    canvas
      ..drawPath(
        edge.shift(const Offset(0, 3)),
        Paint()
          ..color = Palette.textPrimary.withValues(alpha: night ? 0.45 : 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      )
      ..drawPath(edge, Paint()..color = band);
  }

  @override
  bool shouldRepaint(SkyBandPainter old) =>
      old.paper != paper ||
      old.band != band ||
      old.night != night ||
      old.depth != depth;
}
