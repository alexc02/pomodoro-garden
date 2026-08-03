import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('the week a day is in', () {
    // 11 August 2026 is a Tuesday.
    const tuesday = CalendarDay(2026, 8, 11);

    test('starts on the locale\'s first day of the week', () {
      expect(
        DayRange.week(tuesday, firstDayOfWeek: DateTime.monday).first,
        const CalendarDay(2026, 8, 10),
      );
      expect(
        DayRange.week(tuesday, firstDayOfWeek: DateTime.sunday).first,
        const CalendarDay(2026, 8, 9),
      );
      expect(
        DayRange.week(tuesday, firstDayOfWeek: DateTime.saturday).first,
        const CalendarDay(2026, 8, 8),
      );
    });

    test('is always seven days long, wherever it starts', () {
      for (var firstDay = DateTime.monday;
          firstDay <= DateTime.sunday;
          firstDay++) {
        final week = DayRange.week(tuesday, firstDayOfWeek: firstDay);

        expect(week.days, 7);
        expect(week.eachDay, hasLength(7));
        expect(week.first.daysUntil(week.last), 6);
        expect(week.contains(tuesday), isTrue);
      }
    });

    test('starts on the day itself when the week starts on it', () {
      expect(
        DayRange.week(tuesday, firstDayOfWeek: DateTime.tuesday).first,
        tuesday,
      );
    });

    test('runs back into the month before when the week straddles one', () {
      // 1 September 2026 is a Tuesday; a Monday week reaches back into August.
      final week = DayRange.week(
        const CalendarDay(2026, 9, 1),
        firstDayOfWeek: DateTime.monday,
      );

      expect(week.first, const CalendarDay(2026, 8, 31));
      expect(week.last, const CalendarDay(2026, 9, 6));
    });
  });

  group('the month a day is in', () {
    test('runs from the first to the last, whatever length the month is', () {
      expect(
        DayRange.month(const CalendarDay(2026, 8, 11)),
        _spans(const CalendarDay(2026, 8, 1), const CalendarDay(2026, 8, 31)),
      );
      expect(
        DayRange.month(const CalendarDay(2026, 2, 11)),
        _spans(const CalendarDay(2026, 2, 1), const CalendarDay(2026, 2, 28)),
      );
      expect(
        DayRange.month(const CalendarDay(2028, 2, 11)),
        _spans(const CalendarDay(2028, 2, 1), const CalendarDay(2028, 2, 29)),
      );
      expect(
        DayRange.month(const CalendarDay(2026, 12, 25)),
        _spans(const CalendarDay(2026, 12, 1), const CalendarDay(2026, 12, 31)),
      );
    });

    test('lists every day in it, in order', () {
      final august = DayRange.month(const CalendarDay(2026, 8, 11));

      expect(august.days, 31);
      expect(august.eachDay.first, const CalendarDay(2026, 8, 1));
      expect(august.eachDay.last, const CalendarDay(2026, 8, 31));
      expect(august.eachDay, august.eachDay.toList()..sort());
    });
  });

  group('the instants a range covers', () {
    test('run from local midnight to local midnight, half open', () {
      final week = DayRange.week(
        const CalendarDay(2026, 8, 11),
        firstDayOfWeek: DateTime.monday,
      );

      expect(week.from, DateTime(2026, 8, 10).toUtc());
      // Exclusive, so a session at exactly midnight Monday is in the next week.
      expect(week.until, DateTime(2026, 8, 17).toUtc());
      expect(week.from.isUtc, isTrue);
      expect(week.until.isUtc, isTrue);
    });

    test('are the whole of the days in it, and nothing either side', () {
      final month = DayRange.month(const CalendarDay(2026, 2, 14));

      expect(month.from, DateTime(2026, 2, 1).toUtc());
      expect(month.until, DateTime(2026, 3, 1).toUtc());
    });

    test('holds a day that is in it and refuses one that is not', () {
      final month = DayRange.month(const CalendarDay(2026, 8, 11));

      expect(month.contains(const CalendarDay(2026, 8, 1)), isTrue);
      expect(month.contains(const CalendarDay(2026, 8, 31)), isTrue);
      expect(month.contains(const CalendarDay(2026, 7, 31)), isFalse);
      expect(month.contains(const CalendarDay(2026, 9, 1)), isFalse);
    });
  });
}

Matcher _spans(CalendarDay first, CalendarDay last) => isA<DayRange>()
    .having((range) => range.first, 'first', first)
    .having((range) => range.last, 'last', last);
