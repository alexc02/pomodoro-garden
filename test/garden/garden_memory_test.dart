import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/features/garden/garden_view.dart';
import 'package:pomodoro_garden/src/features/garden/seasonal_garden.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/garden/garden_atlas.dart';
import 'package:pomodoro_garden/src/garden/garden_painter.dart';
import 'package:pomodoro_garden/src/garden/garden_projection.dart';
import 'package:pomodoro_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pomodoro_garden/src/garden/plant_sprite.dart';
import 'package:pomodoro_garden/src/garden/plant_sway.dart';
import 'package:pomodoro_garden/src/garden/season_providers.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/celebrations.dart';
import '../support/decor_fixtures.dart';
import '../support/garden_seed.dart';

/// PRD §4.4, ticket 24: **memory is stable across a long session with a large
/// garden — no growth over time from animation or sprite handling.**
///
/// A leak is usually chased with a heap snapshot, which is a device tool and a
/// human reading it. What this file does instead is watch the two things the
/// garden allocates that are *not* ordinary Dart objects and so are not the
/// garbage collector's problem: `dart:ui` [ui.Image]s and [ui.Picture]s. Both
/// hold native memory behind a handle, both are released by an explicit
/// `dispose`, and both announce themselves through the hooks used below. That
/// makes "the garden leaks textures" a thing a workstation can assert rather
/// than a thing a profiler has to be pointed at.
///
/// **Why those two and not everything.** They are where the bytes are. One
/// atlas is a 600×800-ish RGBA texture — roughly two megabytes of native memory
/// per bake — and the garden rebakes on every change of season and theme, on
/// every trip in and out of dark mode, and (before ticket 14 put a floor under
/// it) potentially per frame. Sixty leaked bakes is a hundred and twenty
/// megabytes and a phone killing the app. A leaked `List<RSTransform>`, by
/// contrast, is collected like anything else.
///
/// The counters are exact, not statistical. There is no sampling and no
/// threshold to tune: an image that was created and not disposed is one number
/// away from an image that was.

const Size _window = Size(400, 800);

const PlantPalette _palette = PlantPalette(
  foliage: Color(0xFF4CAF50),
  bloom: Color(0xFFFFC107),
  soil: Color(0xFF795548),
);

GardenAtlasRecipe _recipe({Color soil = const Color(0xFF795548)}) =>
    GardenAtlasRecipe(
      registry: const PlaceholderPlantSpriteRegistry(),
      decorRegistry: testDecorRegistry,
      decorPalette: testDecorPalette,
      palettes: {for (final species in PlantSpecies.values) species: _palette},
      soil: soil,
      decor: const Color(0xFF9A9A92),
    );

GardenLayout _fullGarden() => GardenLayout.of(
      plants: [
        for (var n = 0; n < GardenPlots.maximum; n++)
          Plant(
            id: 'plant-$n',
            sessionId: 'session-$n',
            type: PlantType.values[n % PlantType.values.length],
            species: PlantSpecies.values[n % PlantSpecies.values.length],
            stage: GrowthStage.mature,
            plantedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: n)),
            sessionDuration: const Duration(minutes: 25),
            plot: GardenPlots.inPlacementOrder[n],
          ),
      ],
      completedSessions: 5000,
    );

/// How many `dart:ui` handles were opened and not closed again.
typedef _Handles = ({int imagesOpen, int picturesOpen});

/// Watches [ui.Image] and [ui.Picture] allocation for as long as it is not
/// [stop]ped.
///
/// The hooks are process-global and may be somebody else's — the framework sets
/// them itself when leak tracking is on — so whatever was there is put back. A
/// test that took [ui.Image.onCreate] and kept it would break every test after
/// it, silently and at a distance.
class _HandleWatch {
  _HandleWatch.start() {
    _wasImageCreate = ui.Image.onCreate;
    _wasImageDispose = ui.Image.onDispose;
    _wasPictureCreate = ui.Picture.onCreate;
    _wasPictureDispose = ui.Picture.onDispose;

    ui.Image.onCreate = _images.add;
    ui.Image.onDispose = _images.remove;
    ui.Picture.onCreate = _pictures.add;
    ui.Picture.onDispose = _pictures.remove;
  }

