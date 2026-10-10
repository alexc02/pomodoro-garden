import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('the season a date falls in', () {
    test('is the meteorological one, north of the equator', () {
      // The three months REQ-019 names for each, and the ticket's own three
      // examples: April is blossom, November is falling leaves, January is
      // snow.
      const northern = Hemisphere.northern;

      for (final month in [3, 4, 5]) {
        expect(Season.on(_first(month), hemisphere: northern), Season.spring);
      }
      for (final month in [6, 7, 8]) {
        expect(Season.on(_first(month), hemisphere: northern), Season.summer);
      }
      for (final month in [9, 10, 11]) {
        expect(Season.on(_first(month), hemisphere: northern), Season.autumn);
      }
      for (final month in [12, 1, 2]) {
        expect(Season.on(_first(month), hemisphere: northern), Season.winter);
      }
    });

    test('is the opposite one, south of it', () {
      const southern = Hemisphere.southern;

      expect(Season.on(_first(1), hemisphere: southern), Season.summer);
      expect(Season.on(_first(4), hemisphere: southern), Season.autumn);
      expect(Season.on(_first(7), hemisphere: southern), Season.winter);
      expect(Season.on(_first(11), hemisphere: southern), Season.spring);
    });

    test('turns at the first instant of the month, not at noon', () {
      expect(
        Season.on(DateTime(2026, 2, 28, 23, 59, 59)),
        Season.winter,
      );
      expect(Season.on(DateTime(2026, 3)), Season.spring);
    });

    test('reads the same date the same way every year', () {
      for (var year = 1970; year < 2100; year += 7) {
        expect(Season.on(DateTime(year, 11, 15)), Season.autumn);
      }
    });
  });

  group('the next boundary after a date', () {
    test('is the first of the next season-start month', () {
      expect(Season.boundaryAfter(DateTime(2026, 1, 20)), DateTime(2026, 3));
      expect(Season.boundaryAfter(DateTime(2026, 3)), DateTime(2026, 6));
      expect(Season.boundaryAfter(DateTime(2026, 7, 4, 12)), DateTime(2026, 9));
      expect(Season.boundaryAfter(DateTime(2026, 9, 30)), DateTime(2026, 12));
    });

    test('crosses into the next year from December', () {
      expect(
        Season.boundaryAfter(DateTime(2026, 12, 25, 18, 30)),
        DateTime(2027, 3),
      );
    });

    test('is strictly after the instant it is asked about', () {
      // Asked *on* a boundary, the answer is the next one. Otherwise a timer
      // aimed at it would fire immediately and forever.
      final boundary = DateTime(2026, 6);
      expect(Season.boundaryAfter(boundary).isAfter(boundary), isTrue);
    });

    test('turns the season in both hemispheres at once', () {
      // Southern seasons are the northern ones relabelled, not shifted, so one
      // boundary serves both halves of the world — which is why
      // [Season.boundaryAfter] takes no hemisphere to be told.
      final before = DateTime(2026, 1, 20);
      final boundary = Season.boundaryAfter(before);

      for (final hemisphere in Hemisphere.values) {
        expect(
          Season.on(boundary, hemisphere: hemisphere),
          isNot(Season.on(before, hemisphere: hemisphere)),
        );
      }
    });

    test('always names an instant the season has actually changed at', () {
      var date = DateTime(2026, 1, 1);
      for (var turn = 0; turn < 12; turn++) {
        final boundary = Season.boundaryAfter(date);
        expect(
          Season.on(boundary),
          isNot(Season.on(date)),
          reason: 'the season at $boundary should differ from the one at $date',
        );
        date = boundary;
      }
    });
  });

  group('the hemisphere a time zone is in', () {
    test('is southern when the clocks go forward for the southern summer', () {
      // Sydney: UTC+11 in January, UTC+10 in July.
      expect(
        Hemisphere.fromDaylightSaving(
          january: const Duration(hours: 11),
          july: const Duration(hours: 10),
        ),
        Hemisphere.southern,
      );
    });

    test('is northern when they go forward for the northern one', () {
      // London: UTC+0 in January, UTC+1 in July.
      expect(
        Hemisphere.fromDaylightSaving(
          january: Duration.zero,
          july: const Duration(hours: 1),
        ),
        Hemisphere.northern,
      );
    });

    test('is northern when the zone keeps one offset all year', () {
      // Most of the world does not observe daylight saving, so this is the
      // common case and the fallback the whole scheme rests on. See
      // docs/adr/0011-the-season-is-derived-from-the-device-date.md.
      expect(
        Hemisphere.fromDaylightSaving(
          january: const Duration(hours: 8),
          july: const Duration(hours: 8),
        ),
        Hemisphere.northern,
      );
    });
  });

  test('every season has a name to force it by', () {
    // The debug affordance lists these, and it is the only thing that does:
    // nothing records the season a plant was grown in, so there is nowhere
    // else a season is ever spelled out.
    for (final season in Season.values) {
      expect(season.label, isNotEmpty);
    }
  });
}

/// The first instant of [month], in an arbitrary year.
DateTime _first(int month) => DateTime(2026, month);
