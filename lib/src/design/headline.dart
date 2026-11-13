import 'package:flutter/material.dart';

/// The system text size as a plain factor, 1 being the default.
double systemTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(100) / 100;

/// Display-face heading text that holds together at any system text size.
///
/// - Grows with the system size, but more gently than body text once that
///   gets large (see [scaleFor]), like the platforms' own large titles. A
///   34pt headline at three times its size leaves room for nothing else.
/// - Wraps onto as many lines as it needs, only ever between words.
/// - If a single word is still too wide, the whole heading shrinks until it
///   fits rather than breaking the word.
///
/// Uses a [LayoutBuilder], so it can't go anywhere that asks for intrinsic
/// sizes or a baseline (a baseline-aligned [Row], say). Use a plain [Text]
/// with [scalerOf] there; the first two points still hold.
class Headline extends StatelessWidget {
  const Headline(this.text, {required this.style, this.textAlign, super.key});

  final String text;

  final TextStyle? style;

  final TextAlign? textAlign;

  /// Up to here a heading grows exactly as the system asks.
  static const double _fullUpTo = 1.3;

  /// Share of any further growth a heading takes.
  static const double _beyond = 0.35;

  /// How much a heading grows when the system asks text to grow by [system]
  /// (1 is the default size). Never shrinks what the system asked for below
  /// the default, and never grows faster than it.
  static double scaleFor(double system) => system <= _fullUpTo
      ? system
      : _fullUpTo + (system - _fullUpTo) * _beyond;

  /// The heading's own text scaler under [context].
  static TextScaler scalerOf(BuildContext context) =>
      TextScaler.linear(scaleFor(systemTextScale(context)));

  /// Where a line may break: at spaces, and after a hyphen.
  static final RegExp _breaks = RegExp(r'\s+|(?<=-)');

  /// The widest unbreakable piece of [text] in [style], unscaled.
  static double widestWord(
    String text,
    TextStyle? style,
    TextDirection direction,
  ) {
    var widest = 0.0;
    for (final word in text.split(_breaks)) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: direction,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    final direction = Directionality.of(context);
    final wanted = scaleFor(systemTextScale(context));

    return LayoutBuilder(
      builder: (context, constraints) {
        var scale = wanted;
        if (constraints.maxWidth.isFinite) {
          final widest = widestWord(text, resolved, direction);
          // Slightly under, so rounding can't push the word onto two lines.
          final fits = constraints.maxWidth / widest * 0.995;
          if (widest > 0 && fits < scale) scale = fits;
        }

        return Text(
          text,
          style: style,
          textAlign: textAlign,
          textScaler: TextScaler.linear(scale),
        );
      },
    );
  }
}
