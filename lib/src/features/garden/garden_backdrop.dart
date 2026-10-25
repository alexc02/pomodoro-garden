import 'package:flutter/material.dart';

import '../../design/garden_colors.dart';
import '../../design/palette.dart';
import '../../design/paper_painter.dart';

/// What the garden stands in front of: a sky, a sun, and two hills of cut
/// paper (PRD v2.3, Paper Theatre).
///
/// Before this the garden floated in a flat field of sky, which is the single
/// thing that most made the screen look unfinished. The hills give the plots a
/// horizon to sit below, and they are cut the way the plants are — a flat
/// colour each, casting a soft shadow on the layer behind.
///
/// Every colour comes from [GardenColors], so REQ-019's season and REQ-034's
/// theme reach the backdrop exactly as they reach the plants: the hills are the
/// season's foliage faded into its sky, and an autumn garden stands in front of
/// autumn hills. At night — the app in dark mode — the same sky is drawn deep
/// and the sun becomes a moon, rather than the garden keeping a daytime sky on
/// a dark screen.
///
/// Painted once and held behind a [RepaintBoundary]: the garden pans and sways
/// over it, and it never moves.
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
        // The same paper the journal is printed on, over the whole scene, so
        // the sky reads as a sheet rather than a fill.
        foregroundPainter: PaperPainter(
          fibre: colors.textSecondary,
          wash: colors.soil,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// The painting behind [GardenBackdrop].
class GardenBackdropPainter extends CustomPainter {
  const GardenBackdropPainter({
    required this.sky,
    required this.foliage,
    required this.sun,
    required this.night,
  });

  /// The season's sky. The whole background, by day.
  final Color sky;

  /// The season's leaf colour, which the hills are faded from.
  final Color foliage;

  /// The golden-hour colour: the sun by day, and the warmth in the moon.
  final Color sun;

  /// Whether to draw the garden at night.
  final bool night;

  /// How far each hill is faded toward the sky: the far one most, so it sits
  /// back, the way distance does it.
  static const double _farFade = 0.55;
  static const double _nearFade = 0.3;

  /// How much of the sky's own colour survives into the night sky.
  static const double _nightSkyKeeps = 0.18;

  /// The shadow a layer of paper casts on the one behind it — the same offset
  /// and softness the sprites are cut with.
  static const Offset _shadowOffset = Offset(0, 3);
  static const double _shadowBlur = 2.5;

  /// The night sky: the dark canvas, tinted by the season's sky.
  Color get nightSky => Color.lerp(Palette.backgroundDark, sky, _nightSkyKeeps)!;

  /// The sky as painted, by day or by night.
  Color get paintedSky => night ? nightSky : sky;

  /// The far hill, as painted.
  Color get farHill => _hill(_farFade);

  /// The near hill, as painted.
  Color get nearHill => _hill(_nearFade);

  Color _hill(double fade) {
    final day = Color.lerp(foliage, sky, fade)!;
    // At night a hill is a darker shape against a dark sky, not a lit one.
    return night ? Color.lerp(day, Palette.backgroundDark, 0.72)! : day;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Offset.zero & size, Paint()..color = paintedSky);

    // The sun, or the moon, high on the right where the header is not.
    final disc = Offset(w * 0.8, h * 0.2);
    final radius = w * 0.1;
    _cut(
      canvas,
      Path()..addOval(Rect.fromCircle(center: disc, radius: radius)),
      night ? Color.lerp(sun, Palette.surfaceLight, 0.6)! : sun,
    );

    // Two hills, each a single gentle curve across the width and down off the
    // bottom of the screen. Their crests sit behind the middle of the garden,
    // which is where the plots are drawn.
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

  /// Draws [shape] as a layer of paper: its shadow first, then the shape.
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
