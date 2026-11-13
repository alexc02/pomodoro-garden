import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/design/garden_colors.dart';
import 'package:pip_garden/src/design/palette.dart';
import 'package:pip_garden/src/features/garden/garden_backdrop.dart';
import 'package:pip_garden/src/features/garden/garden_header.dart';
import 'package:pip_garden/src/features/garden/garden_view.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';

const Size _window = Size(400, 800);

FixedClock _clockAt(DateTime local) => FixedClock(local.toUtc());

// Spring: sunrise 06:30, sunset 19:00.
DateTime _spring(int hour) => DateTime(2026, 4, 12, hour);

GardenBackdropPainter _painter(Duration time) => GardenBackdropPainter(
      sky: Palette.skyDay,
      foliage: Palette.primary,
      sun: Palette.skyGoldenHour,
      daylight: Daylight.atTimeOfDay(time, season: Season.spring),
    );

GardenBackdropPainter _backdrop(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.descendant(
      of: find.byType(GardenBackdrop),
      matching: find.byType(CustomPaint),
    ))
    .map((paint) => paint.painter)
    .whereType<GardenBackdropPainter>()
    .single;

Color _headerColour(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(
      of: find.byType(GardenHeader),
      matching: find.byType(Text),
    ))
    .last
    .style!
    .color!;