  final Set<ui.Image> _images = {};
  final Set<ui.Picture> _pictures = {};

  late final ui.ImageEventCallback? _wasImageCreate;
  late final ui.ImageEventCallback? _wasImageDispose;
  late final ui.PictureEventCallback? _wasPictureCreate;
  late final ui.PictureEventCallback? _wasPictureDispose;

  /// What is open right now, without giving the hooks back.
  ///
  /// Two readings of this taken a thousand frames apart are what "no growth
  /// over time" actually means — an absolute count is a property of how much
  /// app is on screen, and it is not the thing PRD §4.4 is asking about.
  _Handles get live =>
      (imagesOpen: _images.length, picturesOpen: _pictures.length);

  _Handles stop() {
    ui.Image.onCreate = _wasImageCreate;
    ui.Image.onDispose = _wasImageDispose;
    ui.Picture.onCreate = _wasPictureCreate;
    ui.Picture.onDispose = _wasPictureDispose;

    return (imagesOpen: _images.length, picturesOpen: _pictures.length);
  }
}

/// The handles [during] opened and did not close.
///
/// The hooks are put back on the way out of a failure too, so one failing
/// expectation does not take the rest of the file with it.
_Handles _handlesOpenedBy(void Function() during) {
  final watch = _HandleWatch.start();
  try {
    during();
    return watch.stop();
  } catch (_) {
    watch.stop();
    rethrow;
  }
}

/// The same, for something that awaits.
Future<_Handles> _handlesOpenedByAsync(Future<void> Function() during) async {
  final watch = _HandleWatch.start();
  try {
    await during();
    return watch.stop();
  } catch (_) {
    watch.stop();
    rethrow;
  }
}

