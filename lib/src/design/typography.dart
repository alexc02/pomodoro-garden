import 'package:flutter/widgets.dart';

/// The type ramp from PRD §5.1, as revised by the Paper Theatre direction.
///
/// Two bundled families, both SIL OFL and both common in iOS apps:
///
/// - **Inter** is the UI family — body copy, labels, buttons, the tab bar. It
///   is what keeps the controls reading as familiar, legible interface.
/// - **Fraunces** is the display face — screen titles, section headings, the
///   timer readout and plant names. A soft, slightly old-style serif: the
///   "cut-paper picture book" half of §5.1's brief, where Inter is the
///   "Apple Reminders minimalism" half.
///
/// §5.1 originally asked for SF Pro Rounded, which ships only on iOS; bundling
/// both families keeps Android at parity and first launch working offline.
abstract final class GardenTypography {
  /// The UI family. Declared in `pubspec.yaml` at weights 400/600/700.
  static const String fontFamily = 'Inter';

  /// The display face. Declared in `pubspec.yaml` at 600, upright and italic.
  ///
  /// It replaces the handwritten face §5.1 named for plant names and REQ-025's
  /// journal headers: a script font was the most generic way to say "warm",
  /// and an italic serif carries the same hand-labelled feel without it.
  static const String displayFontFamily = 'Fraunces';

  /// Headings are semibold in both families.
  static const FontWeight headingWeight = FontWeight.w600;

  /// Body copy is regular.
  static const FontWeight bodyWeight = FontWeight.w400;

  /// Screen titles.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: headingWeight,
    fontSize: 34,
    height: 1.1,
    letterSpacing: -0.4,
  );

  /// Section headings within a screen.
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: headingWeight,
    fontSize: 24,
    height: 1.2,
    letterSpacing: -0.2,
  );

  /// Card and list-row headings, app-bar titles and button labels. In the UI
  /// family: these sit inside controls, where the display face would be noise.
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: headingWeight,
    fontSize: 17,
    height: 1.3,
    letterSpacing: -0.2,
  );

  /// Default body copy.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: bodyWeight,
    fontSize: 16,
    height: 1.45,
    letterSpacing: -0.1,
  );

  /// Body copy in a supporting role: card subtitles, secondary paragraphs.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: bodyWeight,
    fontSize: 14,
    height: 1.4,
  );

  /// Captions, secondary labels, tab-bar labels.
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: bodyWeight,
    fontSize: 12,
    height: 1.2,
    letterSpacing: 0.1,
  );

  /// The timer readout: large, semibold, and **tabular**.
  ///
  /// [FontFeature.tabularFigures] forces every digit onto the same advance
  /// width, so `25:00` counting down to `24:59` does not jitter horizontally as
  /// glyphs change each second. This is the one style in the ramp with a
  /// behavioural requirement rather than a visual one, and
  /// `test/design/typography_test.dart` measures it.
  ///
  /// **In the UI family, not the display face.** Fraunces has no tabular
  /// figures — its `1` is two-thirds the width of its `0` — so a countdown set
  /// in it would shift on every tick. Inter's are tabular.
  static const TextStyle timerDigits = TextStyle(
    fontFamily: fontFamily,
    fontWeight: headingWeight,
    fontSize: 64,
    height: 1.0,
    letterSpacing: -1.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// [timerDigits] at the timer screen's size, for a screen [width] across
  /// (PRD v2.3).
  ///
  /// The countdown is the largest thing on the screen, read from across a
  /// desk: about a quarter of the width, which is five digits and a colon
  /// filling most of a phone held upright, and capped so a tablet does not get
  /// a wall of numbers. A screen that wrote its own font size to do this would
  /// be the one place in the app picking type by hand; the ratio lives here.
  static TextStyle timerDigitsFor(double width) => timerDigits.copyWith(
        fontSize: (width * _timerDigitsToWidth).clamp(56.0, 104.0),
        letterSpacing: -3,
      );

  static const double _timerDigitsToWidth = 0.27;

  /// The timer readout at glanceable size — session rows, the journal, and
  /// anywhere a duration sits inline. In the UI family, because at this size
  /// it sits among labels rather than above them; tabular for the same reason.
  static const TextStyle timerDigitsSmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: headingWeight,
    fontSize: 20,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Digits on a fixed advance width, for a style that is not one of the timer
  /// readouts.
  ///
  /// The same contract [timerDigits] carries, available to the places a
  /// duration sits *inside* a sentence — a caption counting up while a session
  /// is paused — where [timerDigitsSmall] would be the wrong size but the
  /// jitter would be the same jitter.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Plant names, as if lettered onto a plant label: the display face in
  /// italic.
  ///
  /// Plant names and [journalHeading] are §5.1's "botanical" type. Setting UI
  /// chrome in either would be a misread.
  static const TextStyle botanicalLabel = TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: headingWeight,
    fontStyle: FontStyle.italic,
    fontSize: 21,
    height: 1.2,
  );

  /// The headings in the botanical journal — "This week", "August 2026",
  /// "Lifetime" — as if written at the top of a page.
  ///
  /// REQ-025 asks for distinct headers on that screen by name. Larger than
  /// [botanicalLabel], because a heading holding up a card of figures has more
  /// work to do than a name on a stake.
  static const TextStyle journalHeading = TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: headingWeight,
    fontSize: 26,
    height: 1.15,
    letterSpacing: -0.3,
  );
}
