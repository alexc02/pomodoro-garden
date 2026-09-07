import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/design/garden_colors.dart';
import 'package:pip_garden/src/design/palette.dart';
import 'package:pip_garden/src/design/season_palette.dart';
import 'package:pip_garden/src/features/garden/garden_view.dart';
import 'package:pip_garden/src/features/garden/seasonal_garden.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/features/timer/timer_screen.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/plant_palettes.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';
import 'package:pip_garden/src/garden/season_weather.dart';
import 'package:pip_garden/src/garden/season_providers.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/garden_seed.dart';

// Seasons through the app: the garden follows the device date; nothing else
// in the app changes.

const Size _window = Size(400, 800);

/// A clock at [local] device time. Local, since seasons follow the wall
/// calendar and UTC would differ per timezone.
FixedClock _clockAt(DateTime local) => FixedClock(local.toUtc());

/// Opens the garden tab in the season [local] falls in.
Future<void> _openGarden(
  WidgetTester tester, {
  DateTime? local,
  Hemisphere hemisphere = Hemisphere.northern,
  int sessions = 3,
}) async {
  final database = AppDatabase.forTesting();
  addTearDown(database.close);
  await seedGarden(database, sessions: sessions);

  await pumpApp(
    tester,
    database: database,
    surface: _window,
    clock: local == null ? null : _clockAt(local),
    overrides: [hemisphereProvider.overrideWithValue(hemisphere)],
  );
  await tapTab(tester, AppTab.garden);
}

GardenColors _garden(WidgetTester tester) => GardenColors.of(
      tester.element(find.byType(GardenView)),
    );

/// The colours plants are baked in.
PlantPalette _palette(WidgetTester tester, PlantSpecies species) =>
    plantPaletteFor(tester.element(find.byType(GardenView)), species);

/// Forces [season] via the debug option.
Future<void> _force(WidgetTester tester, Season? season) async {
  await tapTab(tester, AppTab.settings);
  await scrollToSetting(tester, SettingsKeys.season);
  await tester.tap(find.text(season?.label ?? 'Automatic'));
  await settle(tester);
  await tapTab(tester, AppTab.garden);
}

