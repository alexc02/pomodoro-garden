import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/features/garden/garden_view.dart';
import 'package:pip_garden/src/features/garden/seasonal_garden.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/garden/garden_atlas.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/garden_projection.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';
import 'package:pip_garden/src/garden/plant_sway.dart';
import 'package:pip_garden/src/garden/season_providers.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/celebrations.dart';
import '../support/decor_fixtures.dart';
import '../support/garden_seed.dart';

// Memory should stay flat over a long session with a large garden.
//
// Rather than heap snapshots, this tracks dart:ui Images and Pictures: they
// hold native memory, need an explicit dispose, and have creation hooks we
// can count. An atlas bake is ~2 MB and rebakes on season, theme and dark mode
// changes, so leaked bakes add up fast. Ordinary Dart objects get GC'd.
//
// The counts are exact, no thresholds.

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

/// dart:ui handles opened and not closed.
typedef _Handles = ({int imagesOpen, int picturesOpen});

/// Counts [ui.Image] and [ui.Picture] allocations until [stop]ped.
///
/// The hooks are global and the framework may already use them (leak
/// tracking), so the previous ones are restored.
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

  /// Current open counts, without releasing the hooks. Compare two readings;
  /// the absolute count depends on what's on screen.
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

/// Handles [during] opened and didn't close. Restores the hooks even if it
/// throws.
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
    test('releases its texture on dispose', () {
      // Baseline: if this doesn't balance nothing below means anything.
      final handles = _handlesOpenedBy(() {
        GardenAtlas.bake(_recipe()).dispose();
      });

      expect(handles.imagesOpen, 0);
      expect(handles.picturesOpen, 0,
          reason: 'bake records a picture to rasterise and must not keep it');
    });

    test('no leak over 100 rebakes', () {
      // Far more than any real install, the count shouldn't depend on it.
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
    test('allocates no textures per frame', () {
      // A frame should be math plus drawAtlas from a texture baked once.
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
          // 10s of sway and pan at 60 fps.
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

    test('batch size stays constant', () {
      // A list appended to instead of rebuilt would leak without allocating any
      // texture.
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
    testWidgets('stays flat on a full garden', (tester) async {
      // Two readings: the absolute count depends on how many layers are on
      // screen (about 18 pictures). What matters is that another 10s of a
      // swaying, dragged 200-plant garden doesn't change it.
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

      // 10s each side, about 2.5 sway periods, dragging the whole time.
      await drag(600);
      final early = watch.live;
      await drag(600);
      final late_ = watch.live;

      await gesture.up();
      await tester.pump();

      expect(early.imagesOpen, 1,
          reason: 'only the current atlas');
      expect(late_.imagesOpen, early.imagesOpen,
          reason: 'texture leaked during animation');
      expect(late_.picturesOpen, early.picturesOpen,
          reason: 'the layer tree grew a picture per frame');
    });

    testWidgets('releases everything on teardown', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: GardenPlots.maximum);

      final handles = await _handlesOpenedByAsync(() async {
        await pumpApp(tester, database: database, surface: _window);
        await tester.pump(PlantSway.period);

        // Tear down the app; a texture held by a disposed state would leak
        // here.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      expect(handles.imagesOpen, 0);
    });

    testWidgets("season changes don't leak textures", (tester) async {
      // Season crossfades take 3s and GardenView.rebakeInterval allows a bake
      // every 250ms, so four forced years is ~150 bakes. A missed dispose here
      // would be ~300 MB.
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
        // 40 sessions earns awards and their sheet covers the tab bar.
        await dismissCelebrations(tester);

        // Four times through the year.
        for (var turn = 0; turn < 4; turn++) {
          for (final season in Season.values) {
            await _force(tester, season);
            await settle(tester, over: SeasonalGarden.crossfade);
          }
        }
      });

      // The current one, plus at most one on its way out (released post-frame).
      expect(handles.imagesOpen, lessThanOrEqualTo(2));
    });
  });
}

/// Forces [season] via the debug option in settings, then returns to the
/// garden.
Future<void> _force(WidgetTester tester, Season season) async {
  await tapTab(tester, AppTab.settings);
  await scrollToSetting(tester, SettingsKeys.season);
  await tester.tap(find.text(season.label));
  await settle(tester);
  await tapTab(tester, AppTab.garden);
}
