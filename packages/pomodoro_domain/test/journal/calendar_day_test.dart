import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('the day an instant falls on', () {
    test('is the local day, not the UTC one', () {
      // The instant is the same one twice; the fields differ. Whichever way
      // round the machine running this is, the answer is the local calendar's.
      final instant = DateTime.utc(2026, 8, 11, 23, 30);
      final local = instant.toLocal();

      expect(
        CalendarDay.of(instant),
        CalendarDay(local.year, local.month, local.day),
      );
    });

    test('is the same day whether it is asked as UTC or as local', () {
      final instant = DateTime.utc(2026, 8, 11, 9, 41);

      expect(CalendarDay.of(instant), CalendarDay.of(instant.toLocal()));
    });

    test('starts at midnight and ends a moment before the next one', () {
      const day = CalendarDay(2026, 8, 11);

      expect(day.startsAt, DateTime(2026, 8, 11));
      expect(CalendarDay.of(day.startsAt), day);
      expect(
        CalendarDay.of(day.tomorrow.startsAt.subtract(
          const Duration(milliseconds: 1),
        )),
        day,
      );
    });
  });

  group('walking the calendar', () {
    test('crosses the end of a month', () {
      expect(const CalendarDay(2026, 8, 31).tomorrow, const CalendarDay(2026, 9, 1));
      expect(const CalendarDay(2026, 9, 1).yesterday, const CalendarDay(2026, 8, 31));
    });

    test('crosses the end of a year', () {
      expect(
        const CalendarDay(2026, 12, 31).tomorrow,
        const CalendarDay(2027, 1, 1),
      );
    });

    test('knows a leap year from a common one', () {
      expect(const CalendarDay(2028, 2, 28).tomorrow, const CalendarDay(2028, 2, 29));
      expect(const CalendarDay(2026, 2, 28).tomorrow, const CalendarDay(2026, 3, 1));
    });

    test('counts whole days between two dates, in either direction', () {
      const day = CalendarDay(2026, 8, 11);

      expect(day.daysUntil(day), 0);
      expect(day.daysUntil(const CalendarDay(2026, 8, 12)), 1);
      expect(day.daysUntil(const CalendarDay(2026, 9, 11)), 31);
      expect(day.daysUntil(const CalendarDay(2026, 8, 10)), -1);
    });

    test('counts days across a daylight-saving change as whole days', () {
      // Two dates a European clock change sits between. A count made by
      // dividing an elapsed duration would come out at 30.958… days and round
      // to 30; the calendar says 31 whichever way the clocks went.
      expect(
        const CalendarDay(2026, 3, 15).daysUntil(const CalendarDay(2026, 4, 15)),
        31,
      );
      expect(
        const CalendarDay(2026, 10, 15).daysUntil(const CalendarDay(2026, 11, 15)),
        31,
      );
    });

    test('adds and subtracts a run of days', () {
      expect(const CalendarDay(2026, 8, 11).plus(7), const CalendarDay(2026, 8, 18));
      expect(const CalendarDay(2026, 8, 11).plus(-11), const CalendarDay(2026, 7, 31));
      expect(const CalendarDay(2026, 8, 11).plus(0), const CalendarDay(2026, 8, 11));
    });

    test('names the weekday the way DateTime does', () {
      // 11 August 2026 is a Tuesday.
      expect(const CalendarDay(2026, 8, 11).weekday, DateTime.tuesday);
      expect(const CalendarDay(2026, 8, 16).weekday, DateTime.sunday);
    });
  });

  group('a day as a value', () {
    test('two days with the same date are the same day', () {
      expect(const CalendarDay(2026, 8, 11), const CalendarDay(2026, 8, 11));
      expect(
        const CalendarDay(2026, 8, 11).hashCode,
        const CalendarDay(2026, 8, 11).hashCode,
      );
      // Two days read off two different rows, holding the same date.
      final read = [const CalendarDay(2026, 8, 11), CalendarDay(2026, 8, 10 + 1)];
      expect(read.toSet(), hasLength(1));
    });

    test('sorts chronologically', () {
      final days = [
        const CalendarDay(2026, 8, 11),
        const CalendarDay(2025, 12, 31),
        const CalendarDay(2026, 7, 12),
      ]..sort();

      expect(days, [
        const CalendarDay(2025, 12, 31),
        const CalendarDay(2026, 7, 12),
        const CalendarDay(2026, 8, 11),
      ]);
      expect(
        const CalendarDay(2026, 7, 12).isBefore(const CalendarDay(2026, 8, 11)),
        isTrue,
      );
      expect(
        const CalendarDay(2026, 8, 11).isAfter(const CalendarDay(2026, 7, 12)),
        isTrue,
      );
    });

    test('reads and writes the ISO date SQLite groups by', () {
      expect(const CalendarDay(2026, 8, 11).toString(), '2026-08-11');
      expect(const CalendarDay(2026, 12, 9).toString(), '2026-12-09');
      expect(CalendarDay.parse('2026-08-11'), const CalendarDay(2026, 8, 11));
      expect(
        CalendarDay.parse(const CalendarDay(897, 1, 2).toString()),
        const CalendarDay(897, 1, 2),
      );
    });

    test('refuses a string that is not a date', () {
      expect(() => CalendarDay.parse('yesterday'), throwsFormatException);
      expect(() => CalendarDay.parse('2026-08'), throwsFormatException);
    });
  });

  group('firstOfMonth', () {
    test('is the first of the same month by default', () {
      expect(
        const CalendarDay(2026, 8, 11).firstOfMonth(),
        const CalendarDay(2026, 8, 1),
      );
    });

    test('steps back across a year, December from January', () {
      expect(
        const CalendarDay(2026, 1, 31).firstOfMonth(monthsLater: -1),
        const CalendarDay(2025, 12, 1),
      );
    });

    test('steps forward across a year, and over a short month', () {
      expect(
        const CalendarDay(2025, 12, 31).firstOfMonth(monthsLater: 1),
        const CalendarDay(2026, 1, 1),
      );
      // Adding a month to the 31st of January would overflow into March if the
      // day were kept. Answering the first of the month is what prevents it.
      expect(
        const CalendarDay(2026, 1, 31).firstOfMonth(monthsLater: 1),
        const CalendarDay(2026, 2, 1),
      );
    });

    test('goes back many months at once', () {
      expect(
        const CalendarDay(2026, 8, 11).firstOfMonth(monthsLater: -20),
        const CalendarDay(2024, 12, 1),
      );
    });
  });
}
