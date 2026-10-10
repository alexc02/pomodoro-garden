import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/garden/art_bundle.dart';
import 'package:pomodoro_garden/src/garden/art_gate.dart';
import 'package:pomodoro_garden/src/garden/art_providers.dart';
import 'package:pomodoro_garden/src/garden/decor_providers.dart';
import 'package:pomodoro_garden/src/garden/garden_painter.dart';
import 'package:pomodoro_garden/src/garden/image_sprites.dart';
import 'package:pomodoro_garden/src/garden/placeholder_decor_sprites.dart';
import 'package:pomodoro_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pomodoro_garden/src/garden/plant_providers.dart';
import 'package:pomodoro_garden/src/shell/app_shell.dart';
import 'package:pomodoro_garden/src/shell/opening_frame.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/celebrations.dart';
import '../support/garden_seed.dart';

/// The whole of ticket 23's premise, run through the real app: **swap the art
/// and nothing above the registry notices.**
///
/// Every other test in this suite runs on ticket 04's placeholder shapes, which
/// is what the harness does by default and what nine hundred of them were
/// written against. This file is the one that turns the art on, so that the path
/// the shipping app actually takes is covered somewhere rather than nowhere.
///
/// What it is checking is not that the pictures are pretty. It is that the
/// pieces upstream of the registry — the atlas, the batch, the hit-test, the
/// timer screen, the gates — carry on doing exactly what they did, with a
/// decoded PNG where a circle used to be.

const Size _window = Size(400, 800);

GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GardenPainter,
    ))
    .painter! as GardenPainter;

/// Reads a provider out of the running app.
T _read<T>(WidgetTester tester, Provider<T> provider) =>
    ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    ).read(provider);

void main() {
  group('with the art set loaded', () {
    testWidgets('the registries are the image ones, not the placeholders',
        (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 3);

      await pumpApp(
        tester,
        database: database,
        surface: _window,
        withArt: true,
      );

      // The one line ticket 04 promised would change, changing.
      expect(
        _read(tester, plantSpriteRegistryProvider),
        isA<ImagePlantSpriteRegistry>(),
      );
      expect(
        _read(tester, decorSpriteRegistryProvider),
        isA<ImageDecorSpriteRegistry>(),
      );
    });

    testWidgets('the garden is still one batch of quads', (tester) async {
      // The claim ticket 07's whole design rests on, re-checked with real
      // images behind it: two hundred plants and the ground under them are four
      // hundred quads cut from one texture. If the art swap had turned each
      // plant back into its own draw, this is where it would show.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: GardenPlots.maximum);

      await pumpApp(
        tester,
        database: database,
        surface: _window,
        withArt: true,
      );
      await dismissCelebrations(tester);
      await tapTab(tester, AppTab.garden);

      final batch = _painter(tester).batchFor(const Size(4000, 4000));
      expect(batch.transforms, hasLength(400));
      expect(batch.rects, hasLength(400));
    });

    testWidgets('and every plant in it still knows how much of its box it fills',
        (tester) async {
      // Ticket 12's hit-test, which for a drawing is the manifest's footprint
      // rather than the sprite's own arithmetic. A footprint of the whole box
      // would give a wildflower's empty sky to the finger meant for the tree
      // behind it, and nothing else in the app would complain.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 3);

      await pumpApp(
        tester,
        database: database,
        surface: _window,
        withArt: true,
      );

      final registry = _read(tester, plantSpriteRegistryProvider);
      const box = Rect.fromLTWH(0, 0, 100, 100);

      for (final type in PlantType.values) {
        for (final stage in GrowthStage.values) {
          final footprint =
              registry.spriteFor(type: type, stage: stage).footprintIn(box);

          expect(footprint.isEmpty, isFalse,
              reason: '${type.name}/${stage.name} claims to fill nothing');
          expect(footprint.width, lessThanOrEqualTo(box.width + 0.01),
              reason: '${type.name}/${stage.name} claims to overflow its box');
        }
      }
    });

    testWidgets('a session grows a plant on the timer screen', (tester) async {
      // The other screen a sprite reaches, and the one where a single plant is
      // painted through `PlantPainter` rather than baked into the atlas. Both
      // paths take the same sprite; this is the half the garden does not cover.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final clock = FixedClock(DateTime.utc(2026, 8, 28, 9));

      await pumpApp(
        tester,
        database: database,
        clock: clock,
        surface: _window,
        withArt: true,
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 12));

      // Still growing something, and still doing it through the registry.
      expect(find.text('Pause'), findsOne);
      expect(
        _read(tester, plantSpriteRegistryProvider),
        isA<ImagePlantSpriteRegistry>(),
      );
    });
  });

  group('the gate', () {
    testWidgets('holds the app back until the art has been decoded',
        (tester) async {
      // The one piece of logic the art swap could not avoid. Below the gate
      // every sprite lookup is synchronous, which is what lets the atlas bake
      // with `toImageSync` and the garden never have a frame with no texture.
      final ready = Completer<ArtBundle?>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            artBundleProvider.overrideWith((ref) => ready.future),
          ],
          child: const MaterialApp(home: ArtGate(child: Text('the app'))),
        ),
      );

      expect(find.byType(OpeningFrame), findsOne);
      expect(find.text('the app'), findsNothing);

      ready.complete(null);
      await tester.pump();

      expect(find.text('the app'), findsOne);
    });

    testWidgets('opens on the placeholders when a build ships no art',
        (tester) async {
      // A legitimate state, not a failure: the art is a delivery from outside
      // this repository and a build can be made before it lands.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await pumpApp(tester, database: database, surface: _window);

      expect(
        _read(tester, plantSpriteRegistryProvider),
        isA<PlaceholderPlantSpriteRegistry>(),
      );
      expect(
        _read(tester, decorSpriteRegistryProvider),
        isA<PlaceholderDecorSpriteRegistry>(),
      );
      expect(find.byType(NavigationBar), findsOne,
          reason: 'the app opened anyway');
    });

    // **Two branches are deliberately not tested here**, and the reason is
    // test plumbing rather than doubt about the code.
    //
    // `ArtGate`'s error report, and `artBundleProvider`'s refusal to fall back
    // for a manifest that is present and wrong, both need a provider that fails
    // *asynchronously* inside a `testWidgets` body. Riverpod surfaces such a
    // failure as an `AsyncValue.error` and also lets it reach the zone, and an
    // error loose in the zone fails the test before any expectation runs — under
    // every arrangement tried: a completer completed with an error, a body that
    // throws on its first tick, one that throws after an await, an overridden
    // `FlutterError.onError`, and `tester.takeException`.
    //
    // What that leaves uncovered is one `reportError` call. What is covered
    // elsewhere is everything it depends on: `art_bundle_test.dart` proves that
    // a missing file and an incomplete set each throw an `ArtBundleException`,
    // and the two tests above prove the gate holds for a load and opens on the
    // placeholders when there is nothing to load. Recorded in the ticket rather
    // than papered over with a test that passes for the wrong reason.
  });
}
