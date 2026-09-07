import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/garden/garden_atlas.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/garden_projection.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/plant_sprite.dart';
import 'package:pip_garden/src/garden/plant_sway.dart';

import '../support/app_harness.dart';
import '../support/decor_fixtures.dart';
import '../support/garden_seed.dart';

// Sway happens inside the batch: same 400 quads, same drawAtlas call, just
// with the rotation field filled in.

final DateTime _anchor = DateTime.utc(2026, 8, 11, 9, 41);

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

/// Big enough that nothing is culled.
const Size _window = Size(4000, 4000);

/// Precision after a Float32List round trip.
const double _float32 = 1e-6;

GardenAtlas _atlas() => GardenAtlas.bake(
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

Plant _plant(int n) => Plant(
      id: 'plant-$n',
      sessionId: 'session-$n',
      type: _sessionSpecies[n % _sessionSpecies.length].type,
      species: _sessionSpecies[n % _sessionSpecies.length],
      stage: GrowthStage.mature,
      plantedAt: _anchor.add(Duration(days: n)),
      sessionDuration: const Duration(minutes: 25),
      plot: GardenPlots.inPlacementOrder[n],
    );

GardenLayout _garden(int plants, {List<Decor> decor = const []}) =>
    GardenLayout.of(
      plants: [for (var n = 0; n < plants; n++) _plant(n)],
      decor: decor,
      completedSessions: 5000,
    );

/// The lean in radians, recovered from the transform. RSTransform stores
/// scale*cos and scale*sin in a Float32List, so it's only accurate to
/// [_float32].
double _lean(RSTransform transform) => math.atan2(transform.ssin, transform.scos);

/// Leans of everything standing on the ground, in draw order (quads that
/// aren't soil tiles).
List<double> _occupantLeans(GardenBatch batch, GardenAtlas atlas) => [
      for (var index = 0; index < batch.rects.length; index++)
        if (batch.rects[index] != atlas.emptySoil &&
            batch.rects[index] != atlas.plantedSoil)
          _lean(batch.transforms[index]),
    ];

List<double> _groundLeans(GardenBatch batch, GardenAtlas atlas) => [
      for (var index = 0; index < batch.rects.length; index++)
        if (batch.rects[index] == atlas.emptySoil ||
            batch.rects[index] == atlas.plantedSoil)
          _lean(batch.transforms[index]),
    ];

GardenBatch _batchAt(
  double? turn, {
  required GardenLayout layout,
  required GardenAtlas atlas,
}) =>
    GardenPainter(
      layout: layout,
      projection: GardenProjection.fitting(_window, layout.plots),
      atlas: atlas,
      sway: turn == null ? null : AlwaysStoppedAnimation<double>(turn),
    ).batchFor(_window);

void main() {
  late GardenAtlas atlas;

  setUp(() => atlas = _atlas());
  tearDown(() => atlas.dispose());

  group('without sway', () {
    test('stands perfectly upright', () {
      // Default, and the reduce-motion state: upright, not frozen mid-lean.
      final batch = _batchAt(null, layout: _garden(40), atlas: atlas);

      expect(batch.transforms, isNotEmpty);
      for (final transform in batch.transforms) {
        expect(transform.ssin, 0);
      }
    });

    test('same batch as a swaying one', () {
      // Sway adds no quad, draw or widget.
      final garden = _garden(GardenPlots.maximum);
      final still = _batchAt(null, layout: garden, atlas: atlas);
      final swaying = _batchAt(0.3, layout: garden, atlas: atlas);

      expect(still.transforms, hasLength(400));
      expect(swaying.transforms, hasLength(still.transforms.length));
      expect(swaying.rects, still.rects);
    });
  });

  group('swaying', () {
    test('leans its plants', () {
      final leans = _occupantLeans(
        _batchAt(0.1, layout: _garden(40), atlas: atlas),
        atlas,
      );

      expect(leans, hasLength(40));
      expect(leans.any((lean) => lean.abs() > 1e-6), isTrue,
          reason: 'nothing moved');
    });

    test('never past two degrees', () {
      // Sample a whole period; which plant hits the extreme depends on phase.
      final garden = _garden(GardenPlots.maximum);

      for (var step = 0; step < 40; step++) {
        for (final lean
            in _occupantLeans(_batchAt(step / 40, layout: garden, atlas: atlas), atlas)) {
          expect(lean.abs(), lessThanOrEqualTo(PlantSway.amplitude + 1e-9));
        }
      }
    });

    test('ground does not move', () {
      // Soil must not move, or the plot slides out from under the plant.
      final garden = _garden(40);
      final leans = _groundLeans(_batchAt(0.37, layout: garden, atlas: atlas), atlas);

      // Every plot's tile, planted or not.
      expect(leans, hasLength(garden.plotCount));
      expect(leans, everyElement(0.0));
    });

    test('decor does not sway', () {
      final garden = _garden(
        0,
        decor: [testDecor(DecorKind.bench, GardenPlots.inPlacementOrder.first)],
      );

      final leans = _occupantLeans(
        _batchAt(0.37, layout: garden, atlas: atlas),
        atlas,
      );

      expect(leans, [0.0]);
    });

    test('neighbours are out of phase', () {
      // Per-plant phase so the garden doesn't pulse in unison.
      final leans = _occupantLeans(
        _batchAt(0, layout: _garden(GardenPlots.maximum), atlas: atlas),
        atlas,
      );

      final distinct = leans.map((lean) => lean.toStringAsFixed(4)).toSet();
      expect(distinct.length, greaterThan(100),
          reason: 'plants should not lean in unison',
      );
    });

    test('phase is stable across frames', () {
      // Re-rolling per frame or rebuild would shimmer or jump. Don't use
      // Random.
      final garden = _garden(40);

      expect(
        _occupantLeans(_batchAt(0.25, layout: garden, atlas: atlas), atlas),
        _occupantLeans(_batchAt(0.25, layout: garden, atlas: atlas), atlas),
      );
    });

    test('loops seamlessly', () {
      // The controller repeats 0..1, so frame 1 equals frame 0.
      final garden = _garden(40);

      final atOne = _occupantLeans(_batchAt(1, layout: garden, atlas: atlas), atlas);
      final atZero = _occupantLeans(_batchAt(0, layout: garden, atlas: atlas), atlas);

      for (var n = 0; n < atZero.length; n++) {
        expect(atOne[n], closeTo(atZero[n], _float32));
      }
    });
  });

  group('timer vs garden', () {
    test('lean the same at the same phase', () {
      // Different code paths (CustomPaint per plant vs a drawAtlas quad), same
      // motion.
      final garden = _garden(8);
      final leans = _occupantLeans(_batchAt(0.42, layout: garden, atlas: atlas), atlas);

      // Walk plots, not plants: the batch is in draw order.
      final expected = [
        for (final plot in garden.plots)
          if (garden.plantIn(plot) case final plant?)
            PlantSway.leanAt(0.42, seed: plant.sessionId!),
      ];

      expect(expected, hasLength(8));
      for (var n = 0; n < leans.length; n++) {
        expect(leans[n], closeTo(expected[n], _float32));
      }
    });
  });

  group('in the running app', () {
    testWidgets('the garden sways', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 20);

      await pumpApp(tester, database: database, surface: const Size(400, 800));

      final painter = _paintingTheGarden(tester);
      expect(painter.sway, isNotNull);
      expect(painter.sway!.value, isNotNull);

      // The painter repaints off the animation, so sway costs no build or
      // layout.
      final before = painter.sway!.value;
      await tester.pump(PlantSway.period ~/ 4);
      expect(_paintingTheGarden(tester).sway!.value, isNot(before));
    });

    testWidgets('stops with reduce motion', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 20);

      // Set before the app builds, as a real user would have it.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
        disableAnimations: true,
        reduceMotion: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await pumpApp(tester, database: database, surface: const Size(400, 800));

      final painter = _paintingTheGarden(tester);
      expect(painter.sway, isNull);
      for (final transform in painter.batchFor(const Size(400, 800)).transforms) {
        expect(transform.ssin, 0);
      }
    });
  });
}

GardenPainter _paintingTheGarden(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GardenPainter,
    ))
    .painter! as GardenPainter;
