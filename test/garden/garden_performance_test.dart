import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/features/garden/garden_view.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/garden_projection.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/garden_atlas.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';
import 'package:pip_garden/src/garden/plant_sway.dart';

import '../support/app_harness.dart';
import '../support/garden_seed.dart';

import '../support/decor_fixtures.dart';

// Target: 200 plants at 60fps with no dropped frames.
//
// Widget tests have no GPU or vsync, so these aren't frame times. They measure
// the per-frame CPU work (building the batch, recording the draw), not
// device numbers.
//
// Budgets are loose enough for a busy CI box but would catch per-plant work
// coming back (roughly 100x the calls).

const Size _window = Size(400, 800);

const int _frames = 120;

/// Species a session can grow: everything except the seven bonus plants
/// (the enchanted willow also has a halo quad, see garden_glow_test.dart).
final List<PlantSpecies> _sessionSpecies = [
  for (final species in PlantSpecies.values)
    if (species.type != PlantType.bonus) species,
];

const PlantPalette _palette = PlantPalette(
  foliage: Color(0xFF4CAF50),
  bloom: Color(0xFFFFC107),
  soil: Color(0xFF795548),
);

/// 200 plants in 200 plots.
GardenLayout _fullGarden() => GardenLayout.of(
      plants: [
        for (var n = 0; n < GardenPlots.maximum; n++)
          Plant(
            id: 'plant-$n',
            sessionId: 'session-$n',
            // Mixed types so the batch samples across the texture.
            type: _sessionSpecies[n % _sessionSpecies.length].type,
            species: _sessionSpecies[n % _sessionSpecies.length],
            stage: GrowthStage.mature,
            plantedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: n)),
            sessionDuration: const Duration(minutes: 25),
            plot: GardenPlots.inPlacementOrder[n],
          ),
      ],
      completedSessions: 5000,
    );

/// Microseconds per frame, averaged over [_frames] after a warm-up.
double _perFrame(void Function(int frame) frame) {
  for (var warm = 0; warm < 20; warm++) {
    frame(warm);
  }

  final clock = Stopwatch()..start();
  for (var n = 0; n < _frames; n++) {
    frame(n);
  }
  clock.stop();

  return clock.elapsedMicroseconds / _frames;
}

void _record(String what, double microseconds) {
  debugPrint(
    'garden baseline | $what: ${(microseconds / 1000).toStringAsFixed(3)} ms '
    'per frame',
  );
}

