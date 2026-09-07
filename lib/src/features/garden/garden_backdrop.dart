import 'package:flutter/material.dart';

import '../../design/garden_colors.dart';
import '../../design/palette.dart';
import '../../design/paper_painter.dart';

/// Sky, sun and two cut-paper hills behind the garden.
///
/// All colours come from [GardenColors], so season and theme apply here too.
/// In dark mode the sky goes deep and the sun becomes a moon. Sits behind a
/// [RepaintBoundary] since it never moves.
class GardenBackdrop extends StatelessWidget {
  const GardenBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final night = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: CustomPaint(
        painter: GardenBackdropPainter(
          sky: colors.skyDay,
          foliage: colors.foliage,
          sun: colors.skyGoldenHour,
          night: night,
        ),
        // Paper texture over the whole scene.
        foregroundPainter: PaperPainter(
          fibre: colors.textSecondary,
          wash: colors.soil,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class GardenBackdropPainter extends CustomPainter {
  const GardenBackdropPainter({
    required this.sky,
    required this.foliage,
    required this.sun,
    required this.night,
  });

  /// Whole background, by day.
  final Color sky;

  /// The hills are faded from this.
  final Color foliage;

  /// Sun by day, warmth in the moon at night.
  final Color sun;

  final bool night;

  /// How far each hill fades toward the sky. Far one more, for depth.
  static const double _farFade = 0.55;
  static const double _nearFade = 0.3;

  static const double _nightSkyKeeps = 0.18;

  /// Same shadow the sprites use.
  static const Offset _shadowOffset = Offset(0, 3);
  static const double _shadowBlur = 2.5;

  Color get nightSky => Color.lerp(Palette.backgroundDark, sky, _nightSkyKeeps)!;

  Color get paintedSky => night ? nightSky : sky;

  Color get farHill => _hill(_farFade);

  Color get nearHill => _hill(_nearFade);

  Color _hill(double fade) {
    final day = Color.lerp(foliage, sky, fade)!;
    return night ? Color.lerp(day, Palette.backgroundDark, 0.72)! : day;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Offset.zero & size, Paint()..color = paintedSky);

    // Top right, clear of the header.
    final disc = Offset(w * 0.8, h * 0.2);
    final radius = w * 0.1;
    _cut(
      canvas,
      Path()..addOval(Rect.fromCircle(center: disc, radius: radius)),
      night ? Color.lerp(sun, Palette.surfaceLight, 0.6)! : sun,
    );

    // Crests sit behind the middle of the garden, where the plots are.
    _cut(
      canvas,
      Path()
        ..moveTo(-w * 0.05, h * 0.42)
        ..cubicTo(w * 0.15, h * 0.35, w * 0.36, h * 0.38, w * 0.53, h * 0.39)
        ..cubicTo(w * 0.7, h * 0.4, w * 0.85, h * 0.34, w * 1.05, h * 0.36)
        ..lineTo(w * 1.05, h * 1.05)
        ..lineTo(-w * 0.05, h * 1.05)
        ..close(),
      farHill,
    );
    _cut(
      canvas,
      Path()
        ..moveTo(-w * 0.05, h * 0.53)
        ..cubicTo(w * 0.18, h * 0.47, w * 0.44, h * 0.5, w * 0.62, h * 0.49)
        ..cubicTo(w * 0.78, h * 0.48, w * 0.9, h * 0.45, w * 1.05, h * 0.47)
        ..lineTo(w * 1.05, h * 1.05)
        ..lineTo(-w * 0.05, h * 1.05)
        ..close(),
      nearHill,
    );
  }

  /// Shadow first, then the shape.
  void _cut(Canvas canvas, Path shape, Color colour) {
    canvas
      ..drawPath(
        shape.shift(_shadowOffset),
        Paint()
          ..color = Palette.textPrimary.withValues(alpha: night ? 0.45 : 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _shadowBlur),
      )
      ..drawPath(shape, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(GardenBackdropPainter old) =>
      old.sky != sky ||
      old.foliage != foliage ||
      old.sun != sun ||
      old.night != night;
}
