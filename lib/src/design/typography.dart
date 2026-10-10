import 'package:flutter/widgets.dart';

/// The type ramp from PRD §5.1.
///
/// §5.1 specifies SF Pro Rounded for headings and timer numerals. That family
/// ships only on iOS, and this app runs on Android at parity, so the app
/// bundles **Nunito** — a rounded humanist sans with the same warmth — and uses
/// it on both platforms. Bundling rather than fetching also keeps first launch
/// working offline.
abstract final class GardenTypography {
  /// The bundled UI family. Declared in `pubspec.yaml` at weights 400/600/700.
  static const String fontFamily = 'Nunito';

  /// The handwritten family §5.1 asks for on botanical labels — plant names,
  /// and nothing else. Caveat, the PRD's own example. Bundled at 400/600.
  static const String botanicalFontFamily = 'Caveat';

  /// Headings are semibold, per §5.1's "rounded, semibold — warm, friendly".
  static const FontWeight headingWeight = FontWeight.w600;

  /// Body copy is regular.
  static const FontWeight bodyWeight = FontWeight.w400;

  /// Screen titles.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontWeight: headingWeight,
    fontSize: 34,
    height: 1.2,
    letterSpacing: -0.4,
  );

  /// Section headings within a screen.
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: headingWeight,
    fontSize: 24,
    height: 1.25,
    letterSpacing: -0.2,
  );

  /// Card and list-row headings.
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: headingWeight,
    fontSize: 17,
    height: 1.3,
  );

  /// Default body copy.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: bodyWeight,
    fontSize: 16,
    height: 1.4,
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
    letterSpacing: 0.2,
  );

  /// The timer readout: large, rounded, and **tabular**.
  ///
  /// [FontFeature.tabularFigures] forces every digit onto the same advance
  /// width, so `25:00` counting down to `24:59` does not jitter horizontally as
  /// glyphs change each second. This is the one style in the ramp with a
  /// behavioural requirement rather than a visual one, and
  /// `test/design/typography_test.dart` measures it.
  static const TextStyle timerDigits = TextStyle(
    fontFamily: fontFamily,
    fontWeight: headingWeight,
    fontSize: 64,
    height: 1.1,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// [timerDigits], sized to sit inside a ring [ringDiameter] across.
  ///
  /// The countdown has to shrink with the ring on a small screen, and a screen
  /// that wrote its own font size to do that would be the one place in the app
  /// picking type by hand. The ratio lives here instead: a quarter of the
  /// diameter leaves the digits comfortably clear of the stroke at every size
  /// the ring is allowed to take.
  static TextStyle timerDigitsInRing(double ringDiameter) =>
      timerDigits.copyWith(fontSize: ringDiameter * _timerDigitsToRing);

  static const double _timerDigitsToRing = 0.24;

  /// The timer readout at glanceable size — session rows, the journal, and
  /// anywhere a duration sits inline. Tabular for the same reason.
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

  /// Plant names, as if pencilled onto a plant label. Set larger than body
  /// copy because Caveat's x-height runs small next to Nunito's.
  ///
  /// One of the two styles off the UI family, and it applies to plant names
  /// alone — [journalHeading] is the other, and between them they are the whole
  /// of §5.1's handwriting. Setting UI chrome in either would be a misread.
  static const TextStyle botanicalLabel = TextStyle(
    fontFamily: botanicalFontFamily,
    fontWeight: bodyWeight,
    fontSize: 22,
    height: 1.2,
  );

  /// The headings in the botanical journal — "This week", "August 2026",
  /// "Lifetime" — as if written at the top of a page.
  ///
  /// REQ-025 asks for handwritten headers on that screen by name, which is why
  /// this exists at all: it is the one place other than a plant's label where
  /// §5.1's second face is the *specified* type rather than a decoration
  /// somebody reached for. Semibold and larger than [botanicalLabel], because a
  /// heading holding up a card of figures has more work to do than a name on a
  /// stake, and Caveat at regular weight goes faint at heading sizes.
  static const TextStyle journalHeading = TextStyle(
    fontFamily: botanicalFontFamily,
    fontWeight: headingWeight,
    fontSize: 30,
    height: 1.15,
  );
}
