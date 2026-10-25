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

/// REQ-019, through the app: the garden reads the device's date and dresses
/// itself for the month, and nothing else in the app can tell.

/// A phone-sized window.
const Size _window = Size(400, 800);

/// A clock reading [local] on the device's own calendar.
///
/// Built from a local `DateTime` rather than a UTC one because a season is a
/// property of the date on the wall, and a test that wrote UTC would be asking
/// a different question in every time zone the suite is run in.
FixedClock _clockAt(DateTime local) => FixedClock(local.toUtc());

/// Opens the garden tab, in the season [local] falls in.
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

/// The garden colours the garden tab is being drawn with right now.
GardenColors _garden(WidgetTester tester) => GardenColors.of(
      tester.element(find.byType(GardenView)),
    );

/// The colours the plants themselves are baked in.
PlantPalette _palette(WidgetTester tester, PlantSpecies species) =>
    plantPaletteFor(tester.element(find.byType(GardenView)), species);

/// Forces [season] from the debug affordance, as a reviewer would.
Future<void> _force(WidgetTester tester, Season? season) async {
  await tapTab(tester, AppTab.settings);
  await scrollToSetting(tester, SettingsKeys.season);
  await tester.tap(find.text(season?.label ?? 'Automatic'));
  await settle(tester);
  await tapTab(tester, AppTab.garden);
}

void main() {
  group('the season comes off the device date', () {
    testWidgets('April is spring, and the sky says so', (tester) async {
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

    testWidgets('and a garden in Sydney gets summer in January',
        (tester) async {
      await _openGarden(
        tester,
        local: DateTime(2026, 1, 12, 10),
        hemisphere: Hemisphere.southern,
      );

      expect(_garden(tester).skyDay, Palette.summerSky);
    });

    testWidgets('the app around it stays the colour it always was',
        (tester) async {
      // The whole of "season affects the garden view only", at the seam where
      // it could go wrong: the timer tab is built from the same theme and must
      // not have heard about January.
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
    testWidgets('takes the leaves off everything that drops them',
        (tester) async {
      await _openGarden(tester, local: DateTime(2026, 1, 12, 10));

      expect(_garden(tester).foliage, Palette.winterFoliage);
      // REQ-019 names the evergreens as the exception, so a maple and a pine
      // have to be drawn differently — and the same two in July must not be.
      expect(
        _palette(tester, PlantSpecies.maple).foliage,
        isNot(_palette(tester, PlantSpecies.pine).foliage),
      );
    });

    testWidgets('and leaves the evergreens holding colour', (tester) async {
      await _openGarden(tester, local: DateTime(2026, 1, 12, 10));

      // Not the exact hex — `plantPaletteFor` shifts every species a few
      // degrees around the wheel — but a green rather than bare wood. Hue is
      // the honest test: bare wood is orange-brown, and a pine in January is
      // not.
      final pine = HSLColor.fromColor(_palette(tester, PlantSpecies.pine).foliage);
      final maple =
          HSLColor.fromColor(_palette(tester, PlantSpecies.maple).foliage);

      expect(pine.hue, greaterThan(90));
      expect(pine.hue, lessThan(180));
      expect(maple.hue, lessThan(90));
    });

    testWidgets('which is a July garden they are indistinguishable in',
        (tester) async {
      await _openGarden(tester, local: DateTime(2026, 7, 12, 10));

      expect(_garden(tester).foliage, _garden(tester).evergreenFoliage);
    });
  });

  group('crossing a boundary with the app open', () {
    testWidgets('turns the garden over three seconds rather than in a frame',
        (tester) async {
      // Two minutes before winter turns into spring, on the device's own
      // calendar.
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

      // Past midnight. The provider is watching for exactly this instant, so
      // the season changes without anything asking it to.
      await advance(tester, clock, const Duration(minutes: 2));
      await tester.pump();

      // Halfway through the crossfade: neither season, and on the way from one
      // to the other.
      await tester.pump(const Duration(milliseconds: 1500));
      final midway = _garden(tester).skyDay;
      expect(midway, isNot(Palette.winterSky));
      expect(midway, isNot(Palette.springSky));

      // And arrived, once the three seconds are up.
      await tester.pump(const Duration(milliseconds: 1600));
      expect(_garden(tester).skyDay, Palette.springSky);
    });

    testWidgets('and does not rebake the texture once a frame while it does',
        (tester) async {
      // The crossfade moves the soil colour every frame, and the atlas is baked
      // from the soil colour: without the floor in [GardenView.rebakeInterval]
      // this would be a hundred and eighty offscreen renders in three seconds.
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
        reason: 'the texture should step through the crossfade, not follow it',
      );
      // And it still ends up on the season it landed in, rather than one step
      // short of it.
      await settle(tester);
      expect(_garden(tester).soil, Palette.winterSoil);
    });
  });

  group('the debug affordance', () {
    testWidgets('shows every season without waiting for it', (tester) async {
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

    testWidgets('hands the garden back to the calendar', (tester) async {
      await _openGarden(tester, local: DateTime(2026, 7, 12, 10));

      await _force(tester, Season.winter);
      await settle(tester, over: SeasonalGarden.crossfade);
      expect(_garden(tester).skyDay, Palette.winterSky);

      await _force(tester, null);
      await settle(tester, over: SeasonalGarden.crossfade);
      expect(_garden(tester).skyDay, Palette.summerSky);
    });

    testWidgets('and changes nothing about what a session grows',
        (tester) async {
      // The ticket's last line, and the one worth a test rather than a
      // comment: a plant is decided by its session's length and its id, and a
      // forced season must not be able to reach either.
      await _openGarden(tester, local: DateTime(2026, 7, 12, 10));
      final summer = _plants(tester);

      await _force(tester, Season.winter);
      await settle(tester, over: SeasonalGarden.crossfade);

      expect(_plants(tester), summer);
    });
  });

  group('the weather', () {
    testWidgets('falls in the three seasons that have any', (tester) async {
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

    testWidgets('and leaves the summer sky empty', (tester) async {
      // REQ-019 gives summer a bright sky and vibrant flowers, and nothing
      // falling out of it. An overlay drawing nothing should not be there at
      // all: a ticker with no work still costs a frame every vsync.
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

    testWidgets('never takes a tap meant for a plant', (tester) async {
      // Ambient means ambient: the overlay is over the whole garden, so if it
      // were hit-testable it would swallow every tap on the tab.
      await _openGarden(tester, local: DateTime(2026, 1, 12, 10), sessions: 8);

      expect(
        find.descendant(
          of: find.byType(SeasonWeather),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
        reason: 'the overlay puts its own IgnorePointer inside itself; an '
            'ancestor one would be the route\'s, which every page has',
      );

      // And through the whole stack: a plant under the snow still opens.
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

/// The whole of what the garden tab is drawing: its plants, its camera and its
/// texture.
GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GardenPainter,
    ))
    .painter! as GardenPainter;

/// The texture the garden is currently drawn from.
Object _atlas(WidgetTester tester) => _painter(tester).atlas;

/// Every plant in the garden, as the species and plot it is standing in.
List<String> _plants(WidgetTester tester) => _painter(tester)
    .layout
    .plants
    .map((plant) => '${plant.id} ${plant.type.name} ${plant.species.name} '
        '${plant.plot}')
    .toList();

/// What is falling on the garden tab right now, if anything.
Weather? _falling(WidgetTester tester) {
  final overlay = tester.widget<SeasonWeather>(find.byType(SeasonWeather));
  return overlay.transition.to.palette.weather;
}
