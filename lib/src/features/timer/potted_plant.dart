import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/palette.dart';
import '../../garden/growing_plant.dart';

/// The session's plant, growing in a clay pot (PRD v2.3, Paper Theatre).
///
/// The middle of the timer screen. Before this the plant stood on a strip of
/// soil under a ring; in a pot it is one object — something on a windowsill
/// that is being grown, rather than a diagram of growth.
///
/// [GrowingPlant] draws the plant and its soil, and the pot is drawn in front
/// of it with its rim at the plant's soil line: the soil shows in the mouth of
/// the pot, and the stem rises out of it. Every animation the plant has — the
/// drop, the landing, the bloom — is [GrowingPlant]'s, untouched.
class PottedPlant extends StatelessWidget {
  const PottedPlant({
    required this.growth,
    required this.height,
    this.completed = false,
    this.onLanded,
    super.key,
  });

  /// What is growing, or null for a pot of bare soil.
  final PlantGrowth? growth;

  /// How tall the plant and its pot stand together.
  final double height;

  /// See [GrowingPlant.completed].
  final bool completed;

  /// See [GrowingPlant.onLanded].
  final VoidCallback? onLanded;

  /// Where [GrowingPlant] puts its soil line, as a fraction of its box.
  static const double _soilLine = 0.916;

  /// How wide the pot's rim is against the plant's box: a little wider, so the
  /// plant's bed of soil sits inside the mouth.
  static const double _rimToPlant = 1.06;

  /// The rim's and the body's heights, as fractions of the rim's width.
  static const double _rimDepth = 0.16;
  static const double _bodyDepth = 0.5;

  /// The side of the plant's box, for a pot [height] tall overall.
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

/// The pot: a rim, and a body tapering to a rounded foot, each a layer of cut
/// paper casting a soft shadow.
class PotPainter extends CustomPainter {
  const PotPainter({required this.night});

  /// Whether to draw it at night, sunk toward the dark canvas.
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
