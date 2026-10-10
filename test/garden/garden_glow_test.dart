import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/garden/garden_atlas.dart';
import 'package:pomodoro_garden/src/garden/garden_painter.dart';
import 'package:pomodoro_garden/src/garden/garden_projection.dart';
import 'package:pomodoro_garden/src/garden/golden_shimmer.dart';
import 'package:pomodoro_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pomodoro_garden/src/garden/plant_sprite.dart';
import 'package:pomodoro_garden/src/garden/plant_sway.dart';

import '../support/decor_fixtures.dart';

/// REQ-021's two effects, PRD v2.2 (ticket 36): the enchanted willow's halo
/// and the golden garden's shimmer, both carried in the garden's one batch.
void main() {
  const window = Size(4000, 4000);
  final planted = DateTime.utc(2026, 8, 11);

  late GardenAtlas atlas;
  setUp(() {
    atlas = GardenAtlas.bake(
      GardenAtlasRecipe(
        registry: const PlaceholderPlantSpriteRegistry(),
        decorRegistry: testDecorRegistry,
        decorPalette: testDecorPalette,
        palettes: {
          for (final species in PlantSpecies.values)
            species: const PlantPalette(
              foliage: Color(0xFF4CAF50),
              bloom: Color(0xFFFFC107),
              soil: Color(0xFF795548),
            ),
        },
        soil: const Color(0xFF795548),
        decor: const Color(0xFF9A9A92),
      ),
    );
  });
  tearDown(() => atlas.dispose());

  Plant grown(int n) {
    final session = FocusSession(
      id: 'session-$n',
      startedAt: planted.add(Duration(hours: n)),
      plannedDuration: const Duration(minutes: 25),
    ).completedAt(planted.add(Duration(hours: n, minutes: 25)));
    return Plant.fromSession(
      session,
      id: 'plant-$n',
      plot: GardenPlots.inPlacementOrder[n],
    );
  }

  Plant awarded(Milestone milestone, int n) => Plant.forMilestone(
        milestone,
        id: 'award-${milestone.sessions}',
        plantedAt: planted,
        plot: GardenPlots.inPlacementOrder[n],
      );

  GardenLayout gardenOf(List<Plant> plants, {List<Decor> decor = const []}) =>
      GardenLayout.of(plants: plants, decor: decor, completedSessions: 1000);

  GardenBatch batchOf(GardenLayout layout, {Animation<double>? sway}) =>
      GardenPainter(
        layout: layout,
        projection: GardenProjection.fitting(window, layout.plots),
        atlas: atlas,
        sway: sway,
      ).batchFor(window);

  group('the enchanted willow', () {
    test('stands in a halo: one quad behind it, from the halo cell', () {
      final batch = batchOf(gardenOf([awarded(Milestone.fiveHundred, 0)]));

      final halo = batch.rects.indexOf(atlas.glowHalo);
      final willow = batch.rects.indexOf(
        atlas.rectFor(PlantSpecies.enchantedWillow),
      );
      expect(halo, isNot(-1));
      expect(halo, lessThan(willow), reason: 'the light is behind the tree');
      expect(
        batch.transforms[halo].scos,
        greaterThan(batch.transforms[willow].scos),
        reason: 'the halo is a little larger than the tree it surrounds',
      );
    });

    test('is the only plant with one', () {
      final batch = batchOf(gardenOf([
        grown(0),
        awarded(Milestone.ten, 1),
        awarded(Milestone.oneHundred, 2),
        awarded(Milestone.oneThousand, 3),
      ]));

      expect(batch.rects.where((rect) => rect == atlas.glowHalo), isEmpty);
    });

    test('and its halo holds still while the garden sways', () {
      final sway = AnimationController(
        vsync: const TestVSync(),
        duration: PlantSway.period,
      )..value = 0.3;
      addTearDown(sway.dispose);

      final batch = batchOf(
        gardenOf([awarded(Milestone.fiveHundred, 0)]),
        sway: sway,
      );
      final halo = batch.transforms[batch.rects.indexOf(atlas.glowHalo)];
      expect(halo.ssin, 0);
    });
  });

  group('the golden garden', () {
    test('is earned by the thousandth session\'s plant and nothing less', () {
      expect(
        GoldenShimmer.earnedBy(gardenOf([awarded(Milestone.fiveHundred, 0)])),
        isFalse,
      );
      expect(
        GoldenShimmer.earnedBy(gardenOf([awarded(Milestone.oneThousand, 0)])),
        isTrue,
      );
    });

    test('a garden without it draws exactly as before: no colours at all', () {
      final batch = batchOf(gardenOf([grown(0), grown(1)]));
      expect(batch.colors, isNull);
    });

    test('washes every plant with gold, and no soil and no decor', () {
      final batch = batchOf(gardenOf(
        [grown(0), grown(1), awarded(Milestone.oneThousand, 2)],
        decor: [
          Decor(
            id: 'bench',
            kind: DecorKind.bench,
            plot: GardenPlots.inPlacementOrder[3],
            placedAt: planted,
          ),
        ],
      ));
      final colors = batch.colors!;
      expect(colors, hasLength(batch.rects.length));

      final plantRects = {
        for (final species in PlantSpecies.values) atlas.rectFor(species),
      };
      for (var i = 0; i < colors.length; i++) {
        final rect = batch.rects[i];
        if (plantRects.contains(rect)) {
          expect(colors[i].a, closeTo(GoldenShimmer.still, 0.01),
              reason: 'a plant, on a garden holding still');
        } else {
          expect(colors[i].a, 0, reason: 'soil and decor are left alone');
        }
      }
    });

    test('glints plant by plant while it moves, never in unison', () {
      final sway = AnimationController(
        vsync: const TestVSync(),
        duration: PlantSway.period,
      )..value = 0.4;
      addTearDown(sway.dispose);

      final batch = batchOf(
        gardenOf([
          for (var n = 0; n < 12; n++) grown(n),
          awarded(Milestone.oneThousand, 12),
        ]),
        sway: sway,
      );
      final strengths = {
        for (final colour in batch.colors!)
          if (colour.a > 0) colour.a.toStringAsFixed(3),
      };
      expect(strengths.length, greaterThan(6));
      for (final colour in batch.colors!) {
        if (colour.a == 0) continue;
        expect(colour.a, inInclusiveRange(
          GoldenShimmer.faintest - 0.01,
          GoldenShimmer.strongest + 0.01,
        ));
      }
    });

    test('leaves the soil exactly as it was, and turns a plant warmer',
        () async {
      // Drawn, not just batched: the blend mode is the part a batch cannot
      // check, and the wrong one fades the whole garden.
      Future<ui.Image> draw(GardenLayout layout) async {
        final recorder = ui.PictureRecorder();
        GardenPainter(
          layout: layout,
          projection: GardenProjection.fitting(window, layout.plots),
          atlas: atlas,
        ).paint(ui.Canvas(recorder), window);
        return recorder.endRecording().toImage(
              window.width.round(),
              window.height.round(),
            );
      }

      Future<List<int>> pixelAt(ui.Image image, Offset at) async {
        final bytes = (await image.toByteData())!;
        final o = (at.dy.round() * image.width + at.dx.round()) * 4;
        return [for (var i = 0; i < 4; i++) bytes.getUint8(o + i)];
      }

      // The same garden twice over: a plain award in one, the golden garden
      // in the other, at the same plot. Everything else is identical.
      final grownPlants = [for (var n = 0; n < 6; n++) grown(n)];
      final plain = gardenOf([...grownPlants, awarded(Milestone.ten, 6)]);
      final golden =
          gardenOf([...grownPlants, awarded(Milestone.oneThousand, 6)]);
      final plainImage = await draw(plain);
      final goldenImage = await draw(golden);
      addTearDown(plainImage.dispose);
      addTearDown(goldenImage.dispose);

      final projection = GardenProjection.fitting(window, plain.plots);

      // A bare plot: no plant on it, so nothing to shimmer.
      final bare = plain.plots.firstWhere(
        (plot) => plain.plantIn(plot) == null && plain.decorIn(plot) == null,
      );
      final soil = projection.centreOf(bare);
      expect(await pixelAt(goldenImage, soil), await pixelAt(plainImage, soil));

      // A grown plant: the same pixels, warmer and no fainter.
      final plantPoint = projection.centreOf(grown(0).plot!) +
          Offset(0, -GardenProjection.spriteSide * projection.scale * 0.1);
      final before = await pixelAt(plainImage, plantPoint);
      final after = await pixelAt(goldenImage, plantPoint);
      expect(before[3], greaterThan(0), reason: 'the probe is on the plant');
      expect(after[3], before[3], reason: 'the wash does not fade a plant');
      expect(after, isNot(before), reason: 'and it does change its colour');
    });

    test('adds no quad: the batch is the same length with or without it', () {
      final plain = batchOf(gardenOf([grown(0), awarded(Milestone.ten, 1)]));
      final golden = batchOf(
        gardenOf([grown(0), awarded(Milestone.oneThousand, 1)]),
      );
      expect(golden.rects, hasLength(plain.rects.length));
    });
  });
}
