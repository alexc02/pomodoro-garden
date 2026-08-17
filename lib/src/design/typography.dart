import 'package:flutter/widgets.dart';

/// Type ramp. Two bundled families (both SIL OFL), so Android matches iOS and
/// the first launch works offline:
///
/// - Inter for UI: body, labels, buttons, tab bar.
/// - Fraunces for display: titles, headings, plant names.
abstract final class GardenTypography {
  /// Bundled at 400/600/700.
  static const String fontFamily = 'Inter';

  /// Bundled at 600, upright and italic.
  static const String displayFontFamily = 'Fraunces';

  static const FontWeight headingWeight = FontWeight.w600;

  static const FontWeight bodyWeight = FontWeight.w400;

  static const TextStyle displayLarge = TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: headingWeight,
    fontSize: 34,
    height: 1.1,
    letterSpacing: -0.4,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: headingWeight,
    fontSize: 24,
    height: 1.2,
    letterSpacing: -0.2,
  );

  /// Card/list headings, app-bar titles, button labels. Inter, since these
  /// sit inside controls.
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: headingWeight,
    fontSize: 17,
    height: 1.3,
    letterSpacing: -0.2,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: bodyWeight,
    fontSize: 16,
    height: 1.45,
    letterSpacing: -0.1,
  );

  /// Card subtitles, secondary paragraphs.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: bodyWeight,
    fontSize: 14,
    height: 1.4,
  );

  /// Captions, secondary labels, tab labels.
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: bodyWeight,
    fontSize: 12,
    height: 1.2,
    letterSpacing: 0.1,
  );

  /// The countdown. Tabular figures so it doesn't jitter as digits change
  /// (checked in `test/design/typography_test.dart`). Inter because Fraunces
  /// has no tabular figures.
  static const TextStyle timerDigits = TextStyle(
    fontFamily: fontFamily,
    fontWeight: headingWeight,
    fontSize: 64,
    height: 1.0,
    letterSpacing: -1.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// [timerDigits] sized for a screen [width] across: about a quarter of the
  /// width, clamped so tablets don't get huge digits.
  static TextStyle timerDigitsFor(double width) => timerDigits.copyWith(
        fontSize: (width * _timerDigitsToWidth).clamp(56.0, 104.0),
        letterSpacing: -3,
      );

  static const double _timerDigitsToWidth = 0.27;

  /// Small timer readout for inline durations (session rows, journal).
  static const TextStyle timerDigitsSmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: headingWeight,
    fontSize: 20,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Tabular figures for inline durations in other styles, e.g. a paused
  /// caption counting up.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Plant names: Fraunces italic, like a plant label. Don't use for UI.
  static const TextStyle botanicalLabel = TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: headingWeight,
    fontStyle: FontStyle.italic,
    fontSize: 21,
    height: 1.2,
  );

  /// Journal section headings ("This week", "Lifetime"). Bigger than
  /// [botanicalLabel].
  static const TextStyle journalHeading = TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: headingWeight,
    fontSize: 26,
    height: 1.15,
    letterSpacing: -0.3,
  );
}
