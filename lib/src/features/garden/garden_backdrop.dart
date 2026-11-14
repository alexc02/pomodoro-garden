import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/palette.dart';
import '../../design/paper_painter.dart';
import '../../garden/daylight_providers.dart';

/// Sky, sun or moon, and two cut-paper hills behind the garden.
///
/// Colours come from [GardenColors], so season and theme apply here too. The
/// time of day comes from the device clock, not from dark mode.
class GardenBackdrop extends ConsumerWidget {
  const GardenBackdrop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = GardenColors.of(context);

    return RepaintBoundary(
      child: CustomPaint(
        painter: GardenBackdropPainter(
          sky: colors.skyDay,
          foliage: colors.foliage,
          sun: colors.skyGoldenHour,
          daylight: ref.watch(daylightProvider),
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

/// Sky colours for a given time of day. Shared by the painter and the header,
/// which needs to know what it's drawn on.
@immutable
final class GardenSky {
  const GardenSky({required this.day, required this.daylight});

  /// The season's daytime sky.
  final Color day;
  final Daylight daylight;

  double get darkness => 1 - Curves.easeInOut.transform(daylight.light);

  Color get night => Color.lerp(Palette.backgroundDark, day, 0.18)!;

  Color get zenith => Color.lerp(day, night, darkness)!;

  Color horizon(Color sun) => Color.lerp(zenith, sun, daylight.warmth * 0.7)!;

  /// Light or dark text, whichever has more contrast with [zenith].
  Color get ink {
    final sky = zenith.computeLuminance();
    double contrast(Color text) {
      final l = text.computeLuminance();
      return (math.max(sky, l) + 0.05) / (math.min(sky, l) + 0.05);
    }

    return contrast(Palette.textPrimaryDark) > contrast(Palette.textPrimary)
        ? Palette.textPrimaryDark
        : Palette.textPrimary;
  }
}

class GardenBackdropPainter extends CustomPainter {
  const GardenBackdropPainter({
    required this.sky,
    required this.foliage,
    required this.sun,
    required this.daylight,
  });

  /// Daytime sky.
  final Color sky;

  /// The hills are faded from this.
  final Color foliage;

  final Color sun;
  final Daylight daylight;

  /// How far each hill fades toward the sky. Far one more, for depth.
  static const double _farFade = 0.55;
  static const double _nearFade = 0.3;

  /// Same shadow the sprites use.
  static const Offset _shadowOffset = Offset(0, 3);
  static const double _shadowBlur = 2.5;

  /// Disc radius, as a fraction of the width.
  static const double _disc = 0.1;

  // x, y (fractions of the size) and radius in px.
  static const List<(double, double, double)> _stars = [
    (0.06, 0.09, 1.2),
    (0.13, 0.24, 0.9),
    (0.19, 0.05, 1.0),
    (0.24, 0.17, 1.4),
    (0.31, 0.29, 0.8),
    (0.36, 0.08, 1.1),
    (0.43, 0.21, 0.9),
    (0.49, 0.04, 1.3),
    (0.55, 0.14, 0.8),
    (0.61, 0.27, 1.0),
    (0.66, 0.07, 1.2),
    (0.72, 0.19, 0.9),
    (0.78, 0.03, 0.8),
    (0.83, 0.25, 1.3),
    (0.88, 0.11, 1.0),
    (0.94, 0.20, 0.9),
    (0.97, 0.06, 1.1),
    (0.02, 0.30, 1.0),
  ];

  GardenSky get _sky => GardenSky(day: sky, daylight: daylight);

  Color get paintedSky => _sky.zenith;

  Color get horizonSky => _sky.horizon(sun);

  Color get farHill => _hill(_farFade);

  Color get nearHill => _hill(_nearFade);

  /// Sun by day, a paler moon at night.
  Color get discColour =>
      daylight.sunUp ? sun : Color.lerp(sun, Palette.surfaceLight, 0.6)!;

  // Squared so the stars don't show until it's nearly dark.
  double get starlight => _sky.darkness * _sky.darkness;

  Color _hill(double fade) => Color.lerp(
        Color.lerp(foliage, sky, fade),
        Palette.backgroundDark,
        0.72 * _sky.darkness,
      )!;

  /// Centre of the sun or moon. Starts and ends below the hill line.
  Offset discCentre(Size size) {
    final low = size.height * 0.5 + size.width * _disc;
    // Peak is at 0.32 so the disc stays under the header text, including a
    // headline that wraps to two lines.
    final high = size.height * 0.32;

    return Offset(
      size.width * lerpDouble(0.14, 0.86, daylight.arc)!,
      low - math.sin(math.pi * daylight.arc) * (low - high),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;

    _paintSky(canvas, size);
    _paintStars(canvas, size);

    _cut(
      canvas,
      Path()
        ..addOval(Rect.fromCircle(center: discCentre(size), radius: w * _disc)),
      discColour,
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

  void _paintSky(Canvas canvas, Size size) {
    final top = paintedSky;
    final bottom = horizonSky;
    final paint = Paint()..color = top;

    if (bottom != top) {
      // Only the top half is visible above the hills.
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
        stops: const [0.25, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height / 2));
    }
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintStars(Canvas canvas, Size size) {
    if (starlight <= 0) return;

    final paint = Paint()
      ..color = Palette.surfaceLight.withValues(alpha: 0.85 * starlight);
    for (final (x, y, radius) in _stars) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), radius, paint);
    }
  }

  /// Shadow first, then the shape.
  void _cut(Canvas canvas, Path shape, Color colour) {
    canvas
      ..drawPath(
        shape.shift(_shadowOffset),
        Paint()
          ..color = Palette.textPrimary.withValues(
            alpha: lerpDouble(0.22, 0.45, _sky.darkness),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _shadowBlur),
      )
      ..drawPath(shape, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(GardenBackdropPainter old) =>
      old.sky != sky ||
      old.foliage != foliage ||
      old.sun != sun ||
      old.daylight != daylight;
}