void main() {
  group('season from the device date', () {
    testWidgets('April is spring', (tester) async {
      await _openGarden(tester, local: DateTime(2026, 4, 12, 10));

      expect(_garden(tester).skyDay, Palette.springSky);
      expect(_garden(tester).soil, Palette.springSoil);
    });

    testWidgets('November is autumn', (tester) async {
      await _openGarden(tester, local: DateTime(2026, 11, 12, 10));

      expect(_garden(tester).skyDay, Palette.autumnSky);
      expect(_garden(tester).foliage, Palette.autumnFoliage);
    });

    testWidgets('January is winter', (tester) async {
      await _openGarden(tester, local: DateTime(2026, 1, 12, 10));

      expect(_garden(tester).skyDay, Palette.winterSky);
    });

    testWidgets('southern hemisphere gets summer in January', (tester) async {
      await _openGarden(
        tester,
        local: DateTime(2026, 1, 12, 10),
        hemisphere: Hemisphere.southern,
      );

      expect(_garden(tester).skyDay, Palette.summerSky);
    });

    testWidgets('rest of the app is unchanged', (tester) async {
      // The timer tab uses the same theme and must not change.
      await _openGarden(tester, local: DateTime(2026, 1, 12, 10));
      expect(_garden(tester).skyDay, Palette.winterSky);

      await tapTab(tester, AppTab.timer);
      final timer = GardenColors.of(tester.element(find.byType(TimerScreen)));

      expect(timer.skyDay, Palette.skyDay);
      expect(timer.soil, Palette.soil);
      expect(timer.foliage, Palette.primary);
    });
  });

  group('winter', () {
    testWidgets('deciduous plants lose leaves', (tester) async {
      await _openGarden(tester, local: DateTime(2026, 1, 12, 10));

      expect(_garden(tester).foliage, Palette.winterFoliage);
      // Evergreens are the exception, so maple and pine differ in winter but
      // not in July.
      expect(
        _palette(tester, PlantSpecies.maple).foliage,
        isNot(_palette(tester, PlantSpecies.pine).foliage),
      );
    });

    testWidgets('evergreens keep colour', (tester) async {
      await _openGarden(tester, local: DateTime(2026, 1, 12, 10));

      // plantPaletteFor shifts hue per species, so check it's green-ish, not
      // the orange-brown of bare wood.
      final pine = HSLColor.fromColor(_palette(tester, PlantSpecies.pine).foliage);
      final maple =
          HSLColor.fromColor(_palette(tester, PlantSpecies.maple).foliage);

      expect(pine.hue, greaterThan(90));
      expect(pine.hue, lessThan(180));
      expect(maple.hue, lessThan(90));
    });

    testWidgets('in July they look alike', (tester) async {
      await _openGarden(tester, local: DateTime(2026, 7, 12, 10));

      expect(_garden(tester).foliage, _garden(tester).evergreenFoliage);
    });
  });

  group('season change while open', () {
    testWidgets('crossfades over three seconds', (tester) async {
      // Two minutes before winter turns to spring, device time.
      final clock = _clockAt(DateTime(2026, 2, 28, 23, 58));
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 3);

      await pumpApp(
        tester,
        database: database,
        surface: _window,
        clock: clock,
        overrides: [
          hemisphereProvider.overrideWithValue(Hemisphere.northern),
        ],
      );
      await tapTab(tester, AppTab.garden);
      expect(_garden(tester).skyDay, Palette.winterSky);

      // Past midnight. The provider watches for this instant.
      await advance(tester, clock, const Duration(minutes: 2));
      await tester.pump();

      // Halfway through the crossfade.
      await tester.pump(const Duration(milliseconds: 1500));
      final midway = _garden(tester).skyDay;
      expect(midway, isNot(Palette.winterSky));
      expect(midway, isNot(Palette.springSky));

      await tester.pump(const Duration(milliseconds: 1600));
      expect(_garden(tester).skyDay, Palette.springSky);
    });

    testWidgets('does not rebake every frame', (tester) async {
      // The atlas bakes from soil colour, which moves every frame. Without
      // GardenView.rebakeInterval that's ~180 renders in 3s.
      await _openGarden(tester, local: DateTime(2026, 7, 12, 10));

      final baked = <Object>{};
      await _force(tester, Season.winter);

      for (var frame = 0; frame < 180; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        baked.add(_atlas(tester));
      }

      expect(
        baked.length,
        lessThanOrEqualTo(
          SeasonalGarden.crossfade.inMilliseconds ~/
                  GardenView.rebakeInterval.inMilliseconds +
              2,
        ),
        reason: 'should rebake in steps, not every frame',
      );
      // Still ends exactly on the new season.
      await settle(tester);
      expect(_garden(tester).soil, Palette.winterSoil);
    });
  });

  group('debug override', () {
    testWidgets('shows every season', (tester) async {
      await _openGarden(tester, local: DateTime(2026, 7, 12, 10));

      for (final (season, sky) in [
        (Season.spring, Palette.springSky),
        (Season.autumn, Palette.autumnSky),
        (Season.winter, Palette.winterSky),
        (Season.summer, Palette.summerSky),
      ]) {
        await _force(tester, season);
        await settle(tester, over: SeasonalGarden.crossfade);
        expect(_garden(tester).skyDay, sky, reason: '${season.label} was asked for');
      }
    });

    testWidgets('Off returns to the calendar', (tester) async {
      await _openGarden(tester, local: DateTime(2026, 7, 12, 10));

      await _force(tester, Season.winter);
      await settle(tester, over: SeasonalGarden.crossfade);
      expect(_garden(tester).skyDay, Palette.winterSky);

      await _force(tester, null);
      await settle(tester, over: SeasonalGarden.crossfade);
      expect(_garden(tester).skyDay, Palette.summerSky);
    });

    testWidgets('does not change what a session grows', (tester) async {
      // A plant depends on session length and id; a forced season can't reach
      // either.
      await _openGarden(tester, local: DateTime(2026, 7, 12, 10));
      final summer = _plants(tester);

      await _force(tester, Season.winter);
      await settle(tester, over: SeasonalGarden.crossfade);

      expect(_plants(tester), summer);
    });
  });

  group('the weather', () {
    testWidgets('falls in spring, autumn and winter', (tester) async {
      await _openGarden(tester, local: DateTime(2026, 4, 12, 10));
      expect(find.byType(SeasonWeather), findsOneWidget);
      expect(_falling(tester), isNotNull);

      await _force(tester, Season.autumn);
      await settle(tester, over: SeasonalGarden.crossfade);
      expect(_falling(tester)?.shape, WeatherShape.leaf);

      await _force(tester, Season.winter);
      await settle(tester, over: SeasonalGarden.crossfade);
      expect(_falling(tester)?.shape, WeatherShape.flake);
    });

    testWidgets('none in summer', (tester) async {
      // Nothing falls in summer, so no overlay at all (an idle ticker still
      // costs a frame per vsync).
      await _openGarden(tester, local: DateTime(2026, 7, 12, 10));

      expect(_falling(tester), isNull);
      expect(
        find.descendant(
          of: find.byType(SeasonWeather),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('does not block taps', (tester) async {
      // The overlay covers the whole garden, so it must not take taps.
      await _openGarden(tester, local: DateTime(2026, 1, 12, 10), sessions: 8);

      expect(
        find.descendant(
          of: find.byType(SeasonWeather),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
        reason: 'the overlay needs its own IgnorePointer',
      );

      // A plant under the snow still opens.
      final painter = _painter(tester);
      final plant = painter.layout.plants.first;
      final at = painter.projection.centreOf(plant.plot!);

      await tester.tapAt(
        tester.getTopLeft(find.byType(GardenView)) + at,
      );
      await settle(tester);

      expect(find.text(plant.species.label), findsOneWidget);
    });
  });
}

GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GardenPainter,
    ))
    .painter! as GardenPainter;

Object _atlas(WidgetTester tester) => _painter(tester).atlas;

/// Every plant as species and plot.
List<String> _plants(WidgetTester tester) => _painter(tester)
    .layout
    .plants
    .map((plant) => '${plant.id} ${plant.type.name} ${plant.species.name} '
        '${plant.plot}')
    .toList();

/// What's falling on the garden tab, if anything.
Weather? _falling(WidgetTester tester) {
  final overlay = tester.widget<SeasonWeather>(find.byType(SeasonWeather));
  return overlay.transition.to.palette.weather;
}