double _distance(Color a, Color b) =>
    (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();

Future<void> _pinTime(WidgetTester tester, String chip) async {
  await tapTab(tester, AppTab.settings);
  await scrollToSetting(tester, SettingsKeys.timeOfDay);
  await tester.tap(find.descendant(
    of: find.byKey(SettingsKeys.timeOfDay),
    matching: find.text(chip),
  ));
  await settle(tester);
  await tapTab(tester, AppTab.garden);
}

void main() {
  group('backdrop painter', () {
    final noon = _painter(const Duration(hours: 12));
    final midnight = _painter(Duration.zero);
    final sunset = _painter(const Duration(hours: 19));

    test('noon is the plain season sky', () {
      expect(noon.paintedSky, Palette.skyDay);
      expect(noon.horizonSky, Palette.skyDay);
      expect(noon.starlight, 0);
    });

    test('midnight is dark with stars and a moon', () {
      expect(
        midnight.paintedSky.computeLuminance(),
        lessThan(Palette.skyDay.computeLuminance() / 4),
      );
      expect(midnight.starlight, 1);
      expect(midnight.discColour, isNot(noon.discColour));
      expect(
        midnight.nearHill.computeLuminance(),
        lessThan(noon.nearHill.computeLuminance() / 2),
      );
    });

    test('sunset warms the horizon more than the top', () {
      expect(
        _distance(sunset.horizonSky, Palette.skyGoldenHour),
        lessThan(_distance(sunset.paintedSky, Palette.skyGoldenHour)),
      );
      expect(sunset.starlight, lessThan(0.3));
    });

    test('far hill is closer to the sky colour than the near one', () {
      expect(
        _distance(noon.farHill, Palette.skyDay),
        lessThan(_distance(noon.nearHill, Palette.skyDay)),
      );
    });

    test('sun moves left to right and peaks at midday', () {
      final morning = _painter(const Duration(hours: 8)).discCentre(_window);
      final midday =
          _painter(const Duration(hours: 12, minutes: 45)).discCentre(_window);
      final evening = _painter(const Duration(hours: 18)).discCentre(_window);

      expect(morning.dx, lessThan(midday.dx));
      expect(midday.dx, lessThan(evening.dx));
      expect(midday.dy, lessThan(morning.dy));
      expect(midday.dy, lessThan(evening.dy));
    });

    test('sun is hidden behind the far hill at sunrise and sunset', () {
      // Lowest point of the far hill's crest.
      final crest = _window.height * 0.42;
      final radius = _window.width * 0.1;

      for (final time in [
        Daylight.sunriseIn(Season.spring),
        Daylight.sunsetIn(Season.spring),
      ]) {
        final top = _painter(time).discCentre(_window).dy - radius;
        expect(top, greaterThanOrEqualTo(crest));
      }
    });

    test('the disc never rises into a two-line headline', () {
      // Tallest phone header: safe area, date line, two lines of headline.
      const headerBottom = 205.0;
      const phone = Size(402, 874);
      final radius = phone.width * 0.1;

      for (var minutes = 0; minutes < 24 * 60; minutes += 10) {
        final top =
            _painter(Duration(minutes: minutes)).discCentre(phone).dy - radius;
        expect(top, greaterThan(headerBottom), reason: 'at $minutes min');
      }
    });

    test('shouldRepaint', () {
      expect(
        noon.shouldRepaint(_painter(const Duration(hours: 12))),
        isFalse,
      );
      expect(noon.shouldRepaint(sunset), isTrue);
    });

    testWidgets('paints at any hour', (tester) async {
      for (var hour = 0; hour < 24; hour++) {
        await tester.pumpWidget(CustomPaint(
          size: _window,
          painter: _painter(Duration(hours: hour, minutes: 30)),
        ));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('header text colour', () {
    GardenSky sky(Duration time) => GardenSky(
          day: Palette.skyDay,
          daylight: Daylight.atTimeOfDay(time, season: Season.spring),
        );

    test('dark by day, light at night', () {
      expect(sky(const Duration(hours: 12)).ink, Palette.textPrimary);
      expect(sky(Duration.zero).ink, Palette.textPrimaryDark);
    });

    test('contrast never drops below 3:1', () {
      for (var m = 0; m < 24 * 60; m += 5) {
        final s = sky(Duration(minutes: m));
        final a = s.ink.computeLuminance();
        final b = s.zenith.computeLuminance();
        final contrast = ((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05);

        expect(contrast, greaterThanOrEqualTo(3), reason: 'minute $m');
      }
    });
  });

  group('garden tab', () {
    testWidgets('noon', (tester) async {
      await pumpApp(tester, surface: _window, clock: _clockAt(_spring(12)));

      expect(_backdrop(tester).daylight.light, 1);
      expect(_backdrop(tester).daylight.sunUp, isTrue);
      expect(_headerColour(tester), Palette.textPrimary);
    });

    testWidgets('midnight', (tester) async {
      await pumpApp(tester, surface: _window, clock: _clockAt(_spring(0)));

      expect(_backdrop(tester).daylight.light, 0);
      expect(_backdrop(tester).daylight.sunUp, isFalse);
      expect(_headerColour(tester), Palette.textPrimaryDark);
    });

    testWidgets('dark mode does not change the sky', (tester) async {
      useDarkMode(tester);
      await pumpApp(tester, surface: _window, clock: _clockAt(_spring(12)));

      expect(_backdrop(tester).paintedSky, Palette.springSky);
      expect(_headerColour(tester), Palette.textPrimary);
    });

    testWidgets('summer evening is still light at 20:00', (tester) async {
      await pumpApp(
        tester,
        surface: _window,
        clock: _clockAt(DateTime(2026, 7, 12, 20)),
      );
      expect(_backdrop(tester).daylight.light, 1);
    });

    testWidgets('updates while the app is open', (tester) async {
      final clock = _clockAt(_spring(18));
      await pumpApp(tester, surface: _window, clock: clock);
      expect(_backdrop(tester).daylight.light, 1);

      await advance(tester, clock, const Duration(hours: 3));
      // The provider's timer needs one more tick to pick up the new time.
      await advance(tester, clock, const Duration(minutes: 1));

      expect(_backdrop(tester).daylight.light, 0);
      expect(_headerColour(tester), Palette.textPrimaryDark);
    });

    testWidgets('night only touches the sky', (tester) async {
      await pumpApp(tester, surface: _window, clock: _clockAt(_spring(0)));

      final view = tester.element(find.byType(GardenView));
      final garden = GardenColors.of(view);
      expect(garden.skyDay, Palette.springSky);
      expect(garden.foliage, Palette.springFoliage);
      expect(garden.textPrimary, Palette.textPrimary);
      expect(Theme.of(view).brightness, Brightness.light);
    });
  });

  testWidgets('debug time of day', (tester) async {
    await pumpApp(tester, surface: _window, clock: _clockAt(_spring(12)));

    await _pinTime(tester, 'Midnight');
    expect(_backdrop(tester).daylight.light, 0);

    await _pinTime(tester, 'Follow the clock');
    expect(_backdrop(tester).daylight.light, 1);
  });
}
