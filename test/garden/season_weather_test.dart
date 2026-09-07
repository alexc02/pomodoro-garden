import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/design/season_palette.dart';
import 'package:pip_garden/src/design/theme_palette.dart';
import 'package:pip_garden/src/features/garden/garden_view.dart';
import 'package:pip_garden/src/features/garden/seasonal_garden.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/garden/season_weather.dart';
import 'package:pip_garden/src/garden/season_providers.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/garden_seed.dart';

// Weather must not hide the garden or cost the 200-plant garden its frame
// rate. Both come down to a capped count and an alpha (see [SeasonWeather]).

const Size _phone = Size(400, 800);

/// Big landscape window, where a per-area density would run away.
const Size _desk = Size(2560, 1440);

/// Every season with weather, in every theme.
Iterable<Weather> get _weathers => GardenTheme.values.expand(
      (theme) => Season.values
          .map((season) => ThemePalette.of(theme).inSeason(season).weather)
          .nonNulls,
    );

void main() {
  test('each season has its own palette in every theme', () {
    // Twelve near-identical entries is easy to copy-paste wrong.
    for (final theme in GardenTheme.values) {
      for (final season in Season.values) {
        expect(
          ThemePalette.of(theme).inSeason(season).season,
          season,
          reason: '${theme.name} has the wrong palette filed under '
              '${season.name}',
        );
      }
    }
  });

  test('three weathers per theme', () {
    // Blossom, leaves, snow. Themes reskin what falls but don't add to it.
    expect(_weathers, hasLength(3 * GardenTheme.values.length));
    for (final theme in GardenTheme.values) {
      expect(
        ThemePalette.of(theme).summer.weather,
        isNull,
        reason: 'something is falling in ${theme.name} summer',
      );
    }
  });

  group('particle count', () {
    test('is reasonable on a phone', () {
      for (final weather in _weathers) {
        final count = SeasonWeather.countIn(_phone, weather);
        expect(count, greaterThan(4), reason: 'enough to read as weather');
        expect(count, lessThan(40), reason: 'not a storm');
      }
    });

    test('is capped on large windows', () {
      for (final weather in _weathers) {
        expect(
          SeasonWeather.countIn(_desk, weather),
          SeasonWeather.maximum,
          reason: 'count must be capped on big windows',
        );
      }
      expect(
        SeasonWeather.countIn(const Size(20000, 20000), _weathers.first),
        SeasonWeather.maximum,
      );
    });

    test('is zero in an empty window', () {
      expect(SeasonWeather.countIn(Size.zero, _weathers.first), 0);
    });
  });

  test('particles are translucent', () {
    for (final weather in _weathers) {
      expect(
        weather.opacity,
        lessThan(0.8),
        reason: 'plant must show through a ${weather.shape.name}',
      );

      // Coverage: particles are discs at most `size` across, and even at the
      // cap they cover a fraction of a percent.
      final covered = SeasonWeather.countIn(_phone, weather) *
          math.pi *
          math.pow(weather.size / 2, 2);
      expect(
        covered / (_phone.width * _phone.height),
        lessThan(0.005),
        reason: 'covers too much of the screen',
      );
    }
  });

  test('particles move slowly', () {
    // The fastest particle still takes a good part of 15s to cross.
    for (final weather in _weathers) {
      expect(weather.crossing, greaterThanOrEqualTo(const Duration(seconds: 15)));
    }
  });

  group('frame cost', () {
    // Timed directly, like garden_performance_test.dart, to avoid the tab's
    // noise. Same method (120 frames after warm-up) and same loose budget.
    //
    // A 60fps frame is 16,700µs and the garden takes ~200µs of it. The overlay
    // should be close to nothing.
    const budget = 700.0;

    double perFrame(WeatherPainter painter) {
      final falling = painter.falling as ValueNotifier<double>;

      void frame(int n) {
        falling.value = n * 0.016;
        final recorder = PictureRecorder();
        painter.paint(Canvas(recorder), _phone);
        recorder.endRecording().dispose();
      }

      for (var warm = 0; warm < 20; warm++) {
        frame(warm);
      }

      final clock = Stopwatch()..start();
      for (var n = 0; n < 120; n++) {
        frame(n);
      }
      clock.stop();

      return clock.elapsedMicroseconds / 120;
    }

    test('is small in each season', () {
      for (final weather in _weathers) {
        final cost = perFrame(WeatherPainter(
          falling: ValueNotifier<double>(0),
          layers: [(weather: weather, alpha: 1)],
        ));

        debugPrint('garden baseline | ${weather.shape.name}: '
            '${(cost / 1000).toStringAsFixed(3)} ms per frame');
        expect(cost, lessThan(budget), reason: 'the ${weather.shape.name} sky');
      }
    });

    test('is small mid-crossfade', () {
      // Mid-crossfade two seasons are up at once, the case a per-season budget
      // would miss.
      final cost = perFrame(WeatherPainter(
        falling: ValueNotifier<double>(0),
        layers: [
          (weather: ThemePalette.zen.winter.weather!, alpha: 0.5),
          (weather: ThemePalette.zen.autumn.weather!, alpha: 0.5),
        ],
      ));

      debugPrint('garden baseline | two seasons crossfading: '
          '${(cost / 1000).toStringAsFixed(3)} ms per frame');
      expect(cost, lessThan(budget * 2));
    });
  });

  testWidgets('full garden drags in the snow', (tester) async {
    // 200 plants, the densest weather, and a drag. Recorded rather than
    // asserted, like garden_performance_test.dart; the count is capped above so
    // it can't grow with the window.
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await seedGarden(database, sessions: GardenPlots.maximum);

    await pumpApp(
      tester,
      database: database,
      surface: _phone,
      clock: FixedClock(DateTime(2026, 1, 12, 10).toUtc()),
      overrides: [hemisphereProvider.overrideWithValue(Hemisphere.northern)],
    );
    await tapTab(tester, AppTab.garden);
    expect(find.byType(SeasonWeather), findsOneWidget);

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(GardenView)));
    await gesture.moveBy(const Offset(-30, -20));
    await tester.pump();

    const frames = 120;
    final clock = Stopwatch()..start();
    for (var frame = 0; frame < frames; frame++) {
      await gesture.moveBy(const Offset(-1, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    clock.stop();
    await gesture.up();
    await tester.pump();

    debugPrint(
      'garden baseline | dragging 200 plants under snow: '
      '${(clock.elapsedMicroseconds / frames / 1000).toStringAsFixed(3)} ms '
      'per frame',
    );
  });

  testWidgets('stops when the garden is hidden', (tester) async {
    // Battery: the overlay runs off a Ticker, so muting the hidden tab stops
    // it.
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await seedGarden(database, sessions: 4);

    await pumpApp(
      tester,
      database: database,
      surface: _phone,
      clock: FixedClock(DateTime(2026, 1, 12, 10).toUtc()),
      overrides: [hemisphereProvider.overrideWithValue(Hemisphere.northern)],
    );
    await tapTab(tester, AppTab.garden);

    expect(_ticking(tester), isTrue);

    await tapTab(tester, AppTab.timer);
    expect(_ticking(tester), isFalse, reason: 'a hidden tab asks for no frames');

    await tapTab(tester, AppTab.garden);
    expect(_ticking(tester), isTrue);
  });

  testWidgets('old season clears when summer arrives', (tester) async {
    // Arriving at summer could leave the overlay animating autumn leaves at
    // zero alpha. SeasonalGarden dropping the old season is what stops it.
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await seedGarden(database, sessions: 4);

    await pumpApp(
      tester,
      database: database,
      surface: _phone,
      clock: FixedClock(DateTime(2026, 11, 12, 10).toUtc()),
      overrides: [hemisphereProvider.overrideWithValue(Hemisphere.northern)],
    );
    await tapTab(tester, AppTab.garden);
    expect(find.byType(SeasonWeather), findsOneWidget);

    await tapTab(tester, AppTab.settings);
    await scrollToSetting(tester, SettingsKeys.season);
    await tester.tap(find.text(Season.summer.label));
    await settle(tester);
    await tapTab(tester, AppTab.garden);
    await settle(tester, over: SeasonalGarden.crossfade);

    final overlay = tester.widget<SeasonWeather>(find.byType(SeasonWeather));
    expect(overlay.transition.from.season, Season.summer);
    expect(overlay.transition.to.season, Season.summer);
    expect(
      find.descendant(
        of: find.byType(SeasonWeather),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
      reason: 'no weather painter in summer',
    );
  });
}

/// Whether the weather is animating. Reads TickerMode, since the ticker
/// itself reports active while muted.
bool _ticking(WidgetTester tester) => TickerMode.valuesOf(
      tester.element(find.byType(SeasonWeather, skipOffstage: false)),
    ).enabled;
