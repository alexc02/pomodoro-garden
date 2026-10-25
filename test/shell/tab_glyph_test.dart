import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';
import 'package:pomodoro_garden/src/shell/tab_glyph.dart';
import 'package:pomodoro_garden/src/shell/torn_edge.dart';

void main() {
  group('the tab glyphs', () {
    test('each tab has a drawing of its own, inside the grid', () {
      const grid =
          Rect.fromLTWH(0, 0, TabGlyphPainter.grid, TabGlyphPainter.grid);
      final bounds = [
        for (final tab in AppTab.values)
          TabGlyphPainter.pathFor(tab).getBounds(),
      ];

      expect(bounds.toSet(), hasLength(AppTab.values.length));
      for (final drawn in bounds) {
        expect(grid.inflate(0.01).contains(drawn.topLeft), isTrue);
        expect(grid.inflate(0.01).contains(drawn.bottomRight), isTrue);
      }
    });

    test('selection is a heavier line', () {
      expect(TabGlyph.selectedStroke, greaterThan(TabGlyph.stroke));
    });

    testWidgets('size and colour come from the icon theme, like an Icon',
        (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: IconTheme(
            data: IconThemeData(size: 30, color: Color(0xFF123456)),
            child: TabGlyph(AppTab.journal),
          ),
        ),
      ));

      expect(tester.getSize(find.byType(TabGlyph)), const Size(30, 30));
      final painter = tester
          .widget<CustomPaint>(find.descendant(
            of: find.byType(TabGlyph),
            matching: find.byType(CustomPaint),
          ))
          .painter! as TabGlyphPainter;
      expect(painter.color, const Color(0xFF123456));
      expect(painter.stroke, TabGlyph.stroke);
    });
  });

  group('the torn edge', () {
    test('runs the whole width, however wide', () {
      for (final width in [320.0, 390.0, 1024.0]) {
        final tear = TornEdgePainter.tear(Size(width, TornEdge.height));
        expect(tear.getBounds().right, greaterThanOrEqualTo(width));
        expect(tear.getBounds().top, greaterThanOrEqualTo(0));
      }
    });

    test('is ragged rather than a straight cut', () {
      final tear = TornEdgePainter.tear(const Size(390, TornEdge.height));
      // Somewhere along the top it is all the way up, and somewhere it dips:
      // a straight edge would be filled at every point along one line.
      final tops = [
        for (var x = 1.0; x < 390; x += 3)
          [
            for (var y = 0.0; y < TornEdge.height; y += 0.5)
              if (tear.contains(Offset(x, y))) y,
          ].first,
      ];
      tops.sort();
      expect(tops.last - tops.first, greaterThan(4));
    });
  });
}
