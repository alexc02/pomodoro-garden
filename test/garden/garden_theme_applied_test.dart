import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_settings_repository.dart';
import 'package:pomodoro_garden/src/design/garden_colors.dart';
import 'package:pomodoro_garden/src/design/palette.dart';
import 'package:pomodoro_garden/src/design/theme_palette.dart';
import 'package:pomodoro_garden/src/features/garden/garden_view.dart';
import 'package:pomodoro_garden/src/features/garden/seasonal_garden.dart';
import 'package:pomodoro_garden/src/features/garden/theme_picker.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/garden/garden_painter.dart';
import 'package:pomodoro_garden/src/garden/growing_plant.dart';
import 'package:pomodoro_garden/src/garden/season_providers.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/garden_seed.dart';

/// REQ-034 on the garden itself: the theme that is actually drawn, and how it
/// arrives.
///
/// Two of the ticket's criteria are here — the choice persists across a relaunch
/// and a switch crossfades without disturbing the plants — and both are about
/// the garden rather than the picker. A third, about a theme the device was not
/// entitled to falling back to Zen, went with the entitlement: the app is free
/// and every theme it stores is one it draws. See `docs/adr/0021-…`.

/// The colours the garden is currently painted in.
GardenColors _garden(WidgetTester tester) => GardenColors.of(
      tester.element(find.byType(GardenView)),
    );

/// Where one quad of the batch is anchored, and how big it is drawn.
typedef _Placement = ({Offset at, double scale});

/// Where every plot and plant is on screen, as the painter would draw them.
///
/// **Anchors rather than the raw transforms, because REQ-023's sway leans the
/// plants.** An `RSTransform` holds the transformed top-left corner and a
/// `scale * cos` / `scale * sin` pair, so every one of those three numbers moves
/// when a plant leans — and a leaning plant is the garden working, not the
/// garden being disturbed. What a theme change must not touch is the point each
/// quad is *hung from*: the middle of a tile, the bottom middle of a plant. That
/// point is the plot, it is what the projection decides, and it is invariant
/// under the rotation. Recovering it is the same arithmetic
/// [RSTransform.fromComponents] does, run backwards.
List<_Placement> _positions(WidgetTester tester) {
  final view = tester.widget<CustomPaint>(find.descendant(
    of: find.byType(GardenView),
    matching: find.byType(CustomPaint),
  ).first);

  final painter = view.painter! as GardenPainter;
  final atlas = painter.atlas;
  final batch = painter.batchFor(tester.getSize(find.byType(GardenView)));

  return [
    for (var index = 0; index < batch.rects.length; index++)
      () {
        final rect = batch.rects[index];
        final transform = batch.transforms[index];
        final ground = rect == atlas.emptySoil || rect == atlas.plantedSoil;

        // A tile hangs from the middle of itself; anything standing on one
        // hangs from the bottom middle of its cell.
        final anchorX = rect.width / 2;
        final anchorY = ground ? rect.height / 2 : rect.height;

        return (
          at: Offset(
            transform.tx + transform.scos * anchorX - transform.ssin * anchorY,
            transform.ty + transform.ssin * anchorX + transform.scos * anchorY,
          ),
          scale: math.sqrt(
            transform.scos * transform.scos + transform.ssin * transform.ssin,
          ),
        );
      }(),
  ];
}

