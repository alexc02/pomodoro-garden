import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

/// The day every case below is read on.
const _today = CalendarDay(2026, 8, 11);

/// [_today] and the [days] before it, most recent first.
List<CalendarDay> _runEndingToday(int days) =>
    [for (var back = 0; back < days; back++) _today.plus(-back)];

void main() {
  group('a streak', () {
    test('is the run of days ending today', () {
      final streak = Streak.from(
        activeDays: _runEndingToday(4),
        today: _today,
      );

      expect(streak.days, 4);
      expect(streak.isGrowing, isTrue);
      expect(streak.restedDays, 0);
      expect(streak.isResting, isFalse);
    });

    test('stands on a day the user has not finished a session in yet', () {
      // Yesterday and the two before it, and nothing today. Today is not over,
      // so it is not a day that was missed — REQ-029 counts days with a
      // session, and this one is still being lived.
      final streak = Streak.from(
        activeDays: _runEndingToday(4).skip(1).toList(),
        today: _today,
      );

      expect(streak.days, 3);
      expect(streak.isGrowing, isTrue);
      expect(streak.restedDays, 1);
      expect(streak.isResting, isFalse);
    });

    test('stops at the first day with nothing in it', () {
      final streak = Streak.from(
        activeDays: [
          ..._runEndingToday(3),
          // A gap, and then a longer run that is not part of this streak.
          _today.plus(-4),
          _today.plus(-5),
          _today.plus(-6),
          _today.plus(-7),
        ],
        today: _today,
      );

      expect(streak.days, 3);
    });

    test('counts a day once, however many sessions were finished in it', () {
      final streak = Streak.from(
        activeDays: [_today, _today, _today, _today.yesterday],
        today: _today,
      );

      expect(streak.days, 2);
    });

    test('does not care what order the days arrive in', () {
      final streak = Streak.from(
        activeDays: _runEndingToday(5).reversed.toList(),
        today: _today,
      );

      expect(streak.days, 5);
    });

    test('ignores a day in the future, which nothing should ever produce', () {
      final streak = Streak.from(
        activeDays: [_today.tomorrow, ..._runEndingToday(2)],
        today: _today,
      );

      expect(streak.days, 2);
      expect(streak.restedDays, 0);
    });
  });

  group('a garden that has rested', () {
    test('counts the days since the last session, and has no streak', () {
      final streak = Streak.from(
        activeDays: [_today.plus(-2), _today.plus(-3)],
        today: _today,
      );

      expect(streak.days, 0);
      expect(streak.isGrowing, isFalse);
      // REQ-029's own example: "your garden rested for 2 days".
      expect(streak.restedDays, 2);
      expect(streak.isResting, isTrue);
    });

    test('counts a long rest without complaining about it', () {
      final streak = Streak.from(
        activeDays: [_today.plus(-400)],
        today: _today,
      );

      expect(streak.days, 0);
      expect(streak.restedDays, 400);
      expect(streak.isResting, isTrue);
    });
  });

  group('a garden with nothing in it yet', () {
    test('is neither growing nor resting', () {
      final streak = Streak.from(activeDays: const [], today: _today);

      expect(streak.days, 0);
      expect(streak.restedDays, 0);
      expect(streak.isGrowing, isFalse);
      // Nothing to have rested from. A brand-new user has not lapsed.
      expect(streak.isResting, isFalse);
      expect(streak.hasEverGrown, isFalse);
    });

    test('is what an empty streak is', () {
      expect(Streak.from(activeDays: const [], today: _today), Streak.none);
    });
  });
}
