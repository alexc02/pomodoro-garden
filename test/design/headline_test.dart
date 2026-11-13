import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/design/headline.dart';

const _style = TextStyle(fontSize: 30, height: 1);

/// [text] as a [Headline] in a box [width] wide, with the system text size at
/// [system] times the default.
Future<void> _pump(
  WidgetTester tester,
  String text, {
  required double width,
  double system = 1,
}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(system)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: Headline(text, style: _style),
          ),
        ),
      ),
    ),
  );
}

RenderParagraph _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.byType(RichText));

double _scale(WidgetTester tester) =>
    tester.widget<RichText>(find.byType(RichText)).textScaler.scale(100) / 100;

/// The text of each line as laid out.
List<String> _lines(WidgetTester tester, String text) {
  // Laid out again the same way, to ask where the lines fall.
  final rendered = _paragraph(tester);
  final paragraph = TextPainter(
    text: rendered.text,
    textScaler: rendered.textScaler,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: rendered.constraints.maxWidth);
  addTearDown(paragraph.dispose);
  final lines = <String>[];
  var start = 0;
  while (start < text.length) {
    final line = paragraph.getLineBoundary(TextPosition(offset: start));
    lines.add(text.substring(line.start, line.end).trim());
    if (line.end <= start) break;
    start = line.end;
  }
  return lines.where((line) => line.isNotEmpty).toList();
}

void main() {
  group('how a heading grows', () {
    test('exactly as asked at ordinary sizes', () {
      for (final system in [0.8, 1.0, 1.15, 1.3]) {
        expect(Headline.scaleFor(system), system);
      }
    });

    test('more gently than body text once that is large', () {
      expect(Headline.scaleFor(2), closeTo(1.545, 0.001));
      expect(Headline.scaleFor(3.1), closeTo(1.93, 0.001));
    });

    test('always upwards, and never faster than the system asks', () {
      var previous = 0.0;
      for (var system = 0.5; system <= 4; system += 0.1) {
        final scale = Headline.scaleFor(system);
        expect(scale, greaterThan(previous));
        expect(scale, lessThanOrEqualTo(system + 1e-9));
        previous = scale;
      }
    });
  });

  group('a heading that fits', () {
    testWidgets('is one line at the size asked for', (tester) async {
      await _pump(tester, 'Herbs', width: 400);

      expect(_scale(tester), 1);
      expect(_lines(tester, 'Herbs'), ['Herbs']);
    });

    testWidgets('grows with the system size', (tester) async {
      await _pump(tester, 'Herbs', width: 400, system: 1.2);

      expect(_scale(tester), closeTo(1.2, 0.001));
    });
  });

  group('a heading too long for one line', () {
    const text = 'Twelve of twenty-four found.';

    testWidgets('wraps between words, onto as many lines as it needs',
        (tester) async {
      await _pump(tester, text, width: 260);

      final lines = _lines(tester, text);
      expect(lines.length, greaterThan(1));
      expect(lines.join(' ').replaceAll('- ', '-'), text);
      expect(_paragraph(tester).didExceedMaxLines, isFalse);
      // Every word intact on some line.
      for (final word in ['Twelve', 'of', 'found.']) {
        expect(lines.any((line) => line.split(' ').contains(word)), isTrue);
      }
    });

    testWidgets('may break after a hyphen', (tester) async {
      // Room for "twenty-" but not "twenty-four".
      await _pump(tester, 'twenty-four', width: 30.0 * 8);

      expect(_scale(tester), 1, reason: 'no need to shrink');
      expect(_lines(tester, 'twenty-four'), ['twenty-', 'four']);
    });
  });

  group('a word wider than the space', () {
    testWidgets('shrinks the heading until it fits, unbroken', (tester) async {
      // "Wildflowers" is 11 glyphs of 30: 330 wide in the test font.
      await _pump(tester, 'Wildflowers', width: 200);

      expect(_scale(tester), lessThan(1));
      expect(_lines(tester, 'Wildflowers'), ['Wildflowers']);
      expect(
        tester.getSize(find.byType(RichText)).width,
        lessThanOrEqualTo(200),
      );
    });

    testWidgets('holds at any system size, however large', (tester) async {
      for (final system in [1.0, 2.0, 3.1, 5.0]) {
        await _pump(tester, 'Wildflowers', width: 320, system: system);

        expect(
          _lines(tester, 'Wildflowers'),
          ['Wildflowers'],
          reason: 'at $system',
        );
      }
    });

    testWidgets('shrinks no more than that word needs', (tester) async {
      await _pump(tester, 'Small trees', width: 100);

      // "Small" and "trees" are each 150 wide; they stack at 100.
      expect(_scale(tester), closeTo(100 / 150, 0.02));
      expect(_lines(tester, 'Small trees'), ['Small', 'trees']);
    });
  });

  testWidgets('with no width to fit, keeps the size asked for', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: UnconstrainedBox(
          child: Headline('Wildflowers', style: _style),
        ),
      ),
    );

    expect(_scale(tester), 1);
  });
}
