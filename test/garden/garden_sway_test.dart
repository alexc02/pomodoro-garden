import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/garden/garden_atlas.dart';
import 'package:pomodoro_garden/src/garden/garden_painter.dart';
import 'package:pomodoro_garden/src/garden/garden_projection.dart';
import 'package:pomodoro_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pomodoro_garden/src/garden/plant_sprite.dart';
import 'package:pomodoro_garden/src/garden/plant_sway.dart';

import '../support/app_harness.dart';
import '../support/decor_fixtures.dart';
import '../support/garden_seed.dart';

/// REQ-023's sway, in the garden — the animation ticket 07 measured its frame
/// budget without and left for ticket 24 to decide with a number in hand.
///
/// The claim being tested is not "the plants move". It is that they move
/// **inside the batch**: a swaying garden is the same four hundred quads, in the
/// same one `drawAtlas` call, with a rotation field filled in that was
/// previously being passed zero. Everything below is a way of saying that, or of
/// saying that the motion is REQ-023's motion and not some other one.

final DateTime _anchor = DateTime.utc(2026, 8, 11, 9, 41);

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

/// A window big enough that nothing is culled for being off screen.
const Size _window = Size(4000, 4000);

/// What a lean survives a round trip through the batch's `Float32List` to.
///
/// Comfortably tighter than a degree — the assertions using it are about the
/// motion being the same motion, and two degrees against zero is not a
/// distinction that needs 10^-9 to make.
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

/// The lean baked into a quad, in radians, recovered from the transform.
///
/// `RSTransform` does not store the rotation it was built from; it stores
/// `scale * cos` and `scale * sin`, which is what the GPU wants. The angle comes
/// back out of the pair.
///
/// It comes back to single precision and no further: the pair is held in a
/// `Float32List`, because that is what crosses to the engine. So a comparison
/// against the angle that went in is a comparison to about a part in 10^7 — see
/// [_float32], which is the tolerance every assertion here about an exact lean
/// uses.
double _lean(RSTransform transform) => math.atan2(transform.ssin, transform.scos);

/// The leans of everything standing on the ground, in draw order.
///
/// A plot contributes its tile and then whatever is on it, so the occupants are
/// the quads whose rect is neither soil tile.
List<double> _occupantLeans(GardenBatch batch, GardenAtlas atlas) => [
      for (var index = 0; index < batch.rects.length; index++)
        if (batch.rects[index] != atlas.emptySoil &&
            batch.rects[index] != atlas.plantedSoil)
          _lean(batch.transforms[index]),
    ];

