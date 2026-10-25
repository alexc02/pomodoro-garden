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

/// PRD §4.4: a garden of two hundred plants renders at 60fps with no dropped
/// frames. Ticket 24 owns meeting that on a device; this file owns the
/// measurement underneath it and the numbers ticket 24 starts from.
///
/// **What this can and cannot measure.** A widget test has no GPU and no
/// vsync: nothing here rasterises, so none of it is a frame time. What it does
/// measure is the CPU-side work the garden asks for every frame — building the
/// batch and recording the draw — which is the part this ticket wrote and the
/// part that a design of two hundred widgets would have got wrong by two orders
/// of magnitude. The device numbers, and the table they go in, are in
/// `docs/garden-performance-baseline.md`.
///
/// The assertions are budgets rather than measurements. They are set loose
/// enough not to flake on a busy CI box and tight enough that a change which
/// reintroduced per-plant work would trip them: a garden drawn plant by plant
/// runs roughly a hundred times the calls this does.

/// A phone-sized window.
const Size _window = Size(400, 800);

/// How many frames each measurement averages over.
const int _frames = 120;

/// The species a session can grow: every one but REQ-021's seven bonus plants,
/// which only a milestone awards (and the enchanted willow carries a halo
/// quad of its own — see `garden_glow_test.dart`).
final List<PlantSpecies> _sessionSpecies = [
  for (final species in PlantSpecies.values)
    if (species.type != PlantType.bonus) species,
];

const PlantPalette _palette = PlantPalette(
  foliage: Color(0xFF4CAF50),
  bloom: Color(0xFFFFC107),
  soil: Color(0xFF795548),
);

/// A full garden: two hundred plants in two hundred plots, nothing empty.
GardenLayout _fullGarden() => GardenLayout.of(
      plants: [
        for (var n = 0; n < GardenPlots.maximum; n++)
          Plant(
            id: 'plant-$n',
            sessionId: 'session-$n',
            // A spread of types, so the batch is cutting from all over the
            // texture rather than from one cell that would stay in cache.
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

/// Microseconds per frame, averaged over [_frames], after a warm-up.
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

  test('two hundred plants are two hundred plots and nothing left over', () {
    expect(garden.plotCount, 200);
    expect(garden.plants, hasLength(200));
    expect(garden.unplaced, isEmpty);
  });

  test('baking the texture is a one-off, not a frame cost', () {
    // The atlas is baked when the theme changes and at no other time, so it is
    // allowed to be expensive — but only if it really is a one-off, and the
    // number is worth having written down.
    final clock = Stopwatch()..start();
    final baked = GardenAtlas.bake(atlas.signature);
    clock.stop();
    baked.dispose();

    _record('baking the atlas (once, not per frame)', clock.elapsedMicroseconds.toDouble());
    expect(clock.elapsedMilliseconds, lessThan(500));
  });

  test('a still garden of two hundred plants costs almost nothing to draw', () {
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
      reason: 'a frame at 60fps is 16.7ms all in, and the garden is not the '
          'only thing in it',
    );
  });

  test('and scrolling one costs the same', () {
    // Every frame of a drag is a different camera, so nothing can be cached
    // between them: this is the case PRD §4.4 actually names.
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

  test('zoomed in, most of the garden costs nothing at all', () {
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
      reason: 'the plots off the screen were culled rather than drawn — a full '
          'garden with nothing culled is four hundred quads',
    );
    expect(perFrame, lessThan(4000));
  });

  test('and swaying while it scrolls costs a sine per plant and nothing else',
      () {
    // REQ-023's sway, which ticket 07 measured its budget *without* and left
    // for this ticket. This is the row that decides whether a continuously
    // animating garden was affordable: the same batch as the row above it, with
    // the rotation field filled in, so the delta between the two is two hundred
    // `sin` calls and two hundred multiplies.
    //
    // It is also the worst case the garden has, because it is the one frame
    // where nothing can be skipped: the camera moves so no cull result is
    // reusable, and the sway moves so no transform is.
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

  test('and shimmering gold as well costs a colour per plant', () {
    // REQ-021's golden garden (ticket 36): the worst case above, plus the gold
    // wash on every plant, carried in the same batch as a colour per quad.
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

  test('a swaying garden is the same batch as a still one', () {
    // The structural half of the claim above, and the one that does not depend
    // on how fast the box running it is: the sway adds no quad and no draw.
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

  test('the whole batch is one call, however many plants there are', () {
    // The structural claim behind every number above. Two hundred plants and
    // the ground under them are four hundred quads in one batch — not four
    // hundred draws, and not four hundred widgets.
    final batch = GardenPainter(
      layout: garden,
      projection: GardenProjection.fitting(_window, garden.plots),
      atlas: atlas,
    ).batchFor(_window);

    expect(batch.transforms, hasLength(400));
    expect(batch.rects, hasLength(400));
  });

  testWidgets('a full garden opens and drags in the real app', (tester) async {
    // End to end rather than in a microbenchmark: the two hundred plants come
    // off the database, through the layout, into the widget, and are dragged.
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

    // One pointer move and one pump per frame, which is what a real drag is:
    // the number is build, layout and paint for the whole tab, not just the
    // painter's share of it.
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
