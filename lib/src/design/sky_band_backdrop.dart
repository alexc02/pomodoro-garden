import 'package:flutter/material.dart';

import 'garden_colors.dart';
import 'palette.dart';
import 'paper_painter.dart';

/// A sheet of paper with a band of sky cut across the top of it (PRD v2.3,
/// Paper Theatre): what the timer, the journal and the settings stand in front
/// of.
///
/// On the timer the band sits behind the countdown and the pot stands on the
/// paper below its cut edge, so the screen reads as a windowsill — sky above,
/// a pot on the sill — without either being drawn as one. On the journal and
/// the settings it is a shallower strip behind the headline. At night the band is the dark
/// canvas tinted by the sky, as the garden's is.
class SkyBandBackdrop extends StatelessWidget {
  const SkyBandBackdrop({this.depth = 0.36, super.key});

  /// How far down the screen the band's cut edge runs, at its lowest, as a
  /// fraction of the height.
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

/// The painting behind [SkyBandBackdrop].
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