/// Tall enough to hold three preview cards, so every one of them is built and
/// can be tapped without scrolling.
const _tall = Size(600, 2400);

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  /// A garden with something in it, dressed in [theme].
  Future<void> open(
    WidgetTester tester, {
    required GardenTheme theme,
    DateTime? local,
  }) async {
    await seedGarden(database, sessions: 3);
    await pumpApp(
      tester,
      database: database,
      settings: GardenSettings.defaults.withGardenTheme(theme),
      clock: FixedClock(local ?? DateTime(2026, 7, 12, 10)),
      surface: _tall,
      overrides: [
        hemisphereProvider.overrideWithValue(Hemisphere.northern),
      ],
    );
    await tapTab(tester, AppTab.garden);
  }

  /// Picks [theme] from the picker and comes back to the garden, the way a
  /// user does.
  Future<void> pick(WidgetTester tester, GardenTheme theme) async {
    await tapTab(tester, AppTab.settings);
    await tester.tap(await scrollToSetting(tester, SettingsKeys.gardenTheme));
    await settle(tester);
    await tester.tap(find.byKey(ThemePickerKeys.card(theme)));
    await settle(tester);
    await tester.tap(find.byType(BackButton).first);
    await settle(tester);
    await tapTab(tester, AppTab.garden);
  }

  group('the chosen theme is the one on screen', () {
    testWidgets('a garden opens in the theme it was left in', (tester) async {
      await open(tester, theme: GardenTheme.tropical);

      expect(_garden(tester).skyDay, Palette.tropicalSummerSky);
      expect(_garden(tester).soil, Palette.tropicalSummerSoil);
      expect(_garden(tester).decor, Palette.tropicalTeak);
    });

    testWidgets('and every theme reaches the garden it was picked for',
        (tester) async {
      for (final theme in GardenTheme.values) {
        expect(
          ThemePalette.of(theme).summer.sky,
          isNotNull,
          reason: '${theme.name} has no summer',
        );
      }
    });

    testWidgets('the theme reaches the garden and stops there', (tester) async {
      await open(tester, theme: GardenTheme.wildflower);

      // The garden's subtree is dressed; the app around it is not. A meadow
      // must not turn the settings sliders or the timer's ring to straw.
      final outside = GardenColors.of(
        tester.element(find.byType(NavigationBar)),
      );

      expect(_garden(tester).skyDay, Palette.meadowSummerSky);
      expect(outside.skyDay, Palette.skyDay);
      expect(outside.decor, Palette.zenStone);
    });
  });

  group('the choice survives a relaunch', () {
    testWidgets('a theme picked in one run opens the next one', (tester) async {
      await seedGarden(database, sessions: 2);
      await pumpApp(tester, database: database, surface: _tall);

      // Picked the way a user picks it, rather than written past the screen.
      await pick(tester, GardenTheme.tropical);

      // The app dies without warning and starts again on the same database.
      await killApp(tester);
      await pumpApp(tester, database: database, surface: _tall);
      await tapTab(tester, AppTab.garden);

      expect(_garden(tester).decor, Palette.tropicalTeak);

      // Torn down inside the test rather than left to the framework: the
      // garden writes a `garden_viewed` event as it is disposed, and a tree
      // still unwinding after this test's database has closed would report
      // that failure against whichever test runs next.
      await killApp(tester);
    });

    testWidgets('and it opens *in* it, rather than fading into it',
        (tester) async {
      // The first frame the user sees is already the right garden. A launch
      // that crossfaded in from Zen would be a bug that looked like a feature.
      await open(tester, theme: GardenTheme.wildflower);

      expect(_garden(tester).skyDay, Palette.meadowSummerSky);
    });
  });

  group('switching crossfades rather than cutting', () {
    testWidgets('the garden is between the two on the way over',
        (tester) async {
      await open(tester, theme: GardenTheme.zen);
      expect(_garden(tester).skyDay, Palette.summerSky);

      await tapTab(tester, AppTab.settings);
      await tester.tap(await scrollToSetting(tester, SettingsKeys.gardenTheme));
      await settle(tester);

      // From here on the frames are counted rather than settled: the crossfade
      // is three seconds long and `settle` pumps one of them at a time, so
      // walking back to the garden the usual way would arrive after it had
      // finished and prove nothing.
      // Enough frames for a route to pop and a tab to change — a few hundred
      // milliseconds each — and nowhere near three seconds. [settle] rather
      // than a single long [WidgetTester.pump], which advances the clock by
      // 400ms but only draws one frame of the transition.
      Future<void> step() =>
          settle(tester, over: const Duration(milliseconds: 350));

      await tester.tap(find.byKey(ThemePickerKeys.card(GardenTheme.tropical)));
      await tester.pump();
      await tester.tap(find.byType(BackButton).first);
      await step();
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(AppTab.garden.label),
      ));
      await step();

      expect(
        find.byType(GardenView),
        findsOne,
        reason: 'the walk back to the garden did not arrive',
      );

      // Partway across: neither garden, and on the way from one to the other.
      final midway = _garden(tester).skyDay;
      expect(midway, isNot(Palette.summerSky));
      expect(midway, isNot(Palette.tropicalSummerSky));

      // And it arrives.
      await settle(tester, over: SeasonalGarden.crossfade);
      expect(_garden(tester).skyDay, Palette.tropicalSummerSky);
    });

    testWidgets('and the plants do not move while it happens', (tester) async {
      await open(tester, theme: GardenTheme.zen);
      final before = _positions(tester);

      await pick(tester, GardenTheme.wildflower);
      await settle(tester, over: SeasonalGarden.crossfade);

      // A crossfade is colour and nothing else. Every plot and every plant is
      // exactly where it was — the ticket asks that switching themes not
      // disturb plant positions, and a garden that rearranged itself when the
      // user changed its colours would lose them the thing they were looking
      // at.
      final after = _positions(tester);
      expect(after, hasLength(before.length));
      for (var i = 0; i < before.length; i++) {
        // A tolerance because the anchor is recovered through the batch's
        // single-precision floats, not because anything is expected to have
        // shifted: a sixteenth of a pixel is four orders of magnitude below a
        // garden that rearranged itself.
        expect(after[i].at.dx, closeTo(before[i].at.dx, 1 / 16),
            reason: 'quad $i moved sideways');
        expect(after[i].at.dy, closeTo(before[i].at.dy, 1 / 16),
            reason: 'quad $i moved down');
        expect(after[i].scale, closeTo(before[i].scale, 1 / 16),
            reason: 'quad $i changed size');
      }
    });
  });

  group('and nothing that was growing is disturbed', () {
    testWidgets('a session goes on growing across a change of theme',
        (tester) async {
      // The other half of the ticket's sixth criterion. A theme is a colour
      // and nothing else, so the plant on the timer must not restart, jump a
      // stage or lose the minutes it has already banked — and there is no code
      // path from a theme to a session, which is what this checks stays true.
      final clock = FixedClock(DateTime.utc(2026, 7, 12, 10));
      await seedGarden(database, sessions: 1);
      await pumpApp(
        tester,
        database: database,
        clock: clock,
        surface: _tall,
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 12));

      final growingBefore = tester.widget<GrowingPlant>(
        find.byType(GrowingPlant),
      ).growth;

      await tapTab(tester, AppTab.settings);
      await tester.tap(await scrollToSetting(tester, SettingsKeys.gardenTheme));
      await settle(tester);
      await tester.tap(find.byKey(ThemePickerKeys.card(GardenTheme.tropical)));
      await settle(tester);
      await tester.tap(find.byType(BackButton).first);
      await settle(tester);
      await tapTab(tester, AppTab.timer);

      final growingAfter = tester.widget<GrowingPlant>(
        find.byType(GrowingPlant),
      ).growth;

      // Still growing something, and still the same something: the same
      // plant, at the same stage, on the same session.
      expect(growingBefore, isNotNull);
      expect(growingAfter, isNotNull);
      expect(growingAfter!.stage, growingBefore!.stage);
      expect(growingAfter.type, growingBefore.type);
      expect(growingAfter.species, growingBefore.species);
      // And the session is still the one that was running.
      expect(find.text('Pause'), findsOne);
    });
  });

  group('what the user chose is what the garden draws', () {
    testWidgets('a stored theme is applied rather than filtered',
        (tester) async {
      // An earlier draft read the choice through an entitlement and drew Zen
      // for a device that owned nothing. There is nothing between the two any
      // more, and this is the test that would fail if something came back.
      await open(tester, theme: GardenTheme.wildflower);

      expect(_garden(tester).skyDay, Palette.meadowSummerSky);
      expect(
        (await DriftSettingsRepository(database).load()).gardenTheme,
        GardenTheme.wildflower,
      );
    });

    testWidgets('and settings names the same one', (tester) async {
      // So the row and the picker behind it cannot say two different things.
      await open(tester, theme: GardenTheme.wildflower);
      await tapTab(tester, AppTab.settings);
      await scrollToSetting(tester, SettingsKeys.gardenTheme);

      expect(find.text('Theme: Wildflower Meadow'), findsOne);
    });
  });

  group('themes and seasons compose', () {
    testWidgets('the greenhouse still turns with the calendar', (tester) async {
      // The greenhouse in November: amber light on the glass, and nothing
      // inside it turning. This is the pair of criteria the ticket cares most
      // about — every theme renders in all four seasons — asserted on the two
      // that are furthest apart.
      await open(
        tester,
        theme: GardenTheme.tropical,
        local: DateTime(2026, 11, 12, 10),
      );

      expect(_garden(tester).skyDay, Palette.tropicalAutumnSky);
      expect(_garden(tester).foliage, Palette.tropicalAutumnFoliage);
      // The material is the constant: it is a greenhouse in November as much
      // as it is in July.
      expect(_garden(tester).decor, Palette.tropicalTeak);
    });

    testWidgets('and the default one turns the same way', (tester) async {
      await open(
        tester,
        theme: GardenTheme.zen,
        local: DateTime(2026, 11, 12, 10),
      );

      expect(_garden(tester).skyDay, Palette.autumnSky);
      expect(_garden(tester).decor, Palette.zenStone);
    });
  });
}
