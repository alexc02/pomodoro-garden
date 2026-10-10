import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_garden/src/design/garden_colors.dart';
import 'package:pomodoro_garden/src/features/journal/journal_heatmap.dart';
import 'package:pomodoro_garden/src/features/journal/journal_paper.dart';
import 'package:pomodoro_garden/src/features/journal/journal_screen.dart';

/// The two decisions the journal makes that are neither a query nor a layout:
/// how long a stretch of focus is written, and how green a day is drawn.
void main() {
  group('a stretch of focus, as a journal writes it', () {
    test('is hours and minutes, and never smaller', () {
      expect(focusLabel(const Duration(minutes: 45)), '45m');
      expect(focusLabel(const Duration(hours: 5, minutes: 20)), '5h 20m');
      expect(focusLabel(const Duration(hours: 143)), '143h');
      expect(focusLabel(const Duration(hours: 1, minutes: 1)), '1h 1m');
    });

    test('rounds nothing up, and says nothing about seconds', () {
      // A session is minutes long by construction, but a sum of them is not
      // the only thing that reaches here — a lifetime of them is.
      expect(focusLabel(const Duration(minutes: 59, seconds: 59)), '59m');
      expect(focusLabel(Duration.zero), '0m');
    });
  });

  group('how green a day is drawn', () {
    const colors = GardenColors.light;
    const paper = Color(0xFFF7F5EF);

    Color shade(int sessions, {int busiest = 4}) => heatmapShade(
          sessions: sessions,
          busiestDay: busiest,
          colors: colors,
          paper: paper,
        );

    test('a day with nothing in it is bare soil', () {
      expect(shade(0), isNot(shade(1)));
      // Soil rather than a paler green: REQ-027's empty day is ground, not a
      // small amount of work.
      expect(shade(0), Color.lerp(paper, colors.soil, 0.22));
    });

    test('more sessions is further towards the foliage green', () {
      final ramp = [for (var n = 0; n <= 4; n++) _towardsGreen(shade(n))];

      expect(ramp, orderedEquals(ramp.toList()..sort()));
      expect(ramp.toSet(), hasLength(5), reason: 'five distinguishable steps');
    });

    test('the busiest day of the month is the full green, whatever it was', () {
      // A month whose best day was two is drawn as fully as one whose best day
      // was twelve. Nobody is being ranked against anybody.
      expect(shade(2, busiest: 2), shade(12, busiest: 12));
      expect(shade(1, busiest: 2), shade(6, busiest: 12));
    });

    test('a month with nothing in it is all soil, and divides by nothing', () {
      expect(shade(0, busiest: 0), shade(0, busiest: 5));
    });
  });

  group('the paper', () {
    test('has a fibre count that grows with the page and then stops', () {
      expect(PaperPainter.fibresIn(const Size(400, 800)), greaterThan(0));
      expect(
        PaperPainter.fibresIn(const Size(400, 800)),
        lessThan(PaperPainter.fibresIn(const Size(800, 1200))),
      );
      // A tablet-sized page costs no more to draw than a phone-sized one past
      // the cap: the texture is a fixed budget, not one that scales with the
      // window.
      expect(
        PaperPainter.fibresIn(const Size(4000, 4000)),
        PaperPainter.maximumFibres,
      );
    });

    test('repaints when the theme changes and not otherwise', () {
      const light = PaperPainter(fibre: Color(0xFF6B7B6B), wash: Color(0xFF8B6F47));
      const same = PaperPainter(fibre: Color(0xFF6B7B6B), wash: Color(0xFF8B6F47));
      const dark = PaperPainter(fibre: Color(0xFFA3B3A0), wash: Color(0xFF8B6F47));

      expect(light.shouldRepaint(same), isFalse);
      expect(light.shouldRepaint(dark), isTrue);
    });
  });
}

/// How far a shade has travelled from the page towards green, as one number.
double _towardsGreen(Color colour) => colour.g - (colour.r + colour.b) / 2;
