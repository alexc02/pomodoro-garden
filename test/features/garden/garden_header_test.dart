import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/design/palette.dart';
import 'package:pomodoro_garden/src/features/garden/garden_backdrop.dart';
import 'package:pomodoro_garden/src/features/garden/garden_header.dart';

import '../../support/app_harness.dart';
import '../../support/garden_seed.dart';

void main() {
  group('the headline', () {
    test('counts the garden in words', () {
      expect(GardenHeader.headline(1), 'A garden of one.');
      expect(GardenHeader.headline(12), 'A garden of twelve.');
      expect(GardenHeader.headline(31), 'A garden of thirty-one.');
      expect(GardenHeader.headline(40), 'A garden of forty.');
      expect(GardenHeader.headline(99), 'A garden of ninety-nine.');
    });

    test('in figures from a hundred', () {
      expect(GardenHeader.headline(142), 'A garden of 142.');
    });

    test('says nothing is growing yet, without making it a failing', () {
      expect(GardenHeader.headline(0), 'Bare soil, for now.');
    });
  });

  test('the date line is the weekday, the day and the month', () {
    expect(
      GardenHeader.dateLine(const CalendarDay(2026, 8, 11)),
      'Tuesday, 11 August',
    );
    expect(
      GardenHeader.dateLine(const CalendarDay(2026, 3, 1)),
      'Sunday, 1 March',
    );
  });

  testWidgets('the garden screen is headed by its size, not its name',
      (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await seedGarden(database, sessions: 3);

    await pumpApp(tester, database: database);

    expect(find.text('A garden of three.'), findsOneWidget);
    expect(find.text('Tuesday, 11 August'), findsOneWidget);
  });

  group('the backdrop', () {
    const day = GardenBackdropPainter(
      sky: Palette.skyDay,
      foliage: Palette.primary,
      sun: Palette.skyGoldenHour,
      night: false,
    );
    const night = GardenBackdropPainter(
      sky: Palette.skyDay,
      foliage: Palette.primary,
      sun: Palette.skyGoldenHour,
      night: true,
    );

    test('is the season sky by day', () {
      expect(day.paintedSky, Palette.skyDay);
    });

    test('goes dark at night rather than keeping a daytime sky', () {
      expect(
        night.paintedSky.computeLuminance(),
        lessThan(Palette.skyDay.computeLuminance() / 4),
      );
    });

    test('sets the far hill back against the sky', () {
      // Distance fades a hill toward the sky, so the far one is the closer of
      // the two to the sky's colour.
      double distance(Color a, Color b) =>
          (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
      expect(
        distance(day.farHill, Palette.skyDay),
        lessThan(distance(day.nearHill, Palette.skyDay)),
      );
    });

    testWidgets('follows the app into dark mode', (tester) async {
      useDarkMode(tester);
      await pumpApp(tester);

      final painter = tester
          .widgetList<CustomPaint>(find.descendant(
            of: find.byType(GardenBackdrop),
            matching: find.byType(CustomPaint),
          ))
          .map((paint) => paint.painter)
          .whereType<GardenBackdropPainter>()
          .single;
      expect(painter.night, isTrue);
    });
  });
}
