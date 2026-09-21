import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/design/garden_colors.dart';
import 'package:pip_garden/src/features/journal/journal_heatmap.dart';
import 'package:pip_garden/src/design/paper_painter.dart';
import 'package:pip_garden/src/features/journal/journal_screen.dart';

void main() {
  group('focusLabel', () {
    test('hours and minutes only', () {
      expect(focusLabel(const Duration(minutes: 45)), '45m');
      expect(focusLabel(const Duration(hours: 5, minutes: 20)), '5h 20m');
      expect(focusLabel(const Duration(hours: 143)), '143h');
      expect(focusLabel(const Duration(hours: 1, minutes: 1)), '1h 1m');
    });

    test('truncates seconds', () {
      // A lifetime sum can have seconds even though sessions don't.
      expect(focusLabel(const Duration(minutes: 59, seconds: 59)), '59m');
      expect(focusLabel(Duration.zero), '0m');
    });
  });

  group('day shade', () {
    const colors = GardenColors.light;
    const paper = Color(0xFFF7F5EF);

    Color shade(int sessions, {int busiest = 4}) => heatmapShade(
          sessions: sessions,
          busiestDay: busiest,
          colors: colors,
          paper: paper,
        );

    test('empty day is soil', () {
      expect(shade(0), isNot(shade(1)));
      // Soil, not pale green: no work is not a little work.
      expect(shade(0), Color.lerp(paper, colors.soil, 0.22));
    });

    test('more sessions is greener', () {
      final ramp = [for (var n = 0; n <= 4; n++) _towardsGreen(shade(n))];

      expect(ramp, orderedEquals(ramp.toList()..sort()));
      expect(ramp.toSet(), hasLength(5), reason: 'five distinguishable steps');
    });

    test('busiest day is full green', () {
      // Relative to the month's busiest day.
      expect(shade(2, busiest: 2), shade(12, busiest: 12));
      expect(shade(1, busiest: 2), shade(6, busiest: 12));
    });

    test('empty month is all soil, no divide by zero', () {
      expect(shade(0, busiest: 0), shade(0, busiest: 5));
    });
  });

  group('the paper', () {
    test('fibre count grows with page size, capped', () {
      expect(PaperPainter.fibresIn(const Size(400, 800)), greaterThan(0));
      expect(
        PaperPainter.fibresIn(const Size(400, 800)),
        lessThan(PaperPainter.fibresIn(const Size(800, 1200))),
      );
      // Fibre count is capped, so big pages cost the same.
      expect(
        PaperPainter.fibresIn(const Size(4000, 4000)),
        PaperPainter.maximumFibres,
      );
    });

    test('repaints only on theme change', () {
      const light = PaperPainter(fibre: Color(0xFF6B7B6B), wash: Color(0xFF8B6F47));
      const same = PaperPainter(fibre: Color(0xFF6B7B6B), wash: Color(0xFF8B6F47));
      const dark = PaperPainter(fibre: Color(0xFFA3B3A0), wash: Color(0xFF8B6F47));

      expect(light.shouldRepaint(same), isFalse);
      expect(light.shouldRepaint(dark), isTrue);
    });
  });
}

double _towardsGreen(Color colour) => colour.g - (colour.r + colour.b) / 2;