/// The leans of every plot's ground.
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

  group('a garden with nothing driving it', () {
    test('stands perfectly upright', () {
      // The default, and the state a phone with reduce-motion on is left in.
      // Upright rather than frozen mid-lean: a user who asked for no motion is
      // owed the picture, not just the stillness.
      final batch = _batchAt(null, layout: _garden(40), atlas: atlas);

      expect(batch.transforms, isNotEmpty);
      for (final transform in batch.transforms) {
        expect(transform.ssin, 0);
      }
    });

    test('and is the same batch a swaying one is', () {
      // The whole structural claim: the sway adds no quad, no draw and no
      // widget. If this ever stops being true, the frame budget in
      // docs/garden-performance-baseline.md stops describing the app.
      final garden = _garden(GardenPlots.maximum);
      final still = _batchAt(null, layout: garden, atlas: atlas);
      final swaying = _batchAt(0.3, layout: garden, atlas: atlas);

      expect(still.transforms, hasLength(400));
      expect(swaying.transforms, hasLength(still.transforms.length));
      expect(swaying.rects, still.rects);
    });
  });

  group('a swaying garden', () {
    test('leans its plants', () {
      final leans = _occupantLeans(
        _batchAt(0.1, layout: _garden(40), atlas: atlas),
        atlas,
      );

      expect(leans, hasLength(40));
      expect(leans.any((lean) => lean.abs() > 1e-6), isTrue,
          reason: 'nothing moved');
    });

    test('and never past REQ-023\'s two degrees', () {
      // Sampled across a whole period rather than at one instant, because the
      // extreme is somewhere inside it and which plant reaches it depends on
      // the phase its session gave it.
      final garden = _garden(GardenPlots.maximum);

      for (var step = 0; step < 40; step++) {
        for (final lean
            in _occupantLeans(_batchAt(step / 40, layout: garden, atlas: atlas), atlas)) {
          expect(lean.abs(), lessThanOrEqualTo(PlantSway.amplitude + 1e-9));
        }
      }
    });

    test('leaves the ground alone', () {
      // The soil is the one thing under the plant that must not move with it,
      // or the plot slides out from under the thing standing on it.
      final garden = _garden(40);
      final leans = _groundLeans(_batchAt(0.37, layout: garden, atlas: atlas), atlas);

      // Every plot's tile, planted or bare — not just the forty with something
      // standing on them.
      expect(leans, hasLength(garden.plotCount));
      expect(leans, everyElement(0.0));
    });

    test('leaves REQ-040\'s objects alone: a bench does not sway', () {
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

    test('does not pulse: neighbours are at different points in the loop', () {
      // The reason the phase is per plant at all. A garden leaning in unison is
      // a heartbeat, and it is what one shared controller gives you by default.
      final leans = _occupantLeans(
        _batchAt(0, layout: _garden(GardenPlots.maximum), atlas: atlas),
        atlas,
      );

      final distinct = leans.map((lean) => lean.toStringAsFixed(4)).toSet();
      expect(distinct.length, greaterThan(100),
          reason: 'two hundred plants leaning together is not a garden',
      );
    });

    test('holds a plant\'s phase still across frames', () {
      // A phase re-rolled per frame would be a shimmer rather than a sway, and
      // one re-rolled per rebuild would jump every time the garden was scrolled
      // away from and back. Both are what a `Random` would give.
      final garden = _garden(40);

      expect(
        _occupantLeans(_batchAt(0.25, layout: garden, atlas: atlas), atlas),
        _occupantLeans(_batchAt(0.25, layout: garden, atlas: atlas), atlas),
      );
    });

    test('wraps without a seam at the end of the loop', () {
      // The controller repeats over 0..1, so the frame after 1 is the frame at
      // 0. A sine does not care, and this is what says so.
      final garden = _garden(40);

      final atOne = _occupantLeans(_batchAt(1, layout: garden, atlas: atlas), atlas);
      final atZero = _occupantLeans(_batchAt(0, layout: garden, atlas: atlas), atlas);

      for (var n = 0; n < atZero.length; n++) {
        expect(atOne[n], closeTo(atZero[n], _float32));
      }
    });
  });

  group('the plant on the timer screen and the plant in the garden', () {
    test('lean the same way at the same point in the loop', () {
      // The two are drawn by completely different code — one `CustomPaint` per
      // plant there, one quad of a `drawAtlas` batch here — and they are the
      // same plant. A user who watches a plant grow and then goes and finds it
      // must not find something moving to a different rhythm.
      final garden = _garden(8);
      final leans = _occupantLeans(_batchAt(0.42, layout: garden, atlas: atlas), atlas);

      // Built by walking the plots rather than the plants, because the batch is
      // in draw order — back to front — and that is not the order the plants
      // were planted in.
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

      // The animation is what the painter repaints off, which is the whole
      // reason a frame of the sway costs no build and no layout.
      final before = painter.sway!.value;
      await tester.pump(PlantSway.period ~/ 4);
      expect(_paintingTheGarden(tester).sway!.value, isNot(before));
    });

    testWidgets('and stops dead when the phone asks for no animation',
        (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 20);

      // Set before the app is built, which is the case a user actually has: the
      // setting is on when they open the app, not turned on while they watch.
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
