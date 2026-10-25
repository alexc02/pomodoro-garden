import 'package:flutter/material.dart';

import '../design/palette.dart';

/// A strip of paper whose top edge was torn rather than cut (PRD v2.3, Paper
/// Theatre): the tab bar.
///
/// The tear rises [height] above [child] and is painted in front of whatever
/// is behind it, so the screen above appears to run on underneath the bar. It
/// takes no space of its own — a screen laid out against the bar loses nothing
/// to it — and takes no taps: it is a few pixels of decoration over the bottom
/// of a screen, and a tap there belongs to the screen.
///
/// The colour is the [NavigationBarThemeData]'s background, so the tear and the
/// bar under it are one sheet in both themes.
class TornEdge extends StatelessWidget {
  const TornEdge({required this.child, super.key});

  final Widget child;

  /// How far the tear rises above the child.
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

/// The painting behind [TornEdge]: the ragged top of the sheet and the soft
/// shadow it casts upward onto the screen.
class TornEdgePainter extends CustomPainter {
  const TornEdgePainter({required this.paper});

  final Color paper;

  /// One run of the tear, as (step across, depth down) pairs: points every
  /// eighteen or so pixels, each some way down from the top of the strip.
  ///
  /// Fixed rather than random, so the bar is the same bar on every frame and
  /// in every test, and repeated across the width, so a wider screen gets more
  /// tear rather than a stretched one.
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

  /// The path of the tear across [size], closed along the strip's bottom.
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