void main() {
  group('the atlas', () {
    test('releases its texture when it is disposed', () {
      // The floor everything else here stands on. If a bake and a dispose do
      // not balance in the simplest possible case, no number below means
      // anything.
      final handles = _handlesOpenedBy(() {
        GardenAtlas.bake(_recipe()).dispose();
      });

      expect(handles.imagesOpen, 0);
      expect(handles.picturesOpen, 0,
          reason: 'bake records a picture to rasterise and must not keep it');
    });

    test('does not accumulate textures across a hundred rebakes', () {
      // A hundred is far more than a real install sees — it is every season
      // boundary for twenty-five years — and the point is that the number does
      // not depend on the count. One bake held is a leak; a hundred held is
      // two hundred megabytes.
      final handles = _handlesOpenedBy(() {
        for (var n = 0; n < 100; n++) {
          GardenAtlas.bake(_recipe(soil: Color(0xFF795548 + n))).dispose();
        }
      });

      expect(handles.imagesOpen, 0);
      expect(handles.picturesOpen, 0);
    });
  });

  group('painting a full garden', () {
    test('allocates no texture at all, however many frames go by', () {
      // The claim behind the frame budget: a frame of the garden is arithmetic
      // and a `drawAtlas`, and the texture it draws from was baked once. If a
      // frame ever bakes, this is the test that says so — and it would say so
      // long before a device did, because a workstation has the memory to
      // survive it.
      final atlas = GardenAtlas.bake(_recipe());
      addTearDown(atlas.dispose);
      final garden = _fullGarden();
      final camera = GardenProjection.fitting(_window, garden.plots);

      final sway = AnimationController(
        vsync: const TestVSync(),
        duration: PlantSway.period,
      );
      addTearDown(sway.dispose);

      final handles = _handlesOpenedBy(() {
        for (var frame = 0; frame < 600; frame++) {
          // Ten seconds of a swaying, panning garden at sixty frames a second.
          sway.value = (frame % 240) / 240;
          final painter = GardenPainter(
            layout: garden,
            projection: camera.pannedBy(Offset(frame % 60 - 30, 0)),
            atlas: atlas,
            sway: sway,
          );

          final recorder = ui.PictureRecorder();
          painter.paint(Canvas(recorder), _window);
          recorder.endRecording().dispose();
        }
      });

      expect(handles.imagesOpen, 0, reason: 'a frame baked a texture');
      expect(handles.picturesOpen, 0);
    });

    test('and builds the same batch on the last frame as on the first', () {
      // The other shape a leak takes in a painter: a list that is appended to
      // rather than rebuilt, which grows without ever allocating a texture.
      final atlas = GardenAtlas.bake(_recipe());
      addTearDown(atlas.dispose);
      final garden = _fullGarden();

      final painter = GardenPainter(
        layout: garden,
        projection: GardenProjection.fitting(_window, garden.plots),
        atlas: atlas,
      );

      final first = painter.batchFor(_window).transforms.length;
      for (var frame = 0; frame < 600; frame++) {
        painter.batchFor(_window);
      }

      expect(painter.batchFor(_window).transforms.length, first);
    });
  });

  group('in the running app', () {
    testWidgets('does not grow across a long visit to a full garden',
        (tester) async {
      // **Two readings, not one.** How many handles a running app holds at any
      // instant is a property of how many layers are on screen — eighteen or so
      // pictures, one per repaint boundary, none of them the garden's doing.
      // The criterion is about the *derivative*: PRD §4.4 asks that memory be
      // stable over a long session, so what is asserted is that ten more
      // seconds of a swaying, dragged, two-hundred-plant garden leaves the
      // count exactly where the first ten did.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: GardenPlots.maximum);

      final watch = _HandleWatch.start();
      addTearDown(watch.stop);

      await pumpApp(tester, database: database, surface: _window);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GardenView)),
      );

      Future<void> drag(int frames) async {
        for (var frame = 0; frame < frames; frame++) {
          await gesture.moveBy(Offset(frame.isEven ? 1 : -1, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      // Ten seconds each side: two and a half sway periods, on a screen that
      // never stops animating and never stops being dragged.
      await drag(600);
      final early = watch.live;
      await drag(600);
      final late_ = watch.live;

      await gesture.up();
      await tester.pump();

      expect(early.imagesOpen, 1,
          reason: 'the one atlas the garden is drawing from, and no other');
      expect(late_.imagesOpen, early.imagesOpen,
          reason: 'a texture was allocated and kept while the garden animated');
      expect(late_.picturesOpen, early.picturesOpen,
          reason: 'the layer tree grew a picture per frame');
    });

    testWidgets('and leaves nothing behind when the garden goes', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: GardenPlots.maximum);

      final handles = await _handlesOpenedByAsync(() async {
        await pumpApp(tester, database: database, surface: _window);
        await tester.pump(PlantSway.period);

        // The app going away, which is the moment a texture held by a
        // disposed state would become a leak nothing could ever release.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      expect(handles.imagesOpen, 0);
    });

    testWidgets('turning the garden over and over does not stack up textures',
        (tester) async {
      // A change of season rebakes the texture, repeatedly: the crossfade moves
      // the soil colour for three seconds and [GardenView.rebakeInterval] lets
      // one bake through every 250ms of it. So a year forced through the debug
      // affordance is on the order of a hundred and fifty bakes, which is the
      // case where a missed `dispose` stops being a leak and becomes a
      // crash — a hundred and fifty textures is three hundred megabytes.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 40);

      final handles = await _handlesOpenedByAsync(() async {
        await pumpApp(
          tester,
          database: database,
          surface: _window,
          clock: FixedClock(DateTime.utc(2026, 7, 12, 10)),
          overrides: [
            hemisphereProvider.overrideWithValue(Hemisphere.northern),
          ],
        );
        // Forty sessions is past REQ-021's first awards, and the sheet they
        // raise is over the tab bar this test is about to use.
        await dismissCelebrations(tester);

        // Four times round the year.
        for (var turn = 0; turn < 4; turn++) {
          for (final season in Season.values) {
            await _force(tester, season);
            await settle(tester, over: SeasonalGarden.crossfade);
          }
        }
      });

      // The one on screen, and at most one on its way out: a replaced texture
      // is released in a post-frame callback rather than under the frame that
      // is still referring to it.
      expect(handles.imagesOpen, lessThanOrEqualTo(2));
    });
  });
}

/// Forces the garden into [season] from the settings screen, the way the debug
/// affordance does, and comes back to the garden.
Future<void> _force(WidgetTester tester, Season season) async {
  await tapTab(tester, AppTab.settings);
  await scrollToSetting(tester, SettingsKeys.season);
  await tester.tap(find.text(season.label));
  await settle(tester);
  await tapTab(tester, AppTab.garden);
}
