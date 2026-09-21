import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/palette.dart';
import '../../garden/growing_plant.dart';

/// The session's plant in a clay pot. [GrowingPlant] draws the plant, soil and
/// all its animations; the pot is drawn in front with its rim at the soil line.
class PottedPlant extends StatelessWidget {
  const PottedPlant({
    required this.growth,
    required this.height,
    this.completed = false,
    this.onLanded,
    super.key,
  });

  /// Null for bare soil.
  final PlantGrowth? growth;

  /// Plant and pot together.
  final double height;

  /// See [GrowingPlant.completed].
  final bool completed;

  /// See [GrowingPlant.onLanded].
  final VoidCallback? onLanded;

  /// Where [GrowingPlant] puts its soil line, as a fraction of its box.
  static const double _soilLine = 0.916;

  /// Rim width relative to the plant's box; a bit wider so the soil sits
  /// inside.
  static const double _rimToPlant = 1.06;

  /// Rim and body heights as fractions of the rim width.
  static const double _rimDepth = 0.16;
  static const double _bodyDepth = 0.5;

  /// Plant box side for a pot [height] tall overall.
  static double plantSideFor(double height) =>
      height / (_soilLine + (_rimDepth + _bodyDepth) * _rimToPlant);

  @override
  Widget build(BuildContext context) {
    final side = plantSideFor(height);
    final rim = side * _rimToPlant;
    final night = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: rim,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          GrowingPlant(
            growth: growth,
            size: side,
            completed: completed,
            onLanded: onLanded,
          ),
          Positioned(
            top: side * _soilLine,
            left: 0,
            right: 0,
            bottom: 0,
            child: ExcludeSemantics(
              child: CustomPaint(painter: PotPainter(night: night)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rim plus a body tapering to a rounded foot, each with a soft paper shadow.
class PotPainter extends CustomPainter {
  const PotPainter({required this.night});

  /// Darkened toward the background in dark mode.
  final bool night;

  Color _lit(Color colour) =>
      night ? Color.lerp(colour, Palette.backgroundDark, 0.35)! : colour;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final rimHeight = w * PottedPlant._rimDepth;
    final h = size.height;
    final foot = w * 0.13;
    final shoulder = w * 0.05;

    final body = Path()
      ..moveTo(shoulder, rimHeight * 0.6)
      ..lineTo(w - shoulder, rimHeight * 0.6)
      ..lineTo(w - foot, h - w * 0.05)
      ..quadraticBezierTo(w - foot - w * 0.01, h, w - foot - w * 0.07, h)
      ..lineTo(foot + w * 0.07, h)
      ..quadraticBezierTo(foot + w * 0.01, h, foot, h - w * 0.05)
      ..close();
    final rim = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, rimHeight),
        Radius.circular(w * 0.02),
      ));

    _cut(canvas, body, _lit(Palette.clay));
    _cut(canvas, rim, _lit(Palette.clayRim));
    canvas.drawLine(
      Offset(w * 0.08, rimHeight + w * 0.01),
      Offset(w * 0.92, rimHeight + w * 0.01),
      Paint()
        ..color = _lit(Palette.clayShade)
        ..strokeWidth = w * 0.016,
    );
  }

  void _cut(Canvas canvas, Path shape, Color colour) {
    canvas
      ..drawPath(
        shape.shift(const Offset(0, 3)),
        Paint()
          ..color = Palette.textPrimary.withValues(alpha: night ? 0.45 : 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      )
      ..drawPath(shape, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(PotPainter old) => old.night != night;
}
