import 'dart:io';

import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_garden/src/design/typography.dart';

/// Widget tests render with a stand-in font whose glyphs are all the same
/// width, which would make any width assertion below pass for the wrong reason.
/// So load the real Nunito files the app bundles.
Future<void> _loadBundledFonts() async {
  const families = {
    GardenTypography.fontFamily: [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-SemiBold.ttf',
    ],
    GardenTypography.botanicalFontFamily: [
      'assets/fonts/Caveat-Regular.ttf',
      'assets/fonts/Caveat-SemiBold.ttf',
    ],
  };

  for (final MapEntry(key: family, value: paths) in families.entries) {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(bytes.buffer.asByteData()));
    }
    await loader.load();
  }
}

double _widthOf(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadBundledFonts);

  group('the bundled font', () {
    test('is really loaded, so the width assertions below mean something', () {
      const style = TextStyle(
        fontFamily: GardenTypography.fontFamily,
        fontSize: 64,
      );

      // A proportional font gives 'W' a much wider advance than 'i'. The test
      // fallback font gives them identical widths.
      expect(
        _widthOf('W', style),
        greaterThan(_widthOf('i', style) * 1.5),
        reason: 'Expected a real proportional font, got the test stand-in — '
            'check the asset paths in _loadBundledNunito.',
      );
    });
  });

  group('GardenTypography.timerDigits', () {
    test('holds its width as the digits change', () {
      const style = GardenTypography.timerDigits;

      final widths = <String, double>{
        for (final readout in const ['00:00', '11:11', '88:88', '25:00', '09:59'])
          readout: _widthOf(readout, style),
      };

      expect(
        widths.values.toSet(),
        hasLength(1),
        reason: 'A countdown re-renders every second. If digit advances differ, '
            'the readout shifts horizontally on each tick. Measured: $widths',
      );
    });

    test('gives every digit the same advance', () {
      const style = GardenTypography.timerDigits;

      final widths = {
        for (final digit in '0123456789'.split('')) digit: _widthOf(digit, style),
      };

      expect(widths.values.toSet(), hasLength(1), reason: 'Measured: $widths');
    });

    test('applies the same rule at the inline size', () {
      const style = GardenTypography.timerDigitsSmall;

      expect(_widthOf('00:00', style), _widthOf('88:88', style));
    });

    test('is rounded and semibold, matching the heading voice', () {
      expect(GardenTypography.timerDigits.fontFamily, GardenTypography.fontFamily);
      expect(
        GardenTypography.timerDigits.fontWeight,
        GardenTypography.headingWeight,
      );
    });
  });

  group('the ramp', () {
    test('sets headings semibold and body regular', () {
      for (final heading in const [
        GardenTypography.displayLarge,
        GardenTypography.headlineMedium,
        GardenTypography.titleMedium,
      ]) {
        expect(heading.fontWeight, GardenTypography.headingWeight);
        expect(heading.fontFamily, GardenTypography.fontFamily);
      }

      expect(GardenTypography.bodyMedium.fontWeight, GardenTypography.bodyWeight);
      expect(GardenTypography.bodyMedium.fontFamily, GardenTypography.fontFamily);
    });

    test('descends in size from display to label', () {
      final sizes = [
        GardenTypography.displayLarge.fontSize!,
        GardenTypography.headlineMedium.fontSize!,
        GardenTypography.titleMedium.fontSize!,
        GardenTypography.bodyMedium.fontSize!,
        GardenTypography.bodySmall.fontSize!,
        GardenTypography.labelSmall.fontSize!,
      ];

      expect(sizes, orderedEquals(sizes.toList()..sort((a, b) => b.compareTo(a))));
    });
  });

  group('GardenTypography.botanicalLabel', () {
    test('is the only style off the UI family', () {
      final uiStyles = [
        GardenTypography.displayLarge,
        GardenTypography.headlineMedium,
        GardenTypography.titleMedium,
        GardenTypography.bodyMedium,
        GardenTypography.bodySmall,
        GardenTypography.labelSmall,
        GardenTypography.timerDigits,
        GardenTypography.timerDigitsSmall,
      ];

      for (final style in uiStyles) {
        expect(style.fontFamily, GardenTypography.fontFamily);
      }

      expect(
        GardenTypography.botanicalLabel.fontFamily,
        GardenTypography.botanicalFontFamily,
        reason: 'PRD §5.1: plant names are set in a handwritten face.',
      );
      expect(
        GardenTypography.journalHeading.fontFamily,
        GardenTypography.botanicalFontFamily,
        reason: 'REQ-025: the journal is headed in the same hand.',
      );
    });

    test('heads the journal larger than it labels a plant', () {
      // A heading holding up a card of figures against a name on a stake. Both
      // are Caveat, and a journal set at the label's size reads as a caption.
      expect(
        GardenTypography.journalHeading.fontSize!,
        greaterThan(GardenTypography.botanicalLabel.fontSize!),
      );
    });

    test('renders in the bundled handwritten font, not a fallback', () {
      // Caveat is a connected script; its glyph advances differ markedly from
      // Nunito's at the same size. If the family failed to load, Flutter would
      // silently substitute and these widths would coincide.
      const size = 32.0;
      const sample = 'Sunflower';

      final handwritten = _widthOf(
        sample,
        const TextStyle(
          fontFamily: GardenTypography.botanicalFontFamily,
          fontSize: size,
        ),
      );
      final ui = _widthOf(
        sample,
        const TextStyle(
          fontFamily: GardenTypography.fontFamily,
          fontSize: size,
        ),
      );

      expect(handwritten, isNot(ui));
    });
  });
}
