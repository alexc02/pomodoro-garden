import 'dart:io';

import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/design/typography.dart';

/// Widget tests render with a stand-in font whose glyphs are all the same
/// width, which would make any width assertion below pass for the wrong reason.
/// So load the real Inter and Fraunces files the app bundles.
Future<void> _loadBundledFonts() async {
  const families = {
    GardenTypography.fontFamily: [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ],
    GardenTypography.displayFontFamily: [
      'assets/fonts/Fraunces-SemiBold.ttf',
      'assets/fonts/Fraunces-SemiBoldItalic.ttf',
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
            'check the asset paths in _loadBundledFonts.',
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

    test('is in the UI family, the one of the two with tabular figures', () {
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

  group('the two families', () {
    test('the display face carries the headings and the botany', () {
      for (final style in const [
        GardenTypography.displayLarge,
        GardenTypography.headlineMedium,
        GardenTypography.botanicalLabel,
        GardenTypography.journalHeading,
      ]) {
        expect(style.fontFamily, GardenTypography.displayFontFamily);
      }
    });

    test('controls and every readout are in the UI family', () {
      for (final style in const [
        GardenTypography.titleMedium,
        GardenTypography.bodyMedium,
        GardenTypography.bodySmall,
        GardenTypography.labelSmall,
        GardenTypography.timerDigits,
        GardenTypography.timerDigitsSmall,
      ]) {
        expect(style.fontFamily, GardenTypography.fontFamily);
      }
    });

    test('a plant name is italic, so it reads as a label and not a heading', () {
      expect(GardenTypography.botanicalLabel.fontStyle, FontStyle.italic);
      expect(GardenTypography.journalHeading.fontStyle, isNot(FontStyle.italic));
    });

    test('heads the journal larger than it labels a plant', () {
      expect(
        GardenTypography.journalHeading.fontSize!,
        greaterThan(GardenTypography.botanicalLabel.fontSize!),
      );
    });

    test('renders the display face from the bundle, not a fallback', () {
      // Fraunces and Inter set the same word at markedly different widths. If
      // the display family failed to load, Flutter would silently substitute
      // and these widths would coincide.
      const size = 32.0;
      const sample = 'Sunflower';

      final display = _widthOf(
        sample,
        const TextStyle(
          fontFamily: GardenTypography.displayFontFamily,
          fontSize: size,
        ),
      );
      final ui = _widthOf(
        sample,
        const TextStyle(fontFamily: GardenTypography.fontFamily, fontSize: size),
      );

      expect(display, isNot(ui));
    });
  });
}
