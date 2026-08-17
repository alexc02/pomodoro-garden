import 'package:flutter/widgets.dart';

import 'tab.dart';

/// Custom line icon for a tab (sprout, hourglass, notebook, sliders), drawn
/// on a 24-unit grid with round caps.
///
/// Sized and coloured from [IconTheme] like an [Icon]. Selected is a heavier
/// stroke rather than a fill. Excluded from semantics; the label says it.
class TabGlyph extends StatelessWidget {
  const TabGlyph(
    this.tab, {
    this.selected = false,
    this.size,
    this.color,
    super.key,
  });

  final AppTab tab;

  final bool selected;

  /// Defaults to the [IconTheme]'s size.
  final double? size;

  /// Defaults to the [IconTheme]'s colour.
  final Color? color;

  /// In grid units.
  static const double stroke = 2;
  static const double selectedStroke = 2.5;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final side = size ?? iconTheme.size ?? 24;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: side,
        child: CustomPaint(
          painter: TabGlyphPainter(
            tab: tab,
            color: color ?? iconTheme.color ?? const Color(0xFF000000),
            stroke: selected ? selectedStroke : stroke,
          ),
        ),
      ),
    );
  }
}

/// Strokes only, never a fill.
class TabGlyphPainter extends CustomPainter {
  const TabGlyphPainter({
    required this.tab,
    required this.color,
    required this.stroke,
  });

  final AppTab tab;
  final Color color;

  /// In grid units.
  final double stroke;

  static const double grid = 24;

  static Path pathFor(AppTab tab) => switch (tab) {
        AppTab.garden => Path()
          ..moveTo(12, 21)
          ..lineTo(12, 12)
          ..moveTo(12, 12)
          ..cubicTo(12, 8, 15, 6, 19, 6)
          ..cubicTo(19, 10, 16, 12, 12, 12)
          ..close()
          ..moveTo(12, 14)
          ..cubicTo(12, 11, 10, 9, 6, 9)
          ..cubicTo(6, 12, 8, 14, 12, 14)
          ..close()
          ..moveTo(6, 21)
          ..lineTo(18, 21),
        AppTab.timer => Path()
          ..moveTo(7, 3)
          ..lineTo(17, 3)
          ..moveTo(7, 21)
          ..lineTo(17, 21)
          ..moveTo(8, 3)
          ..cubicTo(8, 8, 16, 8, 16, 12)
          ..cubicTo(16, 16, 8, 16, 8, 21)
          ..moveTo(16, 3)
          ..cubicTo(16, 8, 8, 8, 8, 12)
          ..cubicTo(8, 16, 16, 16, 16, 21),
        AppTab.journal => Path()
          ..moveTo(5, 4)
          ..lineTo(16, 4)
          ..arcToPoint(const Offset(19, 7), radius: const Radius.circular(3))
          ..lineTo(19, 20)
          ..lineTo(8, 20)
          ..arcToPoint(const Offset(5, 17), radius: const Radius.circular(3))
          ..close()
          ..moveTo(5, 17)
          ..arcToPoint(const Offset(8, 14), radius: const Radius.circular(3))
          ..lineTo(19, 14),
        AppTab.settings => Path()
          ..moveTo(4, 7)
          ..lineTo(14, 7)
          ..moveTo(18, 7)
          ..lineTo(20, 7)
          ..moveTo(4, 17)
          ..lineTo(8, 17)
          ..moveTo(12, 17)
          ..lineTo(20, 17)
          ..addOval(Rect.fromCircle(center: const Offset(16, 7), radius: 2))
          ..addOval(Rect.fromCircle(center: const Offset(10, 17), radius: 2)),
      };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.shortestSide / grid;
    canvas
      ..save()
      ..scale(scale)
      ..drawPath(
        pathFor(tab),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(TabGlyphPainter old) =>
      old.tab != tab || old.color != color || old.stroke != stroke;
}
