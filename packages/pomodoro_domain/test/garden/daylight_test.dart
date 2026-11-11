import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  // Spring: sunrise 06:30, sunset 19:00.
  Daylight at(int hour, [int minute = 0, Season season = Season.spring]) =>
      Daylight.at(DateTime(2026, 4, 12, hour, minute), season: season);

  group('light', () {
    test('noon and midnight', () {
      expect(at(12).light, 1);
      expect(at(0).light, 0);
    });

    test('is half at sunrise and sunset', () {
      expect(at(6, 30).light, closeTo(0.5, 0.001));
      expect(at(19).light, closeTo(0.5, 0.001));
    });

    test('twilight starts and ends 45 minutes either side of sunrise', () {
      expect(at(5, 45).light, 0);
      expect(at(7, 15).light, 1);
    });

    test('rises all morning and falls all afternoon', () {
      var last = at(0).light;
      for (var m = 1; m <= 12 * 60; m++) {
        final light = at(m ~/ 60, m % 60).light;
        expect(light, greaterThanOrEqualTo(last));
        last = light;
      }
      for (var m = 12 * 60 + 1; m < 24 * 60; m++) {
        final light = at(m ~/ 60, m % 60).light;
        expect(light, lessThanOrEqualTo(last));
        last = light;
      }
    });

    test('depends on the season', () {
      expect(at(20, 0, Season.summer).light, 1);
      expect(at(20, 0, Season.winter).light, 0);
    });
  });

  test('every season has some full day and some full night', () {
    for (final season in Season.values) {
      final day = Daylight.sunsetIn(season) - Daylight.sunriseIn(season);
      expect(day, greaterThan(Daylight.twilight), reason: season.name);
      expect(
        const Duration(hours: 24) - day,
        greaterThan(Daylight.twilight),
        reason: season.name,
      );
      expect(at(12, 0, season).sunUp, isTrue, reason: season.name);
      expect(at(0, 0, season).sunUp, isFalse, reason: season.name);
    }
  });

  test('warmth peaks at sunrise and sunset', () {
    expect(at(6, 30).warmth, 1);
    expect(at(19).warmth, 1);
    expect(at(12).warmth, 0);
    expect(at(0).warmth, 0);
  });

  group('arc', () {
    test('sun', () {
      expect(at(6, 30).sunUp, isTrue);
      expect(at(6, 30).arc, 0);
      expect(at(12, 45).arc, closeTo(0.5, 0.001));
      expect(at(18, 59).arc, closeTo(1, 0.01));
    });

    test('moon, including across midnight', () {
      expect(at(19).sunUp, isFalse);
      expect(at(19).arc, 0);
      // The night runs 19:00 to 06:30, so 00:45 is the middle.
      expect(at(0, 45).arc, closeTo(0.5, 0.001));
      expect(at(23, 59).arc, lessThan(at(0, 1).arc));
      expect(at(6, 29).arc, closeTo(1, 0.01));
    });
  });

  test('atTimeOfDay wraps past 24h', () {
    expect(
      Daylight.atTimeOfDay(const Duration(hours: 25), season: Season.spring),
      at(1),
    );
  });

  test('ignores the date and the seconds', () {
    expect(
      Daylight.at(DateTime(2026, 4, 12, 9, 15, 42), season: Season.spring),
      Daylight.at(DateTime(2031, 1, 1, 9, 15), season: Season.spring),
    );
  });
}
