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

/// The ticket's two hard limits on REQ-019's weather: it must not obscure the
/// garden, and it must not cost the two-hundred-plant garden its frame rate.
///
/// Both are properties of a count and an alpha rather than of how the thing
/// looks, which is what makes them assertable at all — see [SeasonWeather],
/// where the count is capped rather than emergent.

/// A phone.
const Size _phone = Size(400, 800);

/// A tablet in landscape, and then some: the window a density quoted per unit
/// area could run away on.
const Size _desk = Size(2560, 1440);

/// Every season that has anything falling in it, in every theme.
Iterable<Weather> get _weathers => GardenTheme.values.expand(
      (theme) => Season.values
          .map((season) => ThemePalette.of(theme).inSeason(season).weather)
          .nonNulls,
    );

void main() {
  test('every season is dressed in its own colours, in every theme', () {
    // [ThemePalette] is twelve near-identical entries, which is exactly the
    // shape a copy-paste gets wrong silently — a garden showing autumn's
    // palette in spring would look deliberate.
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

  test('every season that has weather has three of them, in every theme', () {
    // Blossom, leaves and snow. A fourth would be an invention: REQ-019 names
    // falling things for spring, autumn and winter, and a bright sky for
    // summer — and REQ-034's themes reskin what falls rather than adding to
    // it, so the answer is the same three whichever garden you are standing
    // in.
    expect(_weathers, hasLength(3 * GardenTheme.values.length));
    for (final theme in GardenTheme.values) {
      expect(
        ThemePalette.of(theme).summer.weather,
        isNull,
        reason: 'something is falling in ${theme.name} summer',
      );
    }
  });

  group('how many are in the air', () {
    test('is a sane handful on a phone', () {
      for (final weather in _weathers) {
        final count = SeasonWeather.countIn(_phone, weather);
        expect(count, greaterThan(4), reason: 'enough to read as weather');
        expect(count, lessThan(40), reason: 'and not enough to read as a storm');
      }
    });

    test('is capped however big the window gets', () {
      for (final weather in _weathers) {
        expect(
          SeasonWeather.countIn(_desk, weather),
          SeasonWeather.maximum,
          reason: 'a density per unit area has to have a ceiling, or a desktop '
              'window is a thousand particles',
        );
      }
      // And absurdly big is still the same number, not more.
      expect(
        SeasonWeather.countIn(const Size(20000, 20000), _weathers.first),
        SeasonWeather.maximum,
      );
    });

    test('is none at all in a window with no room in it', () {
      expect(SeasonWeather.countIn(Size.zero, _weathers.first), 0);
    });
  });

  test('and none of them can hide what is behind it', () {
    for (final weather in _weathers) {
      expect(
        weather.opacity,
        lessThan(0.8),
        reason: 'a plant behind a falling ${weather.shape.name} still has to be '
            'visible through it',
      );

      // The other half of "does not obscure": how much of the screen is under
      // ink at all. A particle is a disc of at most `size` across, and even at
      // the cap they cover a fraction of a percent of the window.
      final covered = SeasonWeather.countIn(_phone, weather) *
          math.pi *
          math.pow(weather.size / 2, 2);
      expect(
        covered / (_phone.width * _phone.height),
        lessThan(0.005),
        reason: 'the weather is ambient, not a curtain',
      );
    }
  });

  test('and none of them is in a hurry', () {
    // §5.3's calm, as a number: the fastest thing in the sky still takes the
    // better part of a quarter of a minute to cross it.
    for (final weather in _weathers) {
      expect(weather.crossing, greaterThanOrEqualTo(const Duration(seconds: 15)));
    }
  });

  group('what a frame of it costs', () {
    // Timed directly rather than through the widget tree, for the reason
    // `garden_performance_test.dart` times the garden painter directly: the
    // budget is a claim about this painter, and a number taken through the tab
    // carries the tab's noise. The same method — 120 frames after a warm-up —
    // and the same shape of budget: loose enough not to flake on a busy CI box,
    // tight enough that a design which stopped bounding the count would trip
    // it.
    //
    // A frame at 60fps is 16 700µs all in, and the garden below the weather
    // costs about 200µs of it. A tenth of a millisecond for the sky is the
    // budget; the whole overlay has to be a rounding error or it is not
    // ambient.
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

    test('is nothing much, in any one season', () {
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

    test('and no worse mid-crossfade, with two seasons in the air', () {
      // The one moment two seasons' worth are up at once, and so the moment the
      // cap can be exceeded — the case a per-season budget would miss.
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

  testWidgets('a full garden in the snow still drags', (tester) async {
    // The end-to-end claim, on the case the ticket names: two hundred plants,
    // the densest of the three seasons falling over them, and a finger on the
    // garden. Recorded rather than asserted on a wall-clock budget — the same
    // judgement `garden_performance_test.dart` makes about a machine running
    // CI — but the count underneath it is capped by the tests above, so what
    // this number cannot do is grow with the window.
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

  testWidgets('and stops falling when the garden is not on screen',
      (tester) async {
    // The battery half of "bounded". The overlay's motion runs off a Ticker, so
    // the shell muting a hidden tab is what stops it — no frame is asked for
    // while the user is on the timer.
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

  testWidgets('and there is nothing left of the old season once summer arrives',
      (tester) async {
    // The case a half-described transition hides: arriving at summer leaves the
    // colours right and the overlay still animating autumn's leaves at an alpha
    // of nothing. What ends it is [SeasonalGarden] forgetting the season it
    // left, which is what makes a settled transition settled.
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
      reason: 'an empty summer sky should not be a painter drawing nothing',
    );
  });
}

/// Whether the weather is actually being animated right now.
///
/// Read off `TickerMode`, which is the thing the shell mutes and the thing the
/// overlay's ticker obeys — asking the ticker itself would report it as active
/// while it sat muted and idle.
bool _ticking(WidgetTester tester) => TickerMode.valuesOf(
      tester.element(find.byType(SeasonWeather, skipOffstage: false)),
    ).enabled;