void main() {
  late GardenAtlas atlas;
  late GardenLayout garden;

  setUp(() {
    atlas = GardenAtlas.bake(
      GardenAtlasRecipe(
        registry: const PlaceholderPlantSpriteRegistry(),
        decorRegistry: testDecorRegistry,
        decorPalette: testDecorPalette,
        palettes: {
          for (final species in PlantSpecies.values) species: _palette,
        },
        soil: const Color(0xFF795548),
        decor: const Color(0xFF9A9A92),
      ),
    );
    garden = _fullGarden();
  });

  tearDown(() => atlas.dispose());

  test('200 plants fill 200 plots', () {
    expect(garden.plotCount, 200);
    expect(garden.plants, hasLength(200));
    expect(garden.unplaced, isEmpty);
  });

  test('atlas bake is a one-off cost', () {
    // Only baked on theme change, so it can be slow, but record the number.
    final clock = Stopwatch()..start();
    final baked = GardenAtlas.bake(atlas.signature);
    clock.stop();
    baked.dispose();

    _record('baking the atlas (once, not per frame)', clock.elapsedMicroseconds.toDouble());
    expect(clock.elapsedMilliseconds, lessThan(500));
  });

  test('still 200-plant garden is cheap', () {
    final projection = GardenProjection.fitting(_window, garden.plots);
    final painter = GardenPainter(
      layout: garden,
      projection: projection,
      atlas: atlas,
    );

    final perFrame = _perFrame((_) {
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), _window);
      recorder.endRecording().dispose();
    });

    _record('200 plants, still', perFrame);
    expect(
      perFrame,
      lessThan(4000),
      reason: 'the garden gets only part of a 16.7ms frame',
    );
  });

  test('scrolling costs the same', () {
    // Every drag frame is a new camera, so nothing can be cached.
    final start = GardenProjection.fitting(_window, garden.plots);

    final perFrame = _perFrame((frame) {
      final painter = GardenPainter(
        layout: garden,
        projection: start.pannedBy(Offset(frame % 60 - 30, 0)),
        atlas: atlas,
      );
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), _window);
      recorder.endRecording().dispose();
    });

    _record('200 plants, scrolling', perFrame);
    expect(perFrame, lessThan(4000));
  });

  test('zoomed in, offscreen plots are free', () {
    final painter = GardenPainter(
      layout: garden,
      projection: const GardenProjection(
        scale: GardenProjection.maximumScale,
        pan: Offset(200, 400),
      ),
      atlas: atlas,
    );

    final perFrame = _perFrame((_) {
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), _window);
      recorder.endRecording().dispose();
    });

    _record('200 plants, zoomed in', perFrame);
    expect(
      painter.batchFor(_window).transforms.length,
      lessThan(200),
      reason: 'offscreen plots should be culled',
    );
    expect(perFrame, lessThan(4000));
  });

  test('sway while scrolling adds a sine per plant', () {
    // Same batch as above with rotation filled in, so the delta is 200 sin
    // calls and multiplies. Worst case: the camera moves so culling can't be
    // reused, and the sway moves so transforms can't be either.
    final start = GardenProjection.fitting(_window, garden.plots);
    final sway = AnimationController(
      vsync: const TestVSync(),
      duration: PlantSway.period,
    );
    addTearDown(sway.dispose);

    final perFrame = _perFrame((frame) {
      sway.value = (frame % 240) / 240;
      final painter = GardenPainter(
        layout: garden,
        projection: start.pannedBy(Offset(frame % 60 - 30, 0)),
        atlas: atlas,
        sway: sway,
      );
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), _window);
      recorder.endRecording().dispose();
    });

    _record('200 plants, scrolling and swaying', perFrame);
    expect(perFrame, lessThan(4000));
  });

  test('gold shimmer adds a colour per plant', () {
    // Worst case above plus the gold wash, a colour per quad.
    final golden = GardenLayout.of(
      plants: [
        ...garden.plants.take(GardenPlots.maximum - 1),
        Plant.forMilestone(
          Milestone.oneThousand,
          id: 'golden',
          plantedAt: DateTime.utc(2026, 1, 1),
          plot: GardenPlots.inPlacementOrder.last,
        ),
      ],
      completedSessions: 5000,
    );
    final start = GardenProjection.fitting(_window, golden.plots);
    final sway = AnimationController(
      vsync: const TestVSync(),
      duration: PlantSway.period,
    );
    addTearDown(sway.dispose);

    final perFrame = _perFrame((frame) {
      sway.value = (frame % 240) / 240;
      final painter = GardenPainter(
        layout: golden,
        projection: start.pannedBy(Offset(frame % 60 - 30, 0)),
        atlas: atlas,
        sway: sway,
      );
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), _window);
      recorder.endRecording().dispose();
    });

    _record('200 plants, scrolling, swaying and shimmering', perFrame);
    expect(perFrame, lessThan(4000));
  });

  test('sway does not change the batch', () {
    // Sway adds no quads or draws, regardless of machine speed.
    final sway = AnimationController(
      vsync: const TestVSync(),
      duration: PlantSway.period,
    )..value = 0.3;
    addTearDown(sway.dispose);

    final projection = GardenProjection.fitting(_window, garden.plots);
    final still = GardenPainter(
      layout: garden,
      projection: projection,
      atlas: atlas,
    ).batchFor(_window);
    final swaying = GardenPainter(
      layout: garden,
      projection: projection,
      atlas: atlas,
      sway: sway,
    ).batchFor(_window);

    expect(swaying.transforms, hasLength(still.transforms.length));
    expect(swaying.rects, still.rects);
  });

  test('whole batch is one call', () {
    // 200 plants plus ground = 400 quads in one batch.
    final batch = GardenPainter(
      layout: garden,
      projection: GardenProjection.fitting(_window, garden.plots),
      atlas: atlas,
    ).batchFor(_window);

    expect(batch.transforms, hasLength(400));
    expect(batch.rects, hasLength(400));
  });

  testWidgets('full garden opens and drags in the app', (tester) async {
    // End to end: 200 plants from the database, through layout, dragged.
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await seedGarden(database, sessions: GardenPlots.maximum);

    await pumpApp(tester, database: database, surface: _window);

    final drawn = tester
        .widget<CustomPaint>(find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is GardenPainter,
        ))
        .painter! as GardenPainter;
    expect(drawn.layout.plants, hasLength(200));

    // One move and one pump per frame, so this is build, layout and paint for
    // the whole tab.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(GardenView)),
    );
    await gesture.moveBy(const Offset(-30, -20));
    await tester.pump();

    final clock = Stopwatch()..start();
    for (var frame = 0; frame < _frames; frame++) {
      await gesture.moveBy(const Offset(-1, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    clock.stop();
    await gesture.up();
    await tester.pump();

    _record(
      'dragging 200 plants, through the widget tree',
      clock.elapsedMicroseconds / _frames,
    );
  });
}
