import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/features/garden/garden_header.dart';

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

    test('empty garden copy', () {
      expect(GardenHeader.headline(0), 'Bare soil, for now.');
    });
  });

  test('date line is weekday, day and month', () {
    expect(
      GardenHeader.dateLine(const CalendarDay(2026, 8, 11)),
      'Tuesday, 11 August',
    );
    expect(
      GardenHeader.dateLine(const CalendarDay(2026, 3, 1)),
      'Sunday, 1 March',
    );
  });

  testWidgets('garden screen header shows plant count', (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await seedGarden(database, sessions: 3);

    await pumpApp(tester, database: database);

    expect(find.text('A garden of three.'), findsOneWidget);
    expect(find.text('Tuesday, 11 August'), findsOneWidget);
  });

}
