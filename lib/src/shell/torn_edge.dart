import 'package:flutter/material.dart';

import '../design/palette.dart';

/// Torn-paper top edge for the tab bar.
///
/// The tear overhangs [child] by [height], takes no layout space and ignores
/// taps. Uses the [NavigationBarThemeData] background so it matches the bar.
class TornEdge extends StatelessWidget {
  const TornEdge({required this.child, super.key});

  final Widget child;

  static const double height = 10;

  @override
  Widget build(BuildContext context) {
    final paper = NavigationBarTheme.of(context).backgroundColor ??
        Theme.of(context).colorScheme.surface;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          top: -height,
          height: height + 1,
          child: IgnorePointer(
            child: CustomPaint(painter: TornEdgePainter(paper: paper)),
          ),
        ),
      ],
    );
  }
}

/// Paints the ragged edge and its upward shadow.
class TornEdgePainter extends CustomPainter {
  const TornEdgePainter({required this.paper});

  final Color paper;

  /// (step across, depth down) pairs, repeated across the width. Fixed rather
  /// than random so it is stable across frames and tests.
  static const List<(double, double)> _run = [
    (18, 2),
    (16, 7),
    (18, 1),
    (18, 6),
    (20, 3),
    (18, 8),
    (20, 2),
    (18, 6),
    (20, 1),
    (20, 7),
    (18, 3),
    (20, 6),
    (18, 1),
    (20, 7),
    (18, 2),
    (20, 6),
    (20, 1),
    (18, 7),
    (18, 3),
    (18, 8),
    (16, 4),
  ];

  static Path tear(Size size) {
    final scale = size.height / TornEdge.height;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 6 * scale);
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final (step, depth) = _run[i % _run.length];
      x += step;
      path.lineTo(x, depth * scale);
      i++;
    }
    return path
      ..lineTo(x, size.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final edge = tear(size);
    canvas
      ..drawPath(
        edge.shift(const Offset(0, -1.5)),
        Paint()
          ..color = Palette.textPrimary.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      )
      ..drawPath(edge, Paint()..color = paper);
  }

  @override
  bool shouldRepaint(TornEdgePainter old) => old.paper != paper;
}
